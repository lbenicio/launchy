# CONTEXT — Launchy

> This file provides full project context for AI assistants working on this codebase.
> Read this file first before making any changes.

---

## What Is This Project?

**Launchy** is a macOS SwiftUI application that replicates Apple's Launchpad — the fullscreen app launcher that was removed in macOS 26 Tahoe. The goal is to faithfully recreate the real Launchpad's look, feel, and behavior while adding tasteful enhancements (customizable grid, folder colors, iCloud sync, etc.).

The real Launchpad:
- Covers the entire screen with a Gaussian-blurred desktop wallpaper backdrop
- Displays installed apps in a paged grid (7 columns × 5 rows by default)
- Supports drag-and-drop to reorder icons and create folders
- Has a search field at the top center
- Uses small circular page dots at the bottom
- Wiggles icons in edit mode (like iOS home screen)
- Dismisses when you click the desktop, press Escape, launch an app, or pinch out on the trackpad
- Opens with a zoom-in animation and closes with a zoom-out
- Activates via F4 key, four/five-finger pinch-in, or the Dock icon
- Automatically discovers installed apps from `/Applications`, `/System/Applications`, and `~/Applications`

## Tech Stack

| Component | Details |
|-----------|---------|
| Language | Swift 6.2 (strict concurrency) |
| UI Framework | SwiftUI (macOS 14.0+ / Sonoma) |
| Package Manager | Swift Package Manager (no Xcode project file) |
| Build System | SPM + Makefile for bundling/signing/distribution |
| Formatter | swift-format (config in `.swift-format`) |
| Testing | XCTest (67 tests, all passing) |
| CI | GitHub Actions (`.github/workflows/`) |
| License | GPLv3 |

## Project Structure

```
macos-launchpad-tahoe-v1/
├── Package.swift              # SPM manifest, version "0.4.2", macOS 14+
├── Makefile                   # build, bundle, sign, notarize, dmg, pkg targets
├── .swift-format              # 4-space indent, 100-char line length
├── assets/
│   ├── icon/launchy.icns      # App icon
│   └── plists/Info.plist      # Plist template ({{APP_NAME}}, {{VERSION}} placeholders)
├── scripts/
│   ├── configure.sh
│   └── publish-wiki.sh
├── src/                       # Main executable target "Launchy"
│   ├── App/
│   │   ├── LaunchyApp.swift           # @main entry, AppDelegate, Scene, Notification.Name extensions
│   │   └── WindowConfigurator.swift   # NSViewRepresentable that configures the NSWindow (fullscreen/windowed)
│   ├── Models/
│   │   ├── AppIcon.swift              # Identifiable, Codable, Hashable, Sendable struct
│   │   ├── GridSettings.swift         # All grid/folder/background settings + Codable with defaults
│   │   ├── IconColor.swift            # Enum of 10 folder color options
│   │   ├── LaunchyDragIdentifier.swift # Transferable drag payload + UTType extension
│   │   ├── LaunchyFolder.swift        # Folder struct (id, name, color, apps)
│   │   └── LaunchyItem.swift          # Enum: .app(AppIcon) | .folder(LaunchyFolder) with Codable
│   ├── Services/
│   │   ├── ApplicationIconProvider.swift      # NSCache-backed icon loader with background pre-warming
│   │   ├── GlobalHotkeyService.swift          # CGEvent tap for F4 global hotkey
│   │   ├── GridSettingsStore.swift            # ObservableObject wrapping UserDefaults persistence
│   │   ├── ICloudSyncService.swift            # NSUbiquitousKeyValueStore sync for layout
│   │   ├── InstalledApplicationsProvider.swift # Scans /Applications etc. for .app bundles
│   │   ├── LaunchyDataStore.swift             # JSON file persistence + reconciliation with installed apps
│   │   ├── LayoutUndoManager.swift            # Snapshot-based undo/redo stack (max 50)
│   │   ├── MenuBarService.swift               # NSStatusItem with toggle + recently launched list
│   │   ├── NotificationBadgeProvider.swift    # Polls lsappinfo for dock badge counts
│   │   └── TrackpadGestureService.swift       # Pinch-in gesture detection (exists but NOT wired up)
│   ├── ViewModels/
│   │   ├── DragCoordinator.swift      # Drag-and-drop state machine (extract, stack, reorder)
│   │   └── LaunchyViewModel.swift     # Main VM: items, paging, editing, folders, search, launch, undo
│   ├── Views/
│   │   ├── FolderContentView.swift            # Folder overlay with rename, color picker, reorder
│   │   ├── LaunchyGridPageView.swift          # Single page of the icon grid
│   │   ├── LaunchyItemView.swift              # Individual app/folder tile with badges and context menu
│   │   ├── LaunchyPagedGridView.swift         # Horizontally-scrolling paged container
│   │   ├── LaunchyRootView.swift              # Top-level orchestrator (header, grid, overlays, background)
│   │   ├── Components/
│   │   │   ├── AppIconTile.swift              # App icon image + name label + notification badge
│   │   │   ├── DesktopBackdropView.swift      # NSVisualEffectView wrapper for wallpaper blur
│   │   │   ├── DropDelegates.swift            # 6 DropDelegate implementations for all drop zones
│   │   │   ├── FolderIconView.swift           # Folder tile with 3×3 mini preview grid
│   │   │   ├── GridLayoutMetrics.swift        # Adaptive layout calculator (spacing, padding, icon size)
│   │   │   ├── LaunchySearchField.swift       # NSSearchField wrapper
│   │   │   ├── PageNavigationKeyHandler.swift # NSView that intercepts arrow/scroll/escape events
│   │   │   └── WiggleEffect.swift             # ViewModifier for randomized jiggle animation
│   │   └── Settings/
│   │       └── SettingsView.swift             # In-app settings overlay with cards
│   └── Extensions/
│       ├── Array+Chunked.swift        # Array pagination helper
│       ├── Color+Hex.swift            # Hex string ↔ Color conversion
│       └── String+FuzzyMatch.swift    # Two-tier fuzzy search (substring + ordered-character)
└── tests/                     # Test target "LaunchyTests"
    ├── Models/
    │   └── GridSettingsTests.swift
    ├── Services/
    │   └── GridSettingsStoreTests.swift
    └── ViewModels/
        └── LaunchyViewModelTests.swift  # 64 tests covering VM operations, drag, folders, paging, search
```

## Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│                    LaunchyApp (@main)                │
│  ┌──────────────┐  ┌───────────────────────────┐    │
│  │  AppDelegate  │  │  LaunchyRootView          │    │
│  │  (hotkey,     │  │  (search, header, grid,   │    │
│  │   menubar,    │  │   folder overlay,         │    │
│  │   dock icon)  │  │   settings overlay,       │    │
│  └──────┬───────┘  │   background)              │    │
│         │          └──────────┬──────────────────┘    │
│         │                    │                        │
│         ▼                    ▼                        │
│  ┌──────────────────────────────────────────┐        │
│  │         LaunchyViewModel (@MainActor)     │        │
│  │  items, paging, editing, selection,       │        │
│  │  folders, search, launch, undo/redo       │        │
│  │  ┌────────────────────────────────┐       │        │
│  │  │  DragCoordinator               │       │        │
│  │  │  extract, stack, reorder       │       │        │
│  │  └────────────────────────────────┘       │        │
│  └──────────┬───────────────┬────────────────┘        │
│             │               │                         │
│    ┌────────▼──────┐  ┌─────▼───────────┐             │
│    │ LaunchyData   │  │ GridSettings    │             │
│    │ Store (JSON)  │  │ Store (UDefs)   │             │
│    └────────┬──────┘  └─────────────────┘             │
│             │                                         │
│    ┌────────▼──────────────┐                          │
│    │ InstalledApplications │                          │
│    │ Provider (disk scan)  │                          │
│    └───────────────────────┘                          │
└─────────────────────────────────────────────────────┘

Services (singletons):
  GlobalHotkeyService    — CGEvent tap for F4
  TrackpadGestureService — Pinch-in detection (NOT wired up yet)
  MenuBarService         — NSStatusItem
  NotificationBadgeProvider — Polls lsappinfo for badge counts
  ApplicationIconProvider — NSCache-backed icon loading
  ICloudSyncService      — NSUbiquitousKeyValueStore layout sync
  LayoutUndoManager      — Snapshot undo/redo stack
```

## Key Patterns & Conventions

### Data Flow
- `LaunchyViewModel` is the single source of truth for the item list (`[LaunchyItem]`).
- `GridSettingsStore` is an `@EnvironmentObject` injected at the root, also passed to the VM.
- Views observe the VM via `@ObservedObject` and call methods on it for mutations.
- Persistence is JSON-file-based (`~/Library/Application Support/Launchy/launchy-data.json`).
- Settings are stored in `UserDefaults` under key `dev.lbenicio.launchy.grid-settings`.

### Concurrency
- All UI types are `@MainActor`-isolated.
- Models are `Codable`, `Equatable`, and `Sendable`.
- Background work uses `Task.detached` (icon pre-warming, app scanning).
- The codebase mixes `DispatchQueue.main.async` and `Task { @MainActor }` — this is a known inconsistency to clean up.

### Drag & Drop
- Uses the native SwiftUI `onDrag`/`onDrop` system with custom `DropDelegate` implementations.
- Drag payload is `LaunchyDragIdentifier` (Transferable + Codable) with UTType `dev.lbenicio.launchy.item`.
- `DragCoordinator` (owned by the VM) manages all drag state, extraction from folders, and stacking.

### Notifications
- Several in-app events use `NotificationCenter` (`dismissLauncher`, `toggleInAppSettings`, `resetToDefaultLayout`, etc.). Notification names are defined as static extensions on `Notification.Name` in `LaunchyApp.swift`.
- This is a known architectural weakness — some notifications are posted but not subscribed to (e.g., `resetToDefaultLayout` is broken).

### Window Management
- `WindowConfigurator` (NSViewRepresentable) configures the NSWindow:
  - **Fullscreen mode:** borderless, covers entire screen including menubar, level `mainMenu + 3`, auto-hide dock/menubar.
  - **Windowed mode:** resizable, floating level, centered, remembers last size.
- Dismiss works by fading alpha to 0, calling `orderOut`, then `NSApp.hide`.

### Formatting
- swift-format with 4-space indentation, 100-char line length.
- `#if os(macOS)` conditional compilation blocks are indented.
- Run `make fmt` to format, `make lint` to lint.

## Build & Run

```bash
# Build (debug)
swift build

# Run
swift run Launchy

# Build release + assemble .app bundle
make bundle

# Run tests
swift test
# or
make test

# Format code
make fmt

# Lint
make lint
```

The Makefile also supports `sign`, `notarize`, `staple`, `release`, `dmg`, `pkg`, and their signed variants. These require Developer ID certificates configured via environment variables.

## Current Version

**0.4.2** (defined in `Package.swift` as `let packageVersion = "0.4.2"`).

## Known Issues (see TODO.md for full list)

**Critical bugs:**
- `resetToDefaultLayout` notification is posted from Settings but never subscribed to — the Reset button is broken.
- `TrackpadGestureService` exists but is never started — pinch gestures don't work.

**Key missing features vs. real Launchpad:**
- No zoom-in/zoom-out appearance animation.
- No Enter-to-launch top search result.
- No automatic page creation when dragging past the last page.
- No folder paging (large folders don't paginate internally).
- No filesystem watcher for newly installed apps.
- No VoiceOver/accessibility support.
- No configurable hotkey (hardcoded to F4).

## Testing

67 tests in `tests/`, all passing. Coverage is focused on `LaunchyViewModel` (64 tests) and `GridSettings`/`GridSettingsStore` (3 tests). Major gaps exist for `DragCoordinator`, `String.fuzzyMatch`, `LayoutUndoManager`, and `InstalledApplicationsProvider`.

Tests use a `StubFileManager` that blocks real `/Applications` access, and isolated `UserDefaults` suites for settings.

## What Real Launchpad Looks & Feels Like

For reference when implementing visual features:

1. **Background:** The actual desktop wallpaper is visible but heavily blurred (Gaussian, ~30px radius) with a subtle dark overlay (~15% black).
2. **Grid:** Icons are evenly distributed across the full screen. Default 7×5 grid. Icons are ~90px with ~14px labels below.
3. **Page dots:** Small uniform circles at the bottom center. Active = white, inactive = 40% white. No size change.
4. **Folders:** Open as a full-width translucent band across the screen at the row where the folder lives, with a small triangle pointer below.
5. **Search:** Centered at the top of the screen, rounded pill shape, placeholder "Search".
6. **Animations:** Spring-based. Icons shift smoothly during drag. Launch = icon zooms toward camera. Show/hide = scale 0.8↔1.0 + fade.
7. **Wiggle:** Subtle ~2° rotation oscillation with random phase per icon. Small × badge in top-left corner.
8. **Gestures:** Pinch-in to open, pinch-out to close, swipe horizontally to page.