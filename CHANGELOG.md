# Changelog

All notable changes to this repository will be documented in this file.

The format is based on "Keep a Changelog" and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.4.0] - 2025-11-29

### Added

- New lightweight vanilla static landing page under `lannding-page/` with HTML/CSS/JS and README. (Note: directory intentionally spelled `lannding-page`.)
- Persistent windowed layout: last window size and last visited page are now stored and restored in windowed mode.
- Settings UI improvements and localized grid tuning options.

### Changed

- Rebranded core product strings to **Launchy** from Tahoe Launchpad (package/product names, README, security, issue templates, VS Code tasks, and build targets).
- `Package.swift`, build and test targets renamed to `Launchy`/`LaunchyTests`.
- Application Support path changed to use `Launchy` (previously `TahoeLaunchpad`).
- Migration of persisted keys and UTType identifiers to `dev.lbenicio.launchy` domain where appropriate.
- `GridSettingsStore` defaults key updated to `dev.lbenicio.launchy.grid-settings`.

### Fixed

- Prevent recursive persistence loop caused by settings updates triggering page persistence — `ensureCurrentPageInBounds` now accepts a `shouldPersist` flag.
- Cleaned up temporary debug prints added during debugging.

### Tests

- Updated test imports and target names to `Launchy`. Existing unit tests pass.

### Notes

- Internal types and file names still use `Launchpad*` (e.g., `LaunchpadViewModel`) to denote the UI concept; these were not renamed and remain as internal API.
- If you want a follow-up to rename internal symbol names to `Launchy*`, this is a larger refactor and can be performed on request.
