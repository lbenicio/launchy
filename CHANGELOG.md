# Changelog

All notable changes to this repository will be documented in this file.

The format is based on "Keep a Changelog" and this project adheres to [Semantic Versioning](https://semver.org/).

## [0.5.0] - 2026-03-19

### Fixed

- **Folder creation crash:** Fixed array index out-of-bounds error in `createFolder` method by collecting indices to remove first, then removing them in reverse order to prevent index shifting issues during folder creation from selected apps.

- **`resetToDefaultLayout` notification not subscribed to:** Added `.onReceive` handler in `LaunchyRootView` for `Notification.Name.resetToDefaultLayout`, so the Settings → Reset Layout button now correctly calls `viewModel.resetToDefaultLayout()`.
- **`TrackpadGestureService` not wired up:** Started `TrackpadGestureService.shared` in `AppDelegate.applicationDidFinishLaunching` with `onPinchIn` calling `toggleLauncher()`, and added `.stop()` in `applicationWillTerminate`. Four-finger pinch-in gestures now toggle the launcher as expected.
- **`NSApp.activate(ignoringOtherApps:)` deprecated:** Replaced all four call sites (`LaunchyApp.init`, `AppDelegate.showLauncherWindow`, `WindowConfigurator.configureWindow`, `LaunchyRootView.activateWindowIfNeeded`) with the parameterless `NSApp.activate()` available on macOS 14+.
- **Excessive undo snapshots from drag operations:** Moved `recordForUndo()` from `moveItem(_:before:)` (called on every drag pixel) to `beginDrag(for:sourceFolder:)` (called once per drag session), so a single Cmd+Z undoes the entire reorder operation.
- **Undo/save timing inconsistency:** By recording the undo snapshot at drag start instead of on every `moveItem` call, the snapshot now always captures the pre-drag state before any debounced saves occur.
- **`dismissAfterLaunch()` could match the Settings window:** Added `$0.identifier?.rawValue != "com_apple_SwiftUI_Settings_window"` filter to the window lookup in `dismissAfterLaunch()`.
- **`dismissLauncher()` could match the Settings window:** Added the same Settings window filter and converted `DispatchQueue.main.async` to `Task { @MainActor in }`.
- **`activateWindowIfNeeded()` could match the Settings window:** Added the Settings window filter and converted `DispatchQueue.main.async` to `Task { @MainActor in }`.
- **`NotificationBadgeProvider` spawned one `Process` per running app:** Replaced per-app `lsappinfo info` calls with a single `lsappinfo list -only StatusLabel` invocation, reducing subprocess spawns from 20+ to 1 per poll cycle.
- **`Color+Hex` only handled 6-character hex:** Added support for `#RGB` (3-char), `#RGBA` (4-char), `#RRGGBB` (6-char), and `#RRGGBBAA` (8-char) formats. The `default` case now logs a warning via `os_log` instead of silently returning black.
- **`chunked(into: 0)` returned `[self]` instead of empty array:** Changed the guard to return `[]` for invalid chunk sizes.
- **Info.plist `CFBundleIconFiles` is iOS-only:** Removed the `CFBundleIconFiles` array entry from the plist template; macOS uses `CFBundleIconFile` (singular) which was already present.

### Added

- **`LaunchyFolder` conforms to `Hashable`:** Added `Hashable` conformance for consistency with `AppIcon` and to enable `Set`/`Dictionary` usage.
- **`LaunchyItem` conforms to `Hashable`:** Added `Hashable` conformance to the enum now that both associated types (`AppIcon`, `LaunchyFolder`) are `Hashable`.
- **Search field auto-focus on appear:** `LaunchySearchField` now calls `makeFirstResponder` on the `NSSearchField` when it appears, matching real Launchpad's immediate-typing behavior.
- **Enter-to-launch top search result:** Added Return/Enter key handling in `PageNavigationKeyHandler` that launches the top fuzzy-match result while searching, matching real Launchpad's instant-launch behavior. Works even when the search field has focus.
- **Opening/closing zoom animation:** Added a scale (0.8→1.0) + opacity spring transition when the launcher appears and a reverse zoom-out when dismissing, matching real Launchpad's signature animation.
- **Folder overlay Escape key:** Added `.onExitCommand` on `FolderContentView` so pressing Escape closes the folder overlay directly, even when a text field inside has focus.

### Changed

- Converted remaining `DispatchQueue.main.async` calls to `Task { @MainActor in }` across `LaunchyRootView`, `LaunchyViewModel`, `LaunchyApp`, and `DropDelegates` for consistent structured concurrency.
- **Page dots match real Launchpad:** Changed from variable-width capsules to uniform 8×8 circles with opacity-only differentiation (active = 0.85, inactive = 0.4).
- **Icon shadow reduced:** Changed from `shadow(opacity: 0.28, radius: 12, y: 8)` to `shadow(opacity: 0.15, radius: 6, y: 3)` to match real Launchpad's subtle shadow.
- **Delete badge (× button) resized:** Reduced from `dimension * 0.28` to `dimension * 0.18`, changed background from bright red to dark translucent, and tightened offset to icon corner.
- **Folder context menu deduplicated:** Removed the duplicate "Remove Folder" entry (which did the same thing as "Split Folder"). Renamed "Split Folder" to "Ungroup N Apps" for clarity.
- **`@unchecked Sendable` removed from `AppDelegate`:** Replaced with explicit `@MainActor` annotation, which is correct since all methods are main-actor-isolated via `NSApplicationDelegate`.
- **Stable window identifier:** Set a custom `NSUserInterfaceItemIdentifier("dev.lbenicio.launchy.main")` on the launcher window in `WindowConfigurator`. All window lookups now match by this known identifier instead of excluding SwiftUI's internal `com_apple_SwiftUI_Settings_window` string.
- **Extracted `IconColorPicker` component:** Deduplicated the folder color picker UI from `FolderContentView` and `LaunchyRootView.newFolderSheet` into a reusable `IconColorPicker` view.
- **Info.plist accessibility declaration:** Added `NSAccessibilityUsageDescription` explaining that Launchy needs Accessibility access for the global F4 hotkey and trackpad pinch gestures.

### Tests

- Updated `testChunkedWithSizeZeroReturnsSelf` → `testChunkedWithSizeZeroReturnsEmpty` to match the corrected `chunked(into: 0)` behavior (returns `[]`).
- Added `FuzzyMatchTests` (13 tests) covering no-match, exact/substring/prefix matches (Tier 1), fuzzy ordered-character matches (Tier 2), cluster tightness scoring, prefix bonus, and edge cases for `String.fuzzyMatch`.
- Added `LayoutUndoManagerTests` (11 tests) covering initial state, snapshot recording, undo/redo, multiple undo/redo cycles, the 50-item stack size limit, and `clearAll()`.
- Total test count increased from 67 to 91.

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
