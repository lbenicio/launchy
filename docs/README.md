# Launchy Documentation

This guide consolidates the technical, architectural, and operational knowledge required to build, extend, and operate Launchy.

## Table of Contents

1. [Project Overview](#project-overview)
2. [Architecture](#architecture)
   1. [Module Layout](#module-layout)
   2. [Core Types](#core-types)
   3. [Window Management](#window-management)
3. [User Experience](#user-experience)
   1. [Grid Interaction](#grid-interaction)
   2. [Search & Keyboard Handling](#search--keyboard-handling)
   3. [Daemon Mode](#daemon-mode)
4. [Persistent Settings](#persistent-settings)
5. [Build & Tooling](#build--tooling)
6. [Development Workflow](#development-workflow)
   1. [Coding Standards](#coding-standards)
   2. [Testing Strategy](#testing-strategy)
   3. [Accessibility Considerations](#accessibility-considerations)
7. [Deployment Process](#deployment-process)
8. [Directory Reference](#directory-reference)
9. [Companion Guides](#companion-guides)
10. [Troubleshooting](#troubleshooting)
11. [FAQ](#faq)

---

## Project Overview

Launchy is a macOS application written in Swift and SwiftUI. It recreates the full-screen Launchpad experience with support for pagination, folders, and incremental search. The app can operate as a standard foreground application or as a background daemon accessible from the menu bar.

Key technologies:

- Swift 5.9 / SwiftUI for the UI layer
- AppKit interop for window and keyboard control
- Combine for state observation and preference synchronization
- Swift Package Manager for build tooling

## Architecture

### Module Layout

The sources are organized under `src/` to maintain a clear separation of responsibilities:

- `Application/` – observable stores, app-wide state, and orchestration logic
- `Domain/` – lightweight models (`AppItem`, `FolderItem`, `CatalogEntry`, etc.)
- `Infrastructure/` – system integrations (filesystem scanning, keyboard monitoring, window configuration, persistence helpers)
- `Interface/` – SwiftUI scenes, views, and the application entry point

Supporting assets such as icons, Info.plist templates, and export settings live in the `assets/` directory.

### Core Types

- `AppCatalogStore` (`src/Application/AppCatalogStore.swift`)
  - Central observable store that loads the app catalog, tracks edit mode, manages drag-and-drop, and handles folder presentation.
- `AppSettings` (`src/Application/AppSettings.swift`)
  - Wraps `UserDefaults`-backed preferences (grid dimensions, scroll sensitivity, daemon mode) with published properties.
- `AppLifecycleDelegate` (`src/Interface/App/LaunchyApp.swift`)
  - NSApplication delegate that enforces activation policy, manages status item integration, and honors daemon mode preferences.
- `ContentView` (`src/Interface/Views/ContentView.swift`)
  - Full-screen grid layout with paging, overlays, search, and key handling.
- `KeyboardMonitor` (`src/Infrastructure/KeyboardMonitor.swift`)
  - Manages global keyboard event taps when the user grants accessibility permissions.
- `SettingsWindowManager` (`src/Infrastructure/SettingsWindowManager.swift`)
  - Owns the detached settings window presented on auxiliary window level.

### Window Management

Two helper structs ensure predictable window behavior:

- `TransparentWindowConfigurator` sets the primary window to borderless, full-screen, and stationary with the custom `launchyPrimary` window level.
- `AuxiliaryWindowConfigurator` raises secondary windows (folders, settings) above the primary overlay using the `launchyAuxiliary` level.

The primary window mirrors the active screen bounds and hides the Dock and menu bar while active. The settings window always floats above the overlay for easy access.

## User Experience

### Grid Interaction

- Pagination is handled via a custom `LazyVGrid` inside a horizontally paging `HStack`.
- Users can drag-and-drop apps to reorder or create folders; folder overlays animate with spring-based transitions.
- Scroll wheel events are accumulated and compared to `AppSettings.scrollThreshold` to flip pages.
- Edge auto-advance moves between pages when dragging near the screen borders.

### Search & Keyboard Handling

- `SearchBar` is auto-focused on launch and when the user stops editing folders.
- Typing while the grid is focused routes characters into the search field using a transparent key capture overlay.
- Escape key behavior (via `onExitCommand` and `KeyboardMonitor`) clears search text, exits edit mode, closes folders, or hides the app depending on context.

### Daemon Mode

When `AppSettings.daemonModeEnabled` is true:

- The app sets its activation policy to `.accessory`, suppressing the Dock icon.
- A status bar item provides quick actions: open Launchy, open settings, or quit.
- Pressing ESC while the grid is idle hides the overlay instead of quitting.
- Launchy can be toggled quickly without disrupting the user's workflow.

## Persistent Settings

User preferences are persisted through `UserDefaults` keys prefixed with `settings.`. The settings window exposes controls for:

- Grid dimensions (columns and rows)
- Scroll sensitivity (1...120 points of scroll delta)
- Background daemon mode toggle

Changes propagate instantly thanks to Combine publishers, ensuring the UI responds without requiring manual refreshes.

## Build & Tooling

- `swift build` / `swift run Launchy` – core build commands
- `make build` / `make release` – simplified Makefile aliases for debug and release builds
- `make bundle` – assembles a distributable `.app` bundle in `.build/dist`
- `make pkg` / `make dmg` – produce installer artifacts (requires Xcode project setup)
- `make format` – run `swiftformat` if installed via Homebrew
- `make lint` – run `swiftlint` when available

Dependency management is handled entirely by Swift Package Manager (`Package.swift`). No external Swift dependencies are required beyond the Apple frameworks bundled with macOS.

## Development Workflow

### Coding Standards

- Follow Swift API Design Guidelines and Apple Human Interface Guidelines
- Keep platform-specific logic isolated in infrastructure helpers
- Use descriptive naming and avoid abbreviations except for common Apple frameworks
- Prefer dependency injection over shared singletons unless the API requires global access (e.g., `KeyboardMonitor.shared`)

### Testing Strategy

Automated tests live under the `Tests/` directory (to be expanded). Developers should:

- Run `make test` before submitting a pull request
- Add unit tests for new features or bug fixes
- Document manual QA steps for UI-heavy changes in the pull request template

### Accessibility Considerations

- Ensure accessibility permissions are requested when global keyboard monitoring is activated
- Maintain VoiceOver labels and focus order when modifying views
- Preserve keyboard shortcuts (e.g., `Command + R`, `Command + ,`, ESC) when refactoring

## Deployment Process

Maintainers use the hardened `scripts/deploy` workflow surfaced through the Makefile:

```sh
make deploy
make deploy DEPLOY_ARGS="--dry-run"
```

The script performs the following steps:

1. Validates the working tree is clean (or allows dirty state in dry-run mode)
2. Fetches from the configured remote (default `origin`)
3. Fast-forwards both source (`develop`) and target (`main`) branches
4. Merges the source branch into the target with a non-fast-forward merge commit
5. Executes `swift build -c release`
6. Pushes the updated target branch back to the remote

## Directory Reference

```text
.
|-- src/
|   |-- Application/
|   |-- Domain/
|   |-- Infrastructure/
|   `-- Interface/
|-- assets/
|   |-- icon/
|   `-- plist/
|-- scripts/
|   `-- deploy
|-- docs/
|   `-- README.md (this document)
|-- Makefile
|-- Package.swift
|-- README.md
|-- CONTRIBUTING.md
`-- SECURITY.md
```

## Companion Guides

- [Architecture Overview](architecture.md)
- [Project Structure Reference](structure.md)

## Troubleshooting

| Symptom | Resolution |
| ------- | ---------- |
| Launchy does not display on launch | Ensure accessibility permissions are granted, and verify the app window is not hidden (status item > Open Launchy). |
| ESC does not hide the app in daemon mode | Confirm `Run in background` is enabled in settings; check that `AppLifecycleDelegate` is active (restart the app if necessary). |
| Scroll gestures feel too sensitive | Open settings and increase the scroll sensitivity slider to require more delta before paging. |
| Build fails due to missing `swiftformat` or `swiftlint` | Install via Homebrew (`brew install swiftformat swiftlint`) or skip the optional Makefile targets. |
| `scripts/deploy` aborts with dirty tree warning | Commit or stash changes, or run with `--dry-run` when rehearsing the deployment. |

## FAQ

**Why does Launchy need accessibility permissions?**
Global keyboard monitoring (for instant search focus and ESC handling) relies on the macOS accessibility APIs. The app gracefully degrades when permission is denied but certain shortcuts require the access.

**Can I run Launchy at login?**
Use macOS System Settings > Users & Groups > Login Items and add the built `.app` bundle produced by `make bundle`.

**How do I reset preferences?**
Delete the `UserDefaults` domain: `defaults delete dev.lbenicio.launchy` and relaunch. Layout files are stored under `~/Library/Application Support/Launchy/layout.json`.

**Where are icons generated from?**
App icons are read from each discovered bundle (`.app` directories). Launchy ships with an `.icns` bundle icon at `assets/icon/launchy.icns` so the app itself has a proper icon.

---

For additional guidance, refer to the top-level [`README.md`](../README.md), [`CONTRIBUTING.md`](../CONTRIBUTING.md), and [`SECURITY.md`](../SECURITY.md).
