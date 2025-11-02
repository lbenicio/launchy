# Launchy

Launchy is a Swift macOS application that recreates the classic full-screen Launchpad experience. It scans your installed applications, organises them into a grid, supports folder browsing, and offers instant search.

## Requirements

- macOS 13 Ventura or newer
- Xcode 15 or Swift 5.9 toolchain

## Getting Started

1. Ensure command-line tools are set to the latest Xcode (`xcode-select --switch /Applications/Xcode.app`).
2. Build and run the overlay:

   ```sh
   swift run LaunchpadClone
   ```

  The overlay launches immediately, hides the dock and menu bar, and dims the current desktop with a translucent blur.

## Features

- Edge-to-edge SwiftUI interface with translucent mask and blurred desktop backdrop
- Automatic discovery of applications in `/Applications`, `/System/Applications`, and `~/Applications`
- Folder browsing for subdirectories containing apps (e.g. Utilities)
- Long-press to enter edit mode with classic wiggle animation
- Drag icons to rearrange the grid or drop them onto another icon to build folders
- Context menu to reveal any application in Finder
- Command+R or the refresh button to rescan the catalog
- Quick search with incremental filtering across app names and bundle identifiers

## Project Structure

- `Package.swift` – Swift Package manifest declaring the macOS executable target
- `Sources/LaunchpadCloneApp` – SwiftUI app sources
  - `LaunchpadCloneApp.swift` – Entry point and window configuration
  - `ContentView.swift` – Main UI layout and interactions
  - `AppCatalogStore.swift` – Observable store managing app data and UI state
  - `AppCatalogLoader.swift` – Filesystem scanner for installed applications
  - `AppIconView.swift`, `FolderOverlay.swift`, `VisualEffectView.swift` – UI components
  - `Models.swift` – Lightweight model definitions
  - `IconStore.swift` – Icon caching utility

## Next Steps

- Persist custom folder arrangements and ordering
- Add pagination handling when the grid exceeds the current page height
- Persist custom ordering and folder membership between launches
