# Launchy

Launchy is a macOS SwiftUI application that recreates the familiar Launchpad experience with enhanced customization. It lets you browse, search, and organize installed apps into pages and folders with smooth paging, wiggle mode editing, and persistent layout storage.

## Features

- **App Browsing** – grid of installed apps with search, paging, and keyboard navigation.
- **Wiggle Mode** – reorder apps, create folders, and batch-move selections with multi-select tools.
- **Folders** – drag-and-drop or tap to organize multiple apps into named collections.
- **App Launching** – click any app tile to open it immediately and close the launcher.
- **Settings** – tweak grid dimensions, icon scaling, and other layout preferences.
- **Persistence** – local storage keeps your custom layout intact between sessions.

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘E` | Toggle wiggle (edit) mode |
| `⌘,` | Open settings |
| `←` / `→` | Navigate between pages |
| `Home` / `End` | Jump to first / last page |
| `Page Up` / `Page Down` | Navigate between pages |
| `Escape` | Layered dismiss: close folder → close settings → clear search → exit edit mode → hide launcher |
| Trackpad swipe / scroll | Navigate between pages (sensitivity configurable in settings) |
| `F4` | Global hotkey to toggle launcher visibility |

## Architecture

```mermaid
graph LR
    A[InstalledApplicationsProvider] --> B[LaunchyDataStore]
    B --> C[LaunchyViewModel]
    C --> D[DragCoordinator]
    C --> E[LaunchyRootView]
    E --> F[LaunchyPagedGridView]
    E --> G[FolderContentView]
    F --> H[LaunchyGridPageView]
    H --> I[LaunchyItemView]
    J[GridSettingsStore] --> C
    J --> E
```

| Layer | Responsibility |
|-------|---------------|
| **Models** | `AppIcon`, `LaunchyItem`, `LaunchyFolder`, `GridSettings` — pure value types (`Codable`, `Sendable`) |
| **Services** | `InstalledApplicationsProvider` discovers apps on disk; `LaunchyDataStore` persists layout as JSON; `GridSettingsStore` persists user preferences; `GlobalHotkeyService` listens for F4 |
| **ViewModels** | `LaunchyViewModel` owns the item list, paging, editing, and folder logic; `DragCoordinator` encapsulates drag-and-drop state and stacking |
| **Views** | SwiftUI views for the grid, folder overlay, settings panel, and search field |

## Requirements

- macOS 14.0 or newer
- Xcode 16 / Swift 6 toolchain (Swift 6.2 package manifest)

## Getting Started

Clone the repository and build with Swift Package Manager:

```bash
git clone https://github.com/lbenicio/macos-launchpad-tahoe-v1.git
cd macos-launchpad-tahoe-v1
swift build
```

Run the app from Xcode or the command line:

```bash
swift run Launchy
```

## Development Tips

- Use `swift build` before submitting changes to ensure everything still compiles.
- Launch the app and press the edit button (wiggle mode) to manage icons and folders.
- Dependabot is configured for Swift and GitHub Actions updates; expect PRs prefixed with `chore(deps)`.

## Contributing

1. Fork the repo and create a feature branch.
2. Follow the pull request template (`.github/pull_request_template.md`).
3. Include relevant issue links and screenshots for UI changes.
4. Ensure new functionality has appropriate tests or manual verification steps.

## License

This project is licensed under the GPLv3 License. See `LICENSE.txt` for details.
