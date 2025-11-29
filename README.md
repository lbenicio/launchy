# Launchy

Launchy is a macOS SwiftUI application that recreates the familiar Launchpad experience with enhanced customization. It lets you browse, search, and organize installed apps into pages and folders with smooth paging, wiggle mode editing, and persistent layout storage.

## Features

- **App Browsing** – grid of installed apps with search, paging, and keyboard navigation.
- **Wiggle Mode** – reorder apps, create folders, and batch-move selections with multi-select tools.
- **Folders** – drag-and-drop or tap to organize multiple apps into named collections.
- **App Launching** – click any app tile to open it immediately and close the launcher.
- **Settings** – tweak grid dimensions, icon scaling, and other layout preferences.
- **Persistence** – local storage keeps your custom layout intact between sessions.

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

This project is licensed under the MIT License. See `LICENSE` for details.
