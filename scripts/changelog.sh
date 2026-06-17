#!/usr/bin/env bash
set -euo pipefail

# release_changelog.sh (ported from scripts/release.js)
# Usage: ./scripts/changelog.sh <major|minor|patch>
# - Bumps APP_VERSION in .env (source-of-truth)
# - Generates a CHANGELOG.md entry with categorized commits (feat, fix, chore, others)
# - Inserts the new entry after the main header in CHANGELOG.md
# Note: This script does NOT create commits or tags; it prints the git commands to run next.

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <major|minor|patch>"
  exit 2
fi

BUMP="$1"

if [[ "$BUMP" != "major" && "$BUMP" != "minor" && "$BUMP" != "patch" ]]; then
  echo "Invalid bump type: $BUMP. Expected major, minor, or patch."
  exit 2
fi

# Ensure clean working tree
if [ -n "$(git status --porcelain)" ]; then
  echo "Working tree is dirty. Please commit or stash changes before running this script."
  git status --porcelain
  exit 1
fi

# Read current version from .env (APP_VERSION); fallback to latest tag or 0.0.0
if [ -f ".env" ]; then
  CURRENT_VERSION=$(grep -E '^APP_VERSION=' .env | head -n1 | cut -d= -f2 || true)
fi

if [ -z "${CURRENT_VERSION:-}" ]; then
  LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || true)
  if [ -n "${LATEST_TAG}" ]; then
    CURRENT_VERSION=${LATEST_TAG#v}
  else
    CURRENT_VERSION="0.0.0"
  fi
fi

IFS='.' read -r MAJOR MINOR PATCH <<< "${CURRENT_VERSION}"
MAJOR=${MAJOR:-0}
MINOR=${MINOR:-0}
PATCH=${PATCH:-0}

case "$BUMP" in
  major)
    MAJOR=$((MAJOR + 1))
    MINOR=0
    PATCH=0
    ;;
  minor)
    MINOR=$((MINOR + 1))
    PATCH=0
    ;;
  patch)
    PATCH=$((PATCH + 1))
    ;;
esac

NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"

echo "Bumping version from ${CURRENT_VERSION} to ${NEW_VERSION}..."

# Update APP_VERSION in .env (create if missing)
update_env_file() {
  local file="$1"
  if [ -f "$file" ]; then
    if grep -q '^APP_VERSION=' "$file"; then
      awk -v v="${NEW_VERSION}" 'BEGIN{OFS=FS} { if ($0 ~ /^APP_VERSION=/) { print "APP_VERSION=" v } else print }' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
    else
      echo "APP_VERSION=${NEW_VERSION}" >> "$file"
    fi
  else
    echo "APP_VERSION=${NEW_VERSION}" > "$file"
  fi
}

update_env_file ".env"

# Get commits since last tag
LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || true)
if [ -n "${LATEST_TAG}" ]; then
  COMMIT_RANGE="${LATEST_TAG}..HEAD"
else
  COMMIT_RANGE="HEAD"
fi

COMMITS_RAW=""
if COMMITS_RAW=$(git log ${COMMIT_RANGE} --pretty=format:"%s" --no-merges 2>/dev/null); then
  :
else
  echo "No previous tags found or git log failed, using all commits (limited to last 20)"
  COMMITS_RAW=$(git log --pretty=format:"%s" --no-merges 2>/dev/null | head -n 20)
fi

# Split into lines and categorize
features=""
fixes=""
chores=""
others=""

while IFS= read -r line; do
  [ -z "${line}" ] && continue
  desc="${line}"
  lc_desc=$(printf '%s' "$desc" | tr '[:upper:]' '[:lower:]')
  if [[ $lc_desc =~ ^feat(\(.*\))?: ]]; then
    short=$(printf '%s' "$desc" | sed -E 's/^[Ff][Ee][Aa][Tt]([[:space:]]*\([^)]*\))?:[[:space:]]*//')
    features+="- ${short}"$'\n'
  elif [[ $lc_desc =~ ^fix(\(.*\))?: ]]; then
    short=$(printf '%s' "$desc" | sed -E 's/^[Ff][Ii][Xx]([[:space:]]*\([^)]*\))?:[[:space:]]*//')
    fixes+="- ${short}"$'\n'
  elif [[ $lc_desc =~ ^chore(\(.*\))?: ]]; then
    short=$(printf '%s' "$desc" | sed -E 's/^[Cc][Hh][Oo][Rr][Ee]([[:space:]]*\([^)]*\))?:[[:space:]]*//')
    chores+="- ${short}"$'\n'
  else
    others+="- ${desc}"$'\n'
  fi
done <<< "${COMMITS_RAW}"

# Build changelog sections
sections=""
if [ -n "${features}" ]; then
  sections+=$'### Features\n\n'"${features}"$'\n'
fi
if [ -n "${fixes}" ]; then
  sections+=$'### Bug Fixes\n\n'"${fixes}"$'\n'
fi
if [ -n "${chores}" ]; then
  sections+=$'### Chores\n\n'"${chores}"$'\n'
fi
if [ -n "${others}" ]; then
  sections+=$'### Other Changes\n\n'"${others}"$'\n'
fi

if [ -z "${sections}" ]; then
  sections="- No notable changes"
fi

DATE=$(date -u +%Y-%m-%d)
CHANGELOG_ENTRY=$(printf "## [%s] - %s\n\n%s" "${NEW_VERSION}" "${DATE}" "${sections}")

# Insert changelog entry after the main header in CHANGELOG.md
CHANGELOG_FILE=CHANGELOG.md
if [ -f "${CHANGELOG_FILE}" ]; then
  # Find first '##' line (release entries); insert before it
  FIRST_RELEASE_LINE=$(grep -n "^##" "${CHANGELOG_FILE}" | head -n1 | cut -d: -f1 || true)
  TMPFILE=$(mktemp)
  if [ -n "${FIRST_RELEASE_LINE}" ] && [ "${FIRST_RELEASE_LINE}" -gt 1 ]; then
    head -n $((FIRST_RELEASE_LINE-1)) "${CHANGELOG_FILE}" > "${TMPFILE}"
    printf "%s\n\n" "${CHANGELOG_ENTRY}" >> "${TMPFILE}"
    tail -n +${FIRST_RELEASE_LINE} "${CHANGELOG_FILE}" >> "${TMPFILE}"
  else
    # No existing releases found, prepend to top
    printf "# Changelog\n\nAll notable changes to this project will be documented in this file.\n\n" > "${TMPFILE}"
    printf "%s\n\n" "${CHANGELOG_ENTRY}" >> "${TMPFILE}"
    if [ -s "${CHANGELOG_FILE}" ]; then
      cat "${CHANGELOG_FILE}" >> "${TMPFILE}"
    fi
  fi
  mv "${TMPFILE}" "${CHANGELOG_FILE}"
else
  # Create changelog from scratch
  cat > "${CHANGELOG_FILE}" <<EOF
# Changelog

All notable changes to this project will be documented in this file.

${CHANGELOG_ENTRY}
EOF
fi

# Final output
echo ""
echo "✅ Version bumped to ${NEW_VERSION}"
echo "✅ .env and updated"
echo "✅ CHANGELOG.md updated"
echo ""
echo "Next steps:"
echo "  1. Review CHANGELOG.md and .env files"
echo "  2. git add CHANGELOG.md .env"
echo "  3. git commit -m \"chore: release v${NEW_VERSION}\""
echo "  4. git tag -a v${NEW_VERSION} -m \"Release v${NEW_VERSION}\""
echo "  5. git push && git push --tags"
