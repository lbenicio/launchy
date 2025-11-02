# Project Structure

This document describes the directory layout of the Launchy repository and summarises the purpose of the most important files.

## Top-Level Layout

```text
.
|-- assets/                # Static resources (icons, Info.plist templates)
|-- docs/                  # Project documentation (architecture, ops, etc.)
|-- scripts/               # Automation scripts (deployment, tooling)
|-- src/                   # Application source code
|-- CODE_OF_CONDUCT.md     # Community guidelines
|-- CONTRIBUTING.md        # Contribution workflow
|-- LICENSE.txt            # MIT license text
|-- Makefile               # Common build/test/deploy commands
|-- Package.swift          # Swift Package manifest
|-- README.md              # Project overview and quick start
|-- SECURITY.md            # Vulnerability reporting policy
```

## Source Tree (`src/`)

The `src/` directory is split into four primary modules. Each module has a focused responsibility.

### `Application/`

- `AppCatalogStore.swift`
  - Observable store powering the grid. Manages catalog loading, drag-and-drop, folder presentation, and search state.
- `AppSettings.swift`
  - Manages persisted user preferences (grid size, scroll sensitivity, daemon mode) using `UserDefaults` and Combine.

### `Domain/`

- `Models.swift`
  - Defines `AppItem`, `FolderItem`, and `CatalogEntry` value types used across the UI and data layers.

### `Infrastructure/`

- `AppCatalogLoader.swift`
  - Enumerates `.app` bundles, normalises metadata, and groups apps into folders.
- `LayoutPersistence.swift`
  - Persists the user-customised layout to disk and restores it at launch.
- `KeyboardMonitor.swift`
  - Installs global/local keyboard event taps to steer search focus and ESC behaviour.
- `SettingsWindowManager.swift`
  - Manages the detached settings window using `NSHostingView` inside an AppKit window.
- `WindowConfigurator.swift`
  - Provides helpers to configure window styles and stacking levels for the overlay and auxiliary views.

### `Interface/`

- `App/LaunchyApp.swift`
  - SwiftUI entry point and `NSApplication` delegate integration (activation policy, status item, ESC handling).
- `Views/ContentView.swift`
  - Main overlay showing the app grid, search field, paging, and folder overlays.
- `Views/SettingsView.swift`
  - Preferences UI for grid layout, scroll sensitivity, and daemon mode toggle.
- `Views` subcomponents
  - `AppIconView`, `FolderOverlay`, `SearchBar`, etc., each encapsulating a portion of the UI.

## Scripts

- `scripts/deploy`
  - Hardened deployment script that merges `develop` into `main`, runs a release build, and pushes updates. Supports dry-run and configurable branches/remotes.

## Assets

- `assets/icon/launchy.icns`
  - Icon used for the application bundle and status bar item.
- `assets/plist/Info.plist.template`
  - Template used by the Makefile when assembling `.app` bundles.

## Documentation (`docs/`)

- `README.md`
  - Consolidated technical documentation and links to deeper guides.
- `architecture/overview.md`
  - Layered architecture, data flow, lifecycle, and resilience notes.
- Additional Markdown files (such as this one) cover focused topics.

## Makefile Targets

The Makefile encapsulates the most common workflows:

| Target          | Description                                 |
|-----------------|---------------------------------------------|
| `make build`    | Debug build via `swift build`                |
| `make release`  | Release build into `.build/release/Launchy`  |
| `make bundle`   | Assemble `.app` bundle under `.build/dist`   |
| `make run`      | Run the debug executable                     |
| `make test`     | Execute unit tests                           |
| `make format`   | Run `swiftformat` if available               |
| `make lint`     | Run `swiftlint` if available                 |
| `make deploy`   | Merge & release using `scripts/deploy`       |

## Configuration Files

- `.editorconfig` – Editor defaults (indentation, line endings)
- `.vscode/` – VS Code workspace settings
- `.github/` – Issue/PR templates and workflows

## Where to Start

- Read `README.md` for a quick start.
- Browse `docs/README.md` and `docs/architecture/overview.md` for deep dives.
- Explore `src/Interface/Views/ContentView.swift` to understand grid behaviour.
- Review `AppCatalogStore` to see how the store coordinates data and animations.
