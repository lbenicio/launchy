#!/bin/bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/update_changelog.sh [--version <version> | --bump <major|minor|patch>] [--date <YYYY-MM-DD>] [--dry-run]

Generates a changelog entry from git commits since the previous version tag,
updates CHANGELOG.md, and prints the entry so it can be reused for release
notes. When --dry-run is supplied, the changelog file is not modified.
EOF
}

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHANGELOG_PATH="$ROOT/CHANGELOG.md"
PACKAGE_SWIFT_PATH="$ROOT/Package.swift"

version=""
release_date="$(date +%F)"
dry_run=0
bump_type=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      [[ $# -ge 2 ]] || { echo "error: --version requires a value" >&2; exit 1; }
      version="$2"
      shift 2
      ;;
    --date)
      [[ $# -ge 2 ]] || { echo "error: --date requires a value" >&2; exit 1; }
      release_date="$2"
      shift 2
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    --bump)
      [[ $# -ge 2 ]] || { echo "error: --bump requires one of: major, minor, patch" >&2; exit 1; }
      bump_type="$2"
      case "$bump_type" in
        major|minor|patch) ;;
        *) echo "error: invalid bump type '$bump_type'" >&2; exit 1 ;;
      esac
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown option '$1'" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -n "$bump_type" && -n "$version" ]]; then
  echo "error: use either --version or --bump, not both" >&2
  exit 1
fi

if [[ -z "$version" ]]; then
  if [[ ! -f "$PACKAGE_SWIFT_PATH" ]]; then
    echo "error: Package.swift not found" >&2
    exit 1
  fi
  version=$(awk -F '"' '/packageVersion/ { print $2; exit }' "$PACKAGE_SWIFT_PATH")
  if [[ -z "$version" ]]; then
    echo "error: could not determine version from Package.swift" >&2
    exit 1
  fi
fi

if [[ -n "$bump_type" ]]; then
  IFS='.' read -r major minor patch <<< "$version"
  major=${major:-0}
  minor=${minor:-0}
  patch=${patch:-0}
  case "$bump_type" in
    major)
      major=$((major + 1))
      minor=0
      patch=0
      ;;
    minor)
      minor=$((minor + 1))
      patch=0
      ;;
    patch)
      patch=$((patch + 1))
      ;;
  esac
  version="${major}.${minor}.${patch}"
fi

if [[ ! -f "$CHANGELOG_PATH" ]]; then
  echo "error: $CHANGELOG_PATH does not exist" >&2
  exit 1
fi

# Determine the most recent tag merged into HEAD.
last_tag=""
if last_tag=$(git -C "$ROOT" describe --tags --abbrev=0 2>/dev/null); then
  :
else
  # Fall back to the latest tag by creation date if describe fails.
  last_tag=$(git -C "$ROOT" tag --merged HEAD --sort=-creatordate | head -n 1 || true)
fi

log_range=""
if [[ -n "$last_tag" ]]; then
  log_range="${last_tag}..HEAD"
fi

commit_messages=$(git -C "$ROOT" log ${log_range:+"$log_range"} --pretty=format:%s --no-merges --reverse)
if [[ -z "$commit_messages" ]]; then
  echo "No commits found since the previous tag; changelog not updated." >&2
  exit 0
fi

commit_array=()
while IFS= read -r line; do
  commit_array+=("$line")
done <<< "$commit_messages"
entry_lines=()
for raw_line in "${commit_array[@]}"; do
  stripped="${raw_line#${raw_line%%[![:space:]]*}}"
  stripped="${stripped#- }"
  stripped="${stripped#\* }"
  if [[ -n "$stripped" ]]; then
    entry_lines+=("- $stripped")
  fi
done

if [[ ${#entry_lines[@]} -eq 0 ]]; then
  echo "No commit summaries available for changelog entry." >&2
  exit 1
fi

entry_body=$(printf '%s\n' "${entry_lines[@]}")
entry=$(printf '## [%s] - %s\n\n%s\n' "$version" "$release_date" "$entry_body")

grep -q "^## \[$version\]" "$CHANGELOG_PATH" && {
  echo "error: changelog already contains an entry for version $version" >&2
  exit 1
}

if (( dry_run )); then
  printf '%s\n' "$entry"
  exit 0
fi

if [[ -n "$bump_type" ]]; then
  tmp_pkg=$(mktemp)
  trap 'rm -f "$tmp_pkg"' EXIT
  awk -v ver="$version" '
    BEGIN { done = 0 }
    {
      if (!done && $0 ~ /packageVersion[[:space:]]*=[[:space:]]*"/) {
        sub(/(packageVersion[[:space:]]*=[[:space:]]*")[^"]*(".*)/, "\\1" ver "\\2")
        done = 1
      }
      print
    }
  ' "$PACKAGE_SWIFT_PATH" > "$tmp_pkg"
  mv "$tmp_pkg" "$PACKAGE_SWIFT_PATH"
  trap - EXIT
fi

tmp_file=$(mktemp)
trap 'rm -f "$tmp_file"' EXIT

entry_escaped=${entry//$'\n'/\\n}

awk -v entry_escaped="$entry_escaped" -v version="$version" '
  BEGIN {
    entry = entry_escaped
    gsub(/\\n/, "\n", entry)
    inserted = 0
    saw_unreleased = 0
  }
  {
    if ($0 ~ /^## \[Unreleased\]/) {
      saw_unreleased = 1
    } else if (!inserted && saw_unreleased && $0 ~ /^## \[/) {
      printf("\n%s\n", entry)
      inserted = 1
    }
    print $0
  }
  END {
    if (!inserted) {
      printf("\n%s\n", entry)
    }
  }
' "$CHANGELOG_PATH" > "$tmp_file"

mv "$tmp_file" "$CHANGELOG_PATH"
trap - EXIT

printf '%s\n' "$entry"
