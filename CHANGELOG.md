# Changelog

All notable changes to this repository will be documented in this file.

The format is based on "Keep a Changelog" and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Fixed

- **`resetToDefaultLayout` notification not subscribed to:** Added `.onReceive` handler in `LaunchyRootView` for `Notification.Name.resetToDefaultLayout`, so the Settings → Reset Layout button now correctly calls `viewModel.resetToDefaultLayout()`.
- **`TrackpadGestureService` not wired up:** Started `TrackpadGestureService.shared` in `AppDelegate.applicationDidFinishLaunching` with `onPinchIn` calling `toggleLauncher()`, and added `.stop()` in `applicationWillTerminate`. Four-finger pinch-in gestures now toggle the launcher as expected.

## [0.4.2] - 2026-03-12

### Added

- Drag-and-drop folder creation: dragging one app icon onto another now creates a new folder containing both apps, matching real Launchpad behavior.
- `extractDraggedItemIfNeeded()` implementation: apps dragged out of a folder onto the main grid are now properly extracted from the source folder and inserted as top-level items. Folders with only one remaining app are automatically disbanded.
- Debounced persistence for drag operations: `moveItem` and drag movements use a 0.5 s debounced save instead of writing JSON to disk on every pixel of movement. Explicit user actions (create, delete, disband) still save immediately.
- Randomized wiggle phase per icon: each icon now wiggles with a unique duration (0.12–0.20 s), intensity (±15 % variation), and slight vertical wobble for a natural, organic feel matching real Launchpad.
- `isEnabled` flag on `PageNavigationKeyHandler` to suppress scroll/key interception when overlays are presented.
- `isOverlayPresented` parameter on `LaunchyPagedGridView` so the root view can disable page-navigation event handling when the settings panel or a folder overlay is open.
- `NSApp.presentationOptions` management: fullscreen mode now sets `.autoHideDock` and `.autoHideMenuBar` (restored to defaults in windowed mode) for authentic Launchpad immersion.
- Distributed grid spacing: `GridLayoutMetrics` now divides remaining screen space evenly between columns and rows so icons spread across the full display, matching real Launchpad layout.

### Changed

- `WindowConfigurator` rewritten around a `ConfiguratorView` subclass that overrides `viewDidMoveToWindow()` for synchronous window configuration, eliminating the previous `DispatchQueue.main.async` delay that caused a visible expansion lag on launch.
- Window level raised from `.mainMenu` to `mainMenu + 3` to fully cover the macOS menubar in fullscreen mode.
- `setFrame` in fullscreen mode now passes `animate: false` for instant display coverage.
- Stacking activation radius reduced from 0.45 to 0.35 of the tile size, and stacking delay increased from 0.18 s to 0.35 s, reducing accidental folder creation during drag.
- Default wiggle intensity lowered from 2.6° to 2.4° for a subtler effect; deactivation now uses `.easeOut(duration: 0.2)` instead of `.default` to prevent stuck animation states.
- `LaunchyGridPageView` refactored: removed `AnyView` type erasure and the per-tile `GeometryReader`, preserving SwiftUI structural identity and improving rendering performance.
- Removed the redundant double `.onDrop` on folder tiles (previously `LaunchyItemDropDelegate` + `FolderDropDelegate` stacked); the unified `LaunchyItemDropDelegate` now handles both reordering and folder-specific drops.
- `launch()` now actually opens the target application via `NSWorkspace.shared.openApplication(at:configuration:)` instead of being a no-op placeholder.
- Settings `ScrollView` now shows scroll indicators (`.scrollIndicators(.visible)`).

### Fixed

- **Empty `extractDraggedItemIfNeeded()`**: the method was a no-op, causing ghost items and broken drag-from-folder behavior.
- **Index corruption in `stackDraggedItem(onto:)`**: after removing the dragged item, `targetIndex` was not adjusted for the index shift, leading to silent data corruption or crashes.
- **Index corruption in `addApps(_:toFolder:)`**: `folderIndex` was captured before items were filtered, causing the folder to be re-inserted at the wrong position.
- **`createFolder` always appended to the end**: used `max(0, remaining.count)` instead of tracking the first selected index; folders now appear where the selected apps were.
- **Double `.onDrop` prevented folder reordering**: the outer `FolderDropDelegate` always captured events on folder tiles, so the inner `LaunchyItemDropDelegate` never fired, making it impossible to reorder folders in the grid.
- **Settings scroll leaked to grid pager**: scroll events inside the settings overlay were intercepted by `PageNavigationKeyHandler` (same-window global monitor), triggering unintended page changes.
- **Stepper values invisible in Settings**: `valueBadge` was passed as the Stepper's label and then hidden by `.labelsHidden()`; the badge is now a visible sibling in an `HStack`.
- **Slow fullscreen expansion on launch**: the window started at a default SwiftUI size and grew asynchronously; now configured synchronously via `viewDidMoveToWindow()`.
- **Window did not cover the menubar**: level was too low and presentation options were not set.
- **Grid icons clustered in center on large displays**: fixed-spacing `GridItem`s left large empty margins; spacing is now distributed to fill the available area.
- `deleteItem` now automatically removes empty folders after the last app is deleted from them.
- `dropExited` added to all drop delegates to properly cancel pending stacking state.

### Tests

- All existing unit tests pass with no modifications required.

## [0.4.1] - 2025-11-29

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
