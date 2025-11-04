# Build & Release Guide

This document captures the end-to-end process for building Launchy from source, packaging distributable artifacts, and promoting releases. It is intended for maintainers and contributors who need to verify changes or cut new versions.

## Prerequisites

- **macOS 13 or later** with Xcode Command Line Tools installed.
- **Swift 6.2 toolchain** (matching `swift-tools-version: 6.2` in `Package.swift`).
- **Git** for source control operations.
- Optional but recommended:
  - Homebrew packages `swiftformat` and `swiftlint` if you plan to run formatting and linting tasks.
  - [`act`](https://github.com/nektos/act) for local CI workflow rehearsal.

## Local Build Commands

### Source Build

```bash
swift build
# or, with Makefile wrapper
do make build
```

Artifacts are generated under `.build/debug/`.

### Run Launchy

```bash
swift run Launchy
# or
make run
```

The command launches the debug executable. To terminate, press `⌘Q` or use the Quit button in the menu bar.

### Unit Tests

```bash
swift test
# or
make test
```

Use `swift test --filter <TestCase>` to run focused suites.

## Bundled Application

Create a macOS `.app` bundle suitable for manual distribution:

```bash
make bundle
```

The bundle is produced at `.build/dist/Launchy.app`. The Makefile injects metadata from `assets/plist/Info.plist.template` and copies the project icon from `assets/icon/launchy.icns`.

## Release Builds

Generate an optimised binary prior to packaging or notarisation:

```bash
make release
```

Artifacts appear under `.build/release/`. Combine this with `make bundle` to produce a release-quality `.app` bundle.

## Deployment Automation

The `scripts/deploy` helper (wrapped by `make deploy`) orchestrates merging and releasing from `develop` to `main`.

```bash
make deploy
# Dry run (skips pushing)
make deploy DEPLOY_ARGS="--dry-run"
```

Steps performed:

1. Ensures the working tree is clean (unless `--dry-run` is passed).
2. Fetches the target remote (`origin` by default).
3. Fast-forwards the source (`develop`) and target (`main`) branches.
4. Creates a merge commit from source into target.
5. Runs `swift build -c release` as a verification gate.
6. Pushes the updated target branch to the remote (skipped in dry-run mode).

### Customising Deploy

Environment variables allow tailoring of the process:

| Variable           | Default  | Description                                   |
|--------------------|----------|-----------------------------------------------|
| `SOURCE_BRANCH`    | `develop`| Branch merged into the target.                |
| `TARGET_BRANCH`    | `main`   | Release branch.                               |
| `REMOTE_NAME`      | `origin` | Git remote used for fetch/push operations.    |
| `DEPLOY_ARGS`      | *(none)* | Extra arguments forwarded to `scripts/deploy`.|

Example:

```bash
make deploy SOURCE_BRANCH=release/v0.2.0 TARGET_BRANCH=main
```

## Versioning & Changelog

- Update the `packageVersion` constant in `Package.swift` and any user-facing version strings in `assets/plist/Info.plist.template` prior to release.
- Maintain the change log (if present) in the repository root—typically `CHANGELOG.md`.
- Tag releases after deployment, e.g.:

```bash
git tag -a v0.2.0 -m "Launchy 0.2.0"
git push origin v0.2.0
```

## Continuous Integration

Two GitHub Actions workflows backstop releases:

- `Unit Tests`: runs on pushes, PRs, and manual dispatch. Installs Swift 6.2 on Ubuntu 22.04 and executes `make test`.
- `Lint / Format`: downloads the same toolchain, fetches SwiftFormat/SwiftLint binaries, and runs formatting checks.

Rehearse these locally with `act` if you need to verify workflow changes.

## Pre-Release Checklist

- [ ] `swift test` and `make test` succeed.
- [ ] Formatting/linting tasks pass (or produce no diffs).
- [ ] `make bundle` produces a working `.app` on a clean system.
- [ ] Accessibility prompts and keyboard shortcuts function as expected.
- [ ] Documentation (`docs/`) reflects user-facing changes.
- [ ] `scripts/deploy --dry-run` completes without errors.

Completing these steps ensures the published build is reproducible and stable across supported environments.
