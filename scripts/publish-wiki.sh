#!/usr/bin/env bash
# scripts/publish-wiki.sh
# Publish the local docs/ folder to this repo's GitHub Wiki.
# - Prefers SSH locally, token HTTPS in CI (GITHUB_ACTIONS)
# - Supports --create (enable wiki and bootstrap empty repo if needed)
# - Supports --dry-run (print what would run)
# - Options: --docs <dir>, --branch <name>, --verbose

set -euo pipefail

# Defaults
DRY=0
CREATE=0
BRANCH="main"
VERBOSE=0
DOCS_DIR=""

# Env tokens (any of these will work)
TOKEN="${GITHUB_TOKEN:-${GITHUB_PAT:-${GH_TOKEN:-${PERSONAL_TOKEN:-}}}}"

log() { printf '[publish-wiki] %s\n' "$*"; }
err() { printf '[publish-wiki] %s\n' "$*" 1>&2; }

run() {
  local cmd="$*"
  if [[ "$DRY" == "1" ]]; then log "[dry-run] $cmd"; return 0; fi
  [[ "$VERBOSE" == "1" ]] && log "run: $cmd"
  eval "$cmd"
}

run_capture() {
  local cmd="$*"
  if [[ "$DRY" == "1" ]]; then echo ""; return 0; fi
  set +e
  local out
  out=$(eval "$cmd" 2>/dev/null)
  local code=$?
  set -e
  if [[ $code -ne 0 ]]; then echo ""; return 0; fi
  printf '%s' "$out"
}

mask_token() {
  local u="$1"
  [[ -z "$u" ]] && { echo "$u"; return; }
  # https://user:token@github.com/... -> mask middle
  echo "$u" | sed -E 's#(https://)[^:]+:[^@]+@#\1***:***@#'
}

usage() {
  cat <<EOF
Usage: $0 [options]
  --docs <dir>      Source docs directory (default: auto-detect)
  --branch <name>   Wiki branch (default: main)
  --dry-run|-d      Print commands only
  --create|-c       Enable wiki / bootstrap repo if needed
  --verbose         Verbose logging
  -h|--help         Show help
EOF
}

# Parse args (support long options)
while [[ $# -gt 0 ]]; do
  case "$1" in
    --docs) DOCS_DIR="${2:-}"; shift 2 ;;
    --docs=*) DOCS_DIR="${1#*=}"; shift ;;
    --branch) BRANCH="${2:-}"; shift 2 ;;
    --branch=*) BRANCH="${1#*=}"; shift ;;
    --dry-run|-d) DRY=1; shift ;;
    --create|-c) CREATE=1; shift ;;
    --verbose) VERBOSE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) err "Unknown option: $1"; usage; exit 2 ;;
  esac
done

# Discover docs dir if not provided
find_docs_dir() {
  local req="$1"
  local candidates=()
  [[ -n "$req" ]] && candidates+=("$(cd "$req" 2>/dev/null && pwd || true)")
  candidates+=("$(pwd)/docs" "$(pwd)/src/docs" "$(pwd)/content" "$(pwd)/src/content")
  local c
  for c in "${candidates[@]}"; do
    if [[ -d "$c" ]]; then echo "$c"; return 0; fi
  done
  echo ""
}

DOCS_DIR="$(find_docs_dir "$DOCS_DIR")"
if [[ -z "$DOCS_DIR" ]]; then err "docs directory not found"; exit 1; fi

# Resolve owner/repo from git remote
resolve_owner_repo() {
  local url
  url="$(run_capture 'git remote get-url origin')"
  url="${url%%$'\n'*}"
  if [[ -n "$url" ]]; then
    if [[ "$url" =~ github.com[:/]{1}([^/]+)/([^\.]+)(\.git)?$ ]]; then
      echo "${BASH_REMATCH[1]} ${BASH_REMATCH[2]} $url"
      return 0
    fi
  fi
  err "unable to determine owner/repo (configure git remote origin)"
  return 1
}

read OWNER REPO REMOTE_URL < <(resolve_owner_repo)
WIKI_REPO="${REPO}.wiki.git"

GITHUB_ACTIONS_FLAG="${GITHUB_ACTIONS:-}"
SSH_URL="git@github.com:${OWNER}/${WIKI_REPO}"
HTTPS_AUTH_URL=""
if [[ -n "$TOKEN" ]]; then HTTPS_AUTH_URL="https://x-access-token:${TOKEN}@github.com/${OWNER}/${WIKI_REPO}"; fi
HTTPS_PLAIN_URL="https://github.com/${OWNER}/${WIKI_REPO}"

PREFS=()
if [[ -n "$GITHUB_ACTIONS_FLAG" ]]; then
  # prefer token HTTPS on CI
  [[ -n "$HTTPS_AUTH_URL" ]] && PREFS+=("$HTTPS_AUTH_URL")
  PREFS+=("$SSH_URL" "$HTTPS_PLAIN_URL")
else
  # prefer SSH locally
  PREFS+=("$SSH_URL")
  [[ -n "$HTTPS_AUTH_URL" ]] && PREFS+=("$HTTPS_AUTH_URL")
  PREFS+=("$HTTPS_PLAIN_URL")
fi

log "owner/repo: ${OWNER}/${REPO}"
log "docs source: ${DOCS_DIR}"
# shellcheck disable=SC2068
log "preferred remotes: $(for u in ${PREFS[@]}; do [[ -n "$u" ]] && printf '%s ' "$(mask_token "$u")"; done)"

# Workdir
TMPDIR_ROOT="${TMPDIR:-/tmp}"
WORK_ROOT="$(mktemp -d "${TMPDIR_ROOT%/}/wiki.XXXXXX")"
WORK_DIR="${WORK_ROOT}/wiki"
CLEANUP() { [[ "$DRY" == "1" ]] && return 0; rm -rf "$WORK_ROOT" || true; }
trap CLEANUP EXIT

cloned=0
used_remote=""

# Optionally ensure wiki is enabled on the repo
ensure_wiki_enabled() {
  [[ "$CREATE" != "1" ]] && return 0
  if command -v gh >/dev/null 2>&1; then
    log "enabling wiki via gh CLI"
    if [[ "$DRY" == "1" ]]; then log "[dry-run] gh repo edit ${OWNER}/${REPO} --enable-wiki"; else gh repo edit "${OWNER}/${REPO}" --enable-wiki || true; fi
    return 0
  fi
  if [[ -n "$TOKEN" ]]; then
    log "enabling wiki via GitHub API"
    local url="https://api.github.com/repos/${OWNER}/${REPO}"
    if [[ "$DRY" == "1" ]]; then
      log "[dry-run] PATCH $url { has_wiki: true }"
    else
      curl -sS -X PATCH -H "Authorization: token ${TOKEN}" -H "Accept: application/vnd.github.v3+json" -H "Content-Type: application/json" -d '{"has_wiki": true}' "$url" >/dev/null || true
    fi
  fi
}

ensure_wiki_enabled

# Try clone in order of preference
for url in "${PREFS[@]}"; do
  [[ -z "$url" ]] && continue
  log "attempting clone $(mask_token "$url")"
  if [[ "$DRY" == "1" ]]; then
    run "mkdir -p \"$WORK_DIR\""
    cloned=1; used_remote="$url"; break
  fi
  if git clone "$url" "$WORK_DIR" 2>/dev/null; then
    cloned=1; used_remote="$url"; break
  else
    [[ "$VERBOSE" == "1" ]] && err "clone failed for $(mask_token "$url")"
  fi
done

# Fallback to gh
if [[ $cloned -eq 0 ]] && command -v gh >/dev/null 2>&1; then
  log "gh CLI detected, attempting gh repo clone fallback"
  if [[ "$DRY" == "1" ]]; then
    run "mkdir -p \"$WORK_DIR\""
    cloned=1; used_remote="gh";
  else
    if gh repo clone "${OWNER}/${REPO}.wiki" "$WORK_DIR"; then cloned=1; used_remote="gh"; fi
  fi
fi

# If still not cloned, initialize a new repo and add remote
if [[ $cloned -eq 0 ]]; then
  log "initializing new git repo at $WORK_DIR"
  run "mkdir -p \"$WORK_DIR\""
  (cd "$WORK_DIR" && run git init)
  # Choose the best available remote
  remote="${HTTPS_AUTH_URL:-$SSH_URL}"
  [[ -z "$remote" ]] && remote="$HTTPS_PLAIN_URL"
  if [[ -z "$remote" ]]; then err "no remote available (need token or ssh)"; exit 2; fi
  (cd "$WORK_DIR" && run git remote add origin "$remote")
  used_remote="$remote"
fi

# Empty workdir except .git
if [[ -d "$WORK_DIR" ]]; then
  shopt -s dotglob nullglob
  for entry in "$WORK_DIR"/*; do
    base="$(basename "$entry")"
    [[ "$base" == ".git" ]] && continue
    run rm -rf "$entry"
  done
  shopt -u dotglob nullglob
fi

log "copying docs into wiki workdir"
# Use tar to preserve dotfiles without extra deps
if [[ "$DRY" == "1" ]]; then
  log "[dry-run] copy $DOCS_DIR -> $WORK_DIR"
else
  (cd "$DOCS_DIR" && tar cf - .) | (cd "$WORK_DIR" && tar xpf -)
fi

# Ensure Home.md from README.md if missing
if [[ -f "$WORK_DIR/README.md" && ! -f "$WORK_DIR/Home.md" ]]; then
  run cp "$WORK_DIR/README.md" "$WORK_DIR/Home.md"
  log "created Home.md from README.md"
fi

# Commit and push
(cd "$WORK_DIR" && run git add -A)
if [[ "$DRY" != "1" ]]; then
  changes=$(run_capture "git -C '$WORK_DIR' status --porcelain")
  if [[ -z "$changes" ]]; then log "no changes to publish"; exit 0; fi
fi

# Commit message; tolerate empty commit failures
(cd "$WORK_DIR" && { run "git commit -m 'Update wiki from docs/'" || true; })

# Branch and push
(cd "$WORK_DIR" && run git checkout -B "$BRANCH")
(cd "$WORK_DIR" && run git push -u origin "$BRANCH" --force)

log "push completed"
