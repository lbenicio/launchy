# Project Structure

This document maps the Launchy repository layout and highlights the responsibility of key files. Use it as a quick reference when navigating the codebase.

## Top-Level Layout

```text
.
|-- assets/                  # Static resources (icons, plist templates)
|-- docs/                    # Engineering documentation (this directory)
|-- scripts/                 # Developer automation (deploy, tooling helpers)
|-- src/                     # Application source code (Swift Package target)
|-- tests/                   # XCTest target mirroring the source layout
|-- .github/                 # Issue templates and CI workflows
|-- CODE_OF_CONDUCT.md
|-- CONTRIBUTING.md
|-- LICENSE.txt
|-- Makefile
|-- Package.swift
|-- README.md
|-- SECURITY.md
```

## Source Tree (`src/`)

`src/` contains the executable target `Launchy`, separated into four top-level modules. Each folder should be mirrored in `tests/` with equivalent subdirectories.

### `Application/`

- `AppCatalogStore.swift`
  - Main `@MainActor` store that fetches the catalog, manages drag-and-drop, folder presentation, and dismiss/escape flows.
- `AppSettings.swift`
  - `ObservableObject` wrapping `UserDefaults` values for grid dimensions and scroll sensitivity with automatic clamping and persistence.

### `Domain/`

- `Models.swift`
  - Declares `AppItem`, `FolderItem`, and `CatalogEntry` value types plus convenience accessors used throughout the app and tests.

### `Infrastructure/`

- `configurators/WindowConfigurator.swift`
  - Defines helper representables to configure NSWindow levels (`launchyPrimary`, `launchyAuxiliary`) for the overlay and auxiliary windows.
- `loaders/AppCatalogLoader.swift`
  - Scans standard application directories, produces `CatalogEntry` arrays, and normalises bundle metadata.
- `managers/SettingsWindowManager.swift`
  - Owns the AppKit settings window lifecycle, presenting a SwiftUI `SettingsView` inside an auxiliary-level window.
- `monitors/KeyboardMonitor.swift`
  - Installs local/global keyboard monitors (with optional accessibility permission) and exposes test-only reset helpers behind `#if DEBUG`.
- `permissions/AccessibilityPermission.swift`
  - Requests accessibility prompts when needed and skips prompting inside automated tests.
- `persistence/LayoutPersistence.swift`
  - Loads and saves layout snapshots asynchronously, ensuring folder/app ordering survives relaunches.
- `stores/IconStore.swift`
  - Caches `NSImage` icons retrieved from application bundles to avoid repeated lookups.

### `Interface/`

- `App/LaunchyApp.swift`
  - SwiftUI entry point containing `LaunchyApp` and `AppLifecycleDelegate` that manage activation policy, presentation options, and window visibility.
- `Views/ContentView.swift`
  - Core overlay view responsible for pagination, drag-and-drop, folder presentation, and search field focus management.
- `Views/AppIconView.swift`
  - Renders app and folder tiles, including hover states, context menus, and rename prompts.
- `Views/FolderOverlay.swift`
  - Presents folder contents in an animated overlay, handling drag state and pagination inside folders.
- `Views/GridMetrics.swift`
  - Supplies sizing logic shared across grid surfaces.
- `Views/SettingsView.swift`
  - SwiftUI preferences UI backed by `AppSettings`.
- `Views/components/VisualEffectView.swift`
  - NSViewRepresentable wrapper for configurating `NSVisualEffectView` instances.

## Tests (`tests/`)

The `LaunchyTests` target mirrors the `src/` layout. Highlights:

- `Application/AppCatalogStoreTests.swift` – verifies store state transitions for editing, folder dismissal, and drag scaffolding.
- `Application/AppSettingsTests.swift` – ensures user defaults integration and clamping logic work under test suites.
- `Domain/ModelsTests.swift` – validates value semantics and identifier derivation.
- `Infrastructure/*Tests.swift` – covers catalog loading, layout persistence, accessibility permissions, keyboard monitoring, icon caching, and window configurators.
- `Interface/*Tests.swift` – asserts SwiftUI views can be hosted inside `NSHostingView` and that lifecycle delegates adjust presentation options correctly.

Tests invoke production types directly and rely on debug-only helpers guarded by compilation flags to avoid shipping testing logic.

## Scripts

- `scripts/deploy`
  - Merge-orchestrated release helper with `--dry-run` support. Employs `set -euo pipefail` safeguards and performs release builds before pushing.

## Assets

- `assets/icon/launchy.icns`
  - Launchy application icon embedded in bundled builds.
- `assets/plist/Info.plist.template`
  - Template consumed by the Makefile when constructing `.app` bundles.

## Documentation (`docs/`)

- `README.md`
  - Comprehensive engineering handbook with build/test/ops guidance.
- `architecture.md`
  - Layered architecture, data flow, runtime lifecycle, and resilience strategies.
- `structure.md`
  - (This file) Directory-level map and responsibilities.

## Makefile Targets

The Makefile wraps common tasks:

| Target          | Description                                 |
|-----------------|---------------------------------------------|
| `make build`    | Debug build via `swift build`                |
| `make release`  | Optimised build into `.build/release/`       |
| `make bundle`   | Assemble `.app` bundle in `.build/dist`      |
| `make run`      | Run the debug executable                     |
| `make test`     | Execute unit tests                           |
| `make format`   | Run `swiftformat` when available             |
| `make lint`     | Run `swiftlint` when available               |
| `make deploy`   | Merge and release using `scripts/deploy`     |

## Configuration Files

- `.editorconfig` – Editor defaults (indentation, line endings)
- `.vscode/` – Workspace preferences for VS Code (if present)
- `.github/` – Issue/PR templates and GitHub Actions workflows

## Where to Start

- Read the repository `README.md` for onboarding.
- Review this document and [`docs/architecture.md`](architecture.md) for structural context.
- Explore `src/Interface/Views/ContentView.swift` to understand UI flow and user interactions.
- Inspect `src/Application/AppCatalogStore.swift` for state management and drag-and-drop orchestration.
- Refer to the mirrored test files under `tests/` for usage examples and behavioural expectations.
