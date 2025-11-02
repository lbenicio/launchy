# Launchy Technical Guide

This guide consolidates the information needed to build, test, deploy, and extend Launchy. It complements the top-level `README.md` with deeper engineering context and cross-links to focused documents under `docs/`.

## Contents

1. [Product Overview](#product-overview)
2. [Architecture Summary](#architecture-summary)
3. [Runtime Behaviour](#runtime-behaviour)
4. [Persistence & Settings](#persistence--settings)
5. [Build, Tooling & Automation](#build-tooling--automation)
6. [Testing & Quality Gates](#testing--quality-gates)
7. [Development Practices](#development-practices)
8. [Release & Operations](#release--operations)
9. [Reference](#reference)

---

## Product Overview

Launchy is a macOS 13+ SwiftUI application that mirrors the system Launchpad experience. It surfaces a searchable grid of installed applications, supports drag-and-drop reordering, and allows grouping apps into folders. The project targets the modern Swift toolchain (Swift 6.2) and relies on AppKit interop for window management, keyboard handling, and folder modals.

Key technologies:

- Swift 6.2, SwiftUI, and Combine for UI and state propagation
- AppKit for window configuration, keyboard events, and Finder integration
- Swift Package Manager for dependency and build orchestration
- GitHub Actions workflows (unit tests, lint/format) for continuous integration

## Architecture Summary

Launchy follows a layered setup described in detail in [`architecture.md`](architecture.md). At a glance:

- **Interface (`src/Interface`)**: SwiftUI entry point (`LaunchyApp`), primary content surface (`ContentView`), and supporting view components (`AppIconView`, `FolderOverlay`, `SettingsView`, etc.).
- **Application (`src/Application`)**: Observable stores (`AppCatalogStore`, `AppSettings`) that own application state, coordinate async work, and bridge user interactions with infrastructure services.
- **Domain (`src/Domain`)**: Pure models (`AppItem`, `FolderItem`, `CatalogEntry`) plus lightweight helpers that remain platform agnostic.
- **Infrastructure (`src/Infrastructure`)**: System integrations such as catalog discovery (`AppCatalogLoader`), persistence (`LayoutPersistence`), accessibility permissions, keyboard monitoring, window configuration, and icon caching.

Source and test trees share the same folder layout (`src/<Module>` mirrored by `tests/<Module>`). Each Swift file has at least one corresponding XCTest covering critical behaviours or hosting guarantees.

## Runtime Behaviour

### Catalog Loading

- `AppCatalogLoader` scans standard application directories asynchronously, creating `AppItem` and `FolderItem` values.
- `AppCatalogStore.reloadCatalog()` merges fresh results with the persisted layout via `LayoutPersistence` before publishing `rootEntries`.

### Grid Interaction & Editing

- `ContentView` computes layout metrics dynamically (see `GridMetricsCalculator`) to size tiles based on user preferences and available screen real estate.
- Drag gestures leverage `AppCatalogStore` helpers (`beginDragging`, `moveEntry`, `mergeEntry`) to reorder entries or create folders.
- Folder overlays animate open/close transitions and support intra-folder drag-out via `FolderOverlay` and `FolderEditableAppTile`.

### Search & Keyboard

- The search field gains focus on launch and after exiting editing operations.
- `KeyboardMonitor` installs local and (when permitted) global event taps so ESC, Return, and text entry are handled consistently even when Launchy is not key.
- ESC flow: exits edit mode, closes folder overlays, clears search text, and only then terminates the app if no other context applies.

### Window Management

- `TransparentWindowConfigurator` converts the primary SwiftUI window into a full-screen, borderless overlay anchored to the active display and raised to the custom `launchyPrimary` level.
- `AuxiliaryWindowConfigurator` ensures secondary windows (settings, alerts) appear above the overlay at the `launchyAuxiliary` level.

## Persistence & Settings

- `AppSettings` persists grid columns, rows, and scroll sensitivity in `UserDefaults`. Values are clamped within predefined ranges to keep the UI responsive.
- Layout customisation is captured in `LayoutPersistence.Snapshot`, written to `~/Library/Application Support/Launchy/layout.json` (or a custom URL when injected for testing).
- Accessibility prompts are requested through `AccessibilityPermission`. Tests bypass dialogs by detecting when the XCTest environment is active.

## Build, Tooling & Automation

### Local commands

- `swift build`, `swift run Launchy`, and `swift test` are the canonical SPM commands.
- The `Makefile` provides convenience wrappers: `make build`, `make release`, `make run`, `make test`, `make bundle`, `make format`, `make lint`, and `make deploy`.
- Optional code quality tools (`swiftformat`, `swiftlint`) can be installed via Homebrew. Targets skip gracefully when the binaries are absent.

### Continuous Integration

- `.github/workflows/unit-tests.yml` installs the Swift 6.2 toolchain on Ubuntu 22.04, verifies the download signature, and runs `make test`.
- `.github/workflows/lint-format.yml` enforces formatting/linting inside a Linux container using the same toolchain.
- Both workflows are compatible with `act` (tested using `--container-architecture linux/amd64`); allow the Swift tarball download to finish on first run.

## Testing & Quality Gates

- Unit tests reside in `tests/`, mirroring the `src/` structure (e.g., `tests/Interface/Views/ContentViewTests.swift`). They cover model behaviours, store state transitions, persistence round-trips, SwiftUI hosting, and infrastructure utilities.
- Utility helpers (`KeyboardMonitor.resetForTesting`, `AccessibilityPermission.resetPromptStateForTesting`) exist solely behind `#if DEBUG` to keep production binaries clean.
- Run the full suite with `swift test` (macOS) or via the CI workflow for Linux validation.

## Development Practices

- Adhere to Swift API Design Guidelines and Apple Human Interface Guidelines.
- Prefer value types for domain models; keep AppKit-specific logic in infrastructure components.
- Keep animations and Combine publishers on the main actor to avoid UI glitches.
- Introduce succinct comments only where code intent is non-obvious (drag state machines, persistence reconciliation, etc.).
- When introducing new files under `src/`, add matching tests under `tests/` and update `structure.md` if directory layouts change.

## Release & Operations

- `scripts/deploy` (invoked via `make deploy`) merges `develop` into `main`, executes a release build, and pushes tags/branches. Use `DEPLOY_ARGS="--dry-run"` for rehearsal.
- Production builds are created with `make release` followed by `make bundle` to package the `.app` bundle in `.build/dist`.
- Keep the working tree clean before deploying; the script enforces it unless running in dry-run mode.

## Reference

- [`architecture.md`](architecture.md) – Layered design, data flow, lifecycle deep dive.
- [`structure.md`](structure.md) – Directory map and per-file summaries.
- [`testing.md`](testing.md) – XCTest organisation, execution tips, and contribution checklist.
- [`build-and-release.md`](build-and-release.md) – Tooling, packaging, and deployment procedures.
- [`ui-components.md`](ui-components.md) – Breakdown of views, interactions, and window configuration.
- `.github/workflows/` – CI definitions for tests and formatting.
- `scripts/deploy` – Release automation source.
- `tests/` – Comprehensive XCTest coverage aligned with the production modules.

For onboarding, start with the repository `README.md`, follow with this document, then explore the focused guides above. Reach out via pull requests or issues for clarifications not captured here.
