#!/bin/bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/sync_docs_to_wiki.sh [options]

Synchronizes the local docs directory into the repository's GitHub Wiki.
Options:
  --docs-dir <path>      Path to the docs directory (default: docs)
  --commit-message <msg> Commit message to use for the wiki sync
  --no-push              Do not push changes to the wiki remote
  --dry-run              Show what would change without committing or pushing
  -h, --help             Show this help message and exit
EOF
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCS_DIR="docs"
COMMIT_MESSAGE=""
PUSH_CHANGES=1
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --docs-dir)
      [[ $# -ge 2 ]] || { echo "error: --docs-dir requires a value" >&2; exit 1; }
      DOCS_DIR="$2"
      shift 2
      ;;
    --commit-message)
      [[ $# -ge 2 ]] || { echo "error: --commit-message requires a value" >&2; exit 1; }
      COMMIT_MESSAGE="$2"
      shift 2
      ;;
    --no-push)
      PUSH_CHANGES=0
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      PUSH_CHANGES=0
      shift
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

SOURCE_DIR="$ROOT_DIR/$DOCS_DIR"
[[ -d "$SOURCE_DIR" ]] || { echo "error: docs directory '$SOURCE_DIR' not found" >&2; exit 1; }

ORIGIN_URL="$(git -C "$ROOT_DIR" remote get-url origin 2>/dev/null || true)"
[[ -n "$ORIGIN_URL" ]] || { echo "error: could not determine origin remote" >&2; exit 1; }

case "$ORIGIN_URL" in
  git@github.com:*.git)
    REPO_PATH="${ORIGIN_URL#git@github.com:}"
    REPO_PATH="${REPO_PATH%.git}"
    WIKI_URL="git@github.com:${REPO_PATH}.wiki.git"
    ;;
  git@github.com:*)
    REPO_PATH="${ORIGIN_URL#git@github.com:}"
    WIKI_URL="git@github.com:${REPO_PATH}.wiki.git"
    ;;
  https://github.com/*.git)
    REPO_PATH="${ORIGIN_URL#https://github.com/}"
    REPO_PATH="${REPO_PATH%.git}"
    WIKI_URL="https://github.com/${REPO_PATH}.wiki.git"
    ;;
  https://github.com/*)
    REPO_PATH="${ORIGIN_URL#https://github.com/}"
    WIKI_URL="https://github.com/${REPO_PATH}.wiki.git"
    ;;
  ssh://git@github.com/*.git)
    REPO_PATH="${ORIGIN_URL#ssh://git@github.com/}"
    REPO_PATH="${REPO_PATH%.git}"
    WIKI_URL="ssh://git@github.com/${REPO_PATH}.wiki.git"
    ;;
  ssh://git@github.com/*)
    REPO_PATH="${ORIGIN_URL#ssh://git@github.com/}"
    WIKI_URL="ssh://git@github.com/${REPO_PATH}.wiki.git"
    ;;
  *)
    echo "error: unsupported origin remote '$ORIGIN_URL'" >&2
    exit 1
    ;;
esac

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

WIKI_DIR="$WORK_DIR/wiki"

git clone "$WIKI_URL" "$WIKI_DIR" >/dev/null

find "$WIKI_DIR" -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} +

DOC_FOUND=0
while IFS= read -r -d '' FILE; do
  DOC_FOUND=1
  BASENAME="$(basename "$FILE")"
  LOWER_BASENAME="$(printf '%s' "$BASENAME" | tr '[:upper:]' '[:lower:]')"
  if [[ "$LOWER_BASENAME" == "readme.md" ]]; then
    DEST_NAME="Home.md"
  else
    DEST_NAME="$BASENAME"
  fi
  cp "$FILE" "$WIKI_DIR/$DEST_NAME"
done < <(find "$SOURCE_DIR" -maxdepth 1 -type f -name '*.md' -print0)

if [[ $DOC_FOUND -eq 0 ]]; then
  echo "error: no markdown files found in '$SOURCE_DIR'" >&2
  exit 1
fi

if [[ $DRY_RUN -eq 1 ]]; then
  git -C "$WIKI_DIR" status --short
  git -C "$WIKI_DIR" diff
  exit 0
fi

if git -C "$WIKI_DIR" status --short | grep -q .; then
  git -C "$WIKI_DIR" add .
  if [[ -z "$COMMIT_MESSAGE" ]]; then
    COMMIT_MESSAGE="docs: sync wiki $(date +%F)"
  fi
  git -C "$WIKI_DIR" commit -m "$COMMIT_MESSAGE"
  if [[ $PUSH_CHANGES -eq 1 ]]; then
    git -C "$WIKI_DIR" push origin HEAD
  else
    echo "Changes staged locally; push skipped (--no-push)."
  fi
else
  echo "Wiki already up to date."
fi
