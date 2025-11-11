#!/usr/bin/env bash
set -euo pipefail

log() { printf "\033[1;34m[configure]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[warn]\033[0m %s\n" "$*"; }
err() { printf "\033[1;31m[error]\033[0m %s\n" "$*"; }

if [[ "$(uname -s)" != "Darwin" ]]; then
  err "This setup script is intended for macOS. Detected: $(uname -s)."
  exit 1
fi

if ! xcode-select -p >/dev/null 2>&1; then
  warn "Xcode Command Line Tools not found. Please run: xcode-select --install"
fi

if ! command -v brew >/dev/null 2>&1; then
  cat <<MSG
Homebrew not found. Please install Homebrew first:
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
Then re-run: make configure
MSG
  exit 1
fi

log "Updating Homebrew (safe preinstall update)"
brew update --preinstall >/dev/null 2>&1 || true

FORMULAS=(swiftlint swiftformat shellcheck markdownlint-cli)

for pkg in "${FORMULAS[@]}"; do
  if brew list --formula "$pkg" >/dev/null 2>&1; then
    log "Already installed: $pkg"
  else
    log "Installing: $pkg"
    brew install "$pkg"
  fi
done

log "Verifying tools"
for cmd in swiftlint swiftformat shellcheck markdownlint; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    warn "$cmd not on PATH after install. Ensure Homebrew paths are configured."
  else
    "$cmd" --version >/dev/null 2>&1 || true
  fi
done

cat <<'DONE'

Dependencies installed.

Try:
  make fmt-check   # check Swift formatting
  make fmt         # format Swift sources
  make lint        # full lint suite

DONE
