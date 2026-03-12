# TODO — Launchy (macOS Launchpad Clone)

> Systematic code review and improvement roadmap.
> Items are organized by category and roughly prioritized within each section.
> Priority: 🔴 Critical · 🟠 High · 🟡 Medium · 🟢 Low · 💡 Idea

---

## 🐛 Bugs

### ~~🔴 `resetToDefaultLayout` notification is posted but never subscribed to~~
~~The **Settings → Reset Layout** button posts `Notification.Name.resetToDefaultLayout`, but there is no `.onReceive` or `addObserver` listening for it anywhere. Clicking "Reset" does nothing.~~

~~**File:** `src/Views/Settings/SettingsView.swift` (line ~292), `src/Views/LaunchyRootView.swift`~~
~~**Fix:** Add `.onReceive(NotificationCenter.default.publisher(for: .resetToDefaultLayout))` in `LaunchyRootView` that calls `viewModel.resetToDefaultLayout()`.~~

✅ **Done** — Added `.onReceive(NotificationCenter.default.publisher(for: .resetToDefaultLayout))` in `LaunchyRootView.body` that calls `viewModel.resetToDefaultLayout()`.

---

### ~~🔴 `TrackpadGestureService` is defined but never instantiated or started~~
~~The service exists in `src/Services/TrackpadGestureService.swift` but is never called from `AppDelegate`, `LaunchyApp`, or anywhere else. The four-finger pinch-in gesture (a key Launchpad activation method) doesn't work.~~

~~**Fix:** Wire up `TrackpadGestureService.shared.start()` in `AppDelegate.applicationDidFinishLaunching` with `onPinchIn` calling `toggleLauncher()`. Also call `.stop()` in `applicationWillTerminate`.~~

✅ **Done** — Wired up `TrackpadGestureService.shared.start()` in `AppDelegate.applicationDidFinishLaunching` with `onPinchIn` calling `toggleLauncher()`, and `.stop()` in `applicationWillTerminate`.

---

### 🟠 `NSApp.activate(ignoringOtherApps:)` is deprecated in macOS 14+
Called in four places (`LaunchyApp.init`, `AppDelegate.showLauncherWindow`, `WindowConfigurator.configureWindow`, `LaunchyRootView.activateWindowIfNeeded`). Since the minimum deployment target is macOS 14, this should use the modern replacement `NSApp.activate()` (no parameter).

**Fix:** Replace all four call sites with `NSApp.activate()`.

---

### 🟠 Excessive undo snapshots from drag operations
`moveItem(_:before:)` calls `recordForUndo()` on **every** drag-movement event (every pixel), flooding the undo stack with dozens of near-identical snapshots for a single reorder. This makes Cmd+Z useless for meaningful undo.

**Fix:** Only call `recordForUndo()` once at the start of a drag session (in `beginDrag`) rather than on every positional update. Alternatively, coalesce snapshots by only recording if the last snapshot is older than ~0.5 s.

---

### 🟠 `recordForUndo()` called inside `moveItem` but save is debounced
When `moveItem` records an undo snapshot and then debounces the save, if the user immediately undoes, the undo restores stale state that was never persisted. The undo/save timing is inconsistent.

**Fix:** Either debounce undo recording to match the save debounce, or only record undo snapshots for explicit user actions (create, delete, disband, folder drop), not for continuous drag movements.

---

### 🟡 Folder overlay doesn't respond to Escape key directly
The `FolderContentView` has no key handler. Escape is handled in `LaunchyRootView.handleEscape()` via `PageNavigationKeyHandler`, but since the folder overlay is `.zIndex(3)`, key events may not route through when a search field is focused.

**Fix:** Verify Escape handling with the folder overlay open and a search field focused. Consider adding `.onExitCommand` or `.onKeyPress(.escape)` directly on the folder overlay.

---

### 🟡 `LaunchyFolder` does not conform to `Hashable`
`AppIcon` conforms to `Hashable`, and `LaunchyItem` uses both in an enum, but `LaunchyFolder` only conforms to `Equatable`. This prevents using folders in `Set` or as `Dictionary` keys if needed in the future, and is an inconsistency.

**Fix:** Add `Hashable` conformance to `LaunchyFolder`.

---

### 🟡 `dismissAfterLaunch()` finds the window with `NSApp.windows.first(where: { $0.isVisible })` which could match the Settings window
If a standalone SwiftUI Settings window were ever visible, the dismiss logic might target the wrong window.

**Fix:** Use the same window filter used elsewhere: `$0.identifier?.rawValue != "com_apple_SwiftUI_Settings_window"`.

---

### 🟡 `NotificationBadgeProvider` spawns a `Process` per running app every 8 seconds
This polls by running `/usr/bin/lsappinfo` once per running `.regular` app, which can be 20+ subprocesses every 8 seconds. This is CPU- and resource-wasteful.

**Fix:** Use a single invocation of `lsappinfo list -only StatusLabel` to query all apps at once, or parse dock badge info from the distributed notification center. Alternatively, increase the poll interval to 30+ seconds.

---

### 🟢 `Color+Hex` doesn't handle 8-character hex (with alpha) or 3-character shorthand
Only 6-character hex strings are parsed; anything else silently returns black.

**Fix:** Add support for `#RGB`, `#RGBA`, `#RRGGBB`, `#RRGGBBAA` formats with a `default` case that logs a warning instead of silently returning black.

---

### 🟢 Info.plist `CFBundleIconFiles` is an iOS-only key
The `assets/plists/Info.plist` template includes `CFBundleIconFiles` (an array), which is only used on iOS. macOS uses `CFBundleIconFile` (a string), which is already present.

**Fix:** Remove the `CFBundleIconFiles` array entry from the plist template.

---

### 🟢 Info.plist is missing `LSUIElement` key
Without `LSUIElement` set, the app always shows in the Dock. For a Launchpad replacement, it might be desirable to hide the Dock icon and rely on the menu bar extra + hotkey instead (matching real Launchpad's invisible-in-dock behavior).

**Fix:** Consider adding `<key>LSUIElement</key><true/>` to the Info.plist template, or make it configurable. (Note: this changes UX significantly — the dock icon is currently the fallback activation method.)

---

## 🔧 Improvements

### 🟠 App appearance in dark mode only — no light mode awareness
Real Launchpad adapts to the system appearance. The current hardcoded dark color scheme (`Color.white.opacity(...)`, `Color.black.opacity(...)`) looks wrong in light mode.

**Fix:** Use semantic colors (`.primary`, `.secondary`) consistently, or detect `@Environment(\.colorScheme)` and adapt backgrounds/text accordingly.

---

### 🟠 Search field does not auto-focus on launch or re-appear
Real Launchpad immediately focuses the search field when it appears, so the user can start typing without clicking. Currently, the `LaunchySearchField` is created but not auto-focused.

**Fix:** Add `NSSearchField.becomeFirstResponder()` logic in the `makeNSView` or on a `.onAppear` trigger in `LaunchyRootView.reappearLauncher()`.

---

### 🟠 No animation when transitioning between fullscreen and windowed mode
Toggling "Fill Entire Screen" in settings causes an abrupt jump. Real macOS windows animate between sizes.

**Fix:** Wrap the `WindowConfigurator` frame changes in `NSAnimationContext.runAnimationGroup` for smooth transitions.

---

### 🟡 The settings overlay is a fixed 680×540 view, not responsive
On smaller screens or in windowed mode, the settings panel might be too large and get clipped.

**Fix:** Use `min(680, proxy.size.width - 120)` for width and make the height flexible with a `ScrollView` that fills available space. The `ScrollView` already exists inside, so just make the outer frame adaptive.

---

### 🟡 `GridLayoutMetrics` is recalculated on every view update
The metrics struct is computed inline inside `GeometryReader` closures. While it's a value type, the calculations (32-iteration tighten loop) run on every frame during animations.

**Fix:** Cache the metrics in the view model or use `@State` with explicit invalidation when `settings` or `proxy.size` change. Could also use `.equatable()` modifier to avoid unnecessary recomputation.

---

### 🟡 Page navigation scroll sensitivity is confusing (higher = harder to scroll)
The `scrollSensitivity` multiplier increases the threshold, making it *harder* to change pages — the opposite of what "sensitivity" implies to most users.

**Fix:** Invert the relationship (divide by multiplier instead of multiplying), or relabel the setting to "Scroll Resistance" / "Scroll Threshold" to match its actual behavior.

---

### 🟡 No smooth spring animation when icons rearrange during drag
Real Launchpad smoothly animates icons shifting out of the way during drag. The current implementation uses `withAnimation(.easeInOut(duration: 0.2))` only on the `moveItem` call, but items inside `LazyVGrid` don't animate position changes naturally.

**Fix:** Add `.animation(.spring(...), value: items)` to the grid or use `matchedGeometryEffect` for individual items to create fluid rearrangement animations.

---

### 🟡 Singleton pattern overuse makes testing difficult
`ApplicationIconProvider.shared`, `NotificationBadgeProvider.shared`, `MenuBarService.shared`, `ICloudSyncService.shared`, `GlobalHotkeyService.shared`, `TrackpadGestureService.shared` are all singletons accessed directly in views and other services.

**Fix:** Inject these as dependencies (protocol-based) through the view model or environment objects. This enables unit testing with mocks and avoids hidden coupling.

---

### 🟡 `LaunchyViewModel` is a 850+ line god object
The view model handles items, paging, editing, selection, folders, drag coordination, iCloud sync, import/export, undo/redo, app launching, and Finder integration all in one class.

**Fix:** Extract distinct responsibilities into focused coordinators:
- `FolderManager` — create, disband, rename, recolor folders
- `SearchManager` — fuzzy matching and filtered paging
- `AppLaunchCoordinator` — launching apps, dismiss-after-launch
- `ImportExportManager` — file panel + JSON encode/decode
Keep `DragCoordinator` (already extracted) as a pattern to follow.

---

### 🟡 Context menu on folder tiles offers both "Remove Folder" and "Split Folder"
"Remove Folder" calls `deleteItem` which also disbands the folder (apps go back to grid), making it identical to "Split Folder." The user sees two options that do the same thing.

**Fix:** Make "Remove Folder" actually delete the folder *and its contents* (with confirmation), or remove the duplicate entry and only offer "Split Folder" + "Remove Folder" with a clear distinction.

---

### 🟢 `chunked(into: 0)` returns `[self]` instead of an empty array
The guard checks `size > 0` and returns `[self]` for zero, which is surprising. A chunk size of zero or negative is a programming error.

**Fix:** Return `[]` for invalid sizes, or use `precondition(size > 0)` in debug builds.

---

### 🟢 Missing `Hashable` conformance on `LaunchyItem`
`LaunchyItem` conforms to `Equatable` but not `Hashable`. Since `AppIcon` is `Hashable`, and `LaunchyFolder` could be, the enum should be too for `Set`/`Dictionary` usage.

**Fix:** Add `Hashable` conformance to `LaunchyFolder` and `LaunchyItem`.

---

### 🟢 No loading skeleton or placeholder while layout loads
The loading state shows a plain `ProgressView` with text. Real Launchpad shows a blurred desktop with a grid shimmer.

**Fix:** Show a placeholder grid of rounded rectangles with a shimmer animation while `isLayoutLoaded` is false.

---

### 🟢 Test coverage gaps
There are 67 tests covering the view model, settings model, and settings store, but **zero tests** for:
- `DragCoordinator` (the most complex drag logic)
- `LaunchyDataStore.reconcile` (tested indirectly via stub, but edge cases like folder-with-one-remaining-app are untested directly)
- `String.fuzzyMatch` (critical for search quality)
- `LayoutUndoManager`
- `InstalledApplicationsProvider`

**Fix:** Add dedicated test suites for each of these.

---

## ✨ New Features (to match real Launchpad)

### 🔴 No dismiss-on-click-outside behavior on the desktop
Real Launchpad dismisses when you click anywhere on the desktop wallpaper behind the grid. Currently, clicking the dark background in fullscreen mode works, but there's no way to click *through* to the desktop to dismiss.

**Fix:** Consider making the window click-through for empty areas outside the grid content, or dismiss on any deactivation event.

---

### 🟠 No Spotlight-like instant search result launching
Real Launchpad lets you type and press Enter to launch the top search result immediately, without clicking.

**Fix:**
1. Track the "top result" from `pagedItems(matching:)`.
2. Add a keyboard handler for Return/Enter that launches the top result.
3. Optionally highlight the top result visually.

---

### 🟠 No multi-display awareness for fullscreen
Real Launchpad opens on the display where the cursor currently is. The `screenContainingCursor()` function exists in `WindowConfigurator` but full multi-monitor support (separate Launchpad instance per display, or following the cursor) may need more work.

**Fix:** Test thoroughly with multiple displays. Ensure the window moves to the correct screen when toggled via hotkey from a different display than it was last on.

---

### 🟠 No opening animation
Real Launchpad has a characteristic zoom-in animation when appearing (icons scale up from ~70% with a spring) and a zoom-out when dismissing. Currently, the window just appears/fades.

**Fix:** Add a `.transition(.scale(scale: 0.8).combined(with: .opacity))` to the root content, triggered by a `@State var isPresented` flag with a spring animation on show/hide.

---

### 🟠 No pinch-to-zoom between Launchpad and Desktop
Real Launchpad uses a five-finger pinch gesture to toggle. The `TrackpadGestureService` exists but isn't wired up (see Bugs section). Beyond wiring it up, the gesture should trigger the zoom animation.

---

### 🟡 No automatic page creation when dragging to the edge
Real Launchpad creates a new empty page when you drag an icon to the rightmost edge past the last page. Currently, cross-page drag only navigates between existing pages.

**Fix:** In the right-edge `CrossPageEdgeDropDelegate`, detect when `direction == +1` and `targetPage >= totalPages`, then insert an empty page and navigate to it.

---

### 🟡 No alphabetical sort option
Real Launchpad (and many launchers) offer a button or setting to sort all apps alphabetically (resetting custom arrangement).

**Fix:** Add a "Sort Alphabetically" button in settings or the editing banner that calls a `sortAlphabetically()` method on the view model.

---

### 🟡 No app badge counts on folder icons
Real Launchpad shows an aggregate badge count on folders (sum of all badges inside). Currently, `NotificationBadgeProvider` only shows badges on individual app icons, not on folder previews.

**Fix:** In `FolderIconView`, query the badge provider for all apps inside the folder and display the sum or a generic indicator badge.

---

### 🟡 No "Recently Added" highlighting
Real Launchpad briefly highlights newly installed apps with a small blue dot. The app has no mechanism to track which apps are new since the last session.

**Fix:** Store a set of "known" bundle identifiers. After reconciliation, compare against the new set and mark new apps. Show a subtle indicator (blue dot under the icon name) that clears on first launch or after a timeout.

---

### 🟡 No drag-to-remove (drag to Dock trash area)
Real Launchpad lets you drag an app icon toward the bottom of the screen to show an "X" / uninstall prompt. There's currently no gesture-based removal.

**Fix:** Detect when a dragged item is moved below the grid area, show a "Remove" zone at the bottom, and call `deleteItem` on drop.

---

### 🟡 Folder paging for large folders
Real Launchpad supports pages *inside* folders when a folder has more apps than fit in one grid. Currently, `FolderContentView` shows all apps in a single scrolling `LazyVGrid`.

**Fix:** Chunk folder apps by `folderColumns × folderRows` and add paging dots inside the folder overlay, with horizontal swipe navigation.

---

### 🟡 No "Show in Launchpad" integration from Finder
Real Launchpad automatically includes newly installed apps. The current reconciliation runs only at launch time.

**Fix:** Set up an `FSEventStream` or `DispatchSource.makeFileSystemObjectSource` to watch `/Applications`, `/System/Applications`, and `~/Applications` for changes. Re-run reconciliation when changes are detected.

---

### 🟡 No configurable global hotkey
The hotkey is hardcoded to F4 (keyCode 118). Users should be able to change this.

**Fix:** Add a hotkey picker in Settings (e.g., using a key-recording field). Store the chosen keyCode in `GridSettings` and update `GlobalHotkeyService.keyCode` when it changes.

---

### 🟡 No Launchpad database import
Users migrating from the real Launchpad have their layout stored in `~/Library/Application Support/Dock/*.db` (SQLite). An importer could read this and recreate the arrangement.

**Fix:** Add an "Import from Launchpad" option that reads the Dock's Launchpad SQLite database and maps groups/pages/items to the Launchy data model.

---

### 🟢 No VoiceOver / accessibility support
Beyond a single `.accessibilityLabel` on page dots, there are no accessibility labels, traits, or hints on app tiles, folders, the search field, or editing controls.

**Fix:** Add comprehensive accessibility labels and traits:
- App tiles: `.accessibilityLabel(icon.name)` + `.accessibilityHint("Double tap to open")`
- Folders: `.accessibilityLabel("\(folder.name) folder, \(folder.apps.count) apps")`
- Edit mode: `.accessibilityAddTraits(.isSelected)` for selected items
- Page announcement: post `UIAccessibility.Notification.pageScrolled` equivalent on page change.

---

### 🟢 No Dock-like bounce animation on app launch
Real Launchpad shows the icon zooming towards the camera when launching. The current implementation uses a simple `scaleEffect(1.25)` + `opacity(0)` which is functional but not as polished.

**Fix:** Use a `matchedGeometryEffect` or a custom `GeometryEffect` that combines scale, y-translation, and 3D perspective to simulate the icon "jumping out" of the grid.

---

### 🟢 No support for System Settings / System Preferences distinction
On macOS 13+, "System Preferences" was renamed to "System Settings" and uses a different bundle structure. The current `InstalledApplicationsProvider` should handle this, but there may be edge cases with hidden system apps.

**Fix:** Verify that System Settings, Screen Saver, and other special system apps appear correctly. Consider adding a configurable allowlist/blocklist for apps to show/hide.

---

### 🟢 App icon cache is not invalidated when apps update
`ApplicationIconProvider` caches icons in an `NSCache` with no expiry. If an app updates its icon, the stale version persists until app restart.

**Fix:** Listen for `NSWorkspace.didLaunchApplicationNotification` or periodically clear the cache. Alternatively, check file modification dates on the `.app` bundle.

---

### 🟢 No Homebrew Cask / non-standard app directory support
Some users install apps via Homebrew (`/opt/homebrew/Caskroom`) or other package managers. These apps may have symlinks in `/Applications` (already covered) but non-standard install locations are missed.

**Fix:** Add a "Custom Search Directories" setting where users can add additional paths to scan for `.app` bundles.

---

## 📐 Architecture & Code Quality

### 🟡 `NotificationCenter` used for in-app communication
`resetToDefaultLayout`, `toggleInAppSettings`, `dismissLauncher`, `exportLayout`, `importLayout`, `launcherDidReappear`, and `menuBarToggleLauncher` all use `NotificationCenter` as a loose coupling mechanism. This is fragile, hard to trace, and the `resetToDefaultLayout` bug (see above) proves the pattern's risk.

**Fix:** Replace with direct method calls through the view model or a dedicated `AppCoordinator` object. If events must cross architectural boundaries, use Combine `PassthroughSubject` with typed payloads.

---

### 🟡 `@unchecked Sendable` on `AppDelegate`
`AppDelegate` is marked `@unchecked Sendable` but has no thread-safety guarantees documented. All methods appear to be `@MainActor`-isolated, so the annotation is technically safe but smells.

**Fix:** Make `AppDelegate` explicitly `@MainActor` isolated (it already is via `NSApplicationDelegate` inheritance) and remove `@unchecked Sendable`.

---

### 🟡 `nonisolated(unsafe)` in `LaunchyDataStore.loadAsync` and `loadFresh`
The `InstalledApplicationsProvider` is value-type but wraps `FileManager`, and the `nonisolated(unsafe)` annotation hides a potential thread-safety issue if `FileManager.default` has issues in concurrent contexts.

**Fix:** Move the disk scanning to a `Task.detached` that explicitly constructs its own `InstalledApplicationsProvider(fileManager: .default)` instead of capturing from the main-actor-isolated `self`.

---

### 🟡 Mixed `DispatchQueue.main.async` and `Task { @MainActor }` patterns
The codebase inconsistently uses GCD (`DispatchQueue.main.async`) in some places and structured concurrency (`Task { @MainActor }`) in others for main-thread dispatch. This is confusing and can lead to subtle ordering bugs.

**Fix:** Standardize on structured concurrency (`Task { @MainActor in ... }`) throughout. Replace all `DispatchQueue.main.async` calls in Swift 6 code.

---

### 🟡 `HotkeyState` uses `nonisolated(unsafe)` for mutable state accessed from a C callback
The comment says "all mutations happen on the main thread in practice" but the C callback runs on the CGEvent tap's mach port thread. Reading `keyCode` and `eventTap` from a background thread while the main thread writes is technically a data race.

**Fix:** Use `OSAllocatedUnfairLock` or `Mutex` to protect shared state, or use atomics for the `keyCode` field.

---

### 🟢 Duplicated `dismissLauncher()` logic
`dismissAfterLaunch()` in the view model and `dismissLauncher()` in `LaunchyRootView` do nearly the same thing (fade out, order out, hide). The duplication risks them diverging.

**Fix:** Consolidate into a single dismiss path, perhaps a method on the view model or a dedicated `WindowManager` service.

---

### 🟢 Duplicated folder color picker UI
The color picker `HStack` with `ForEach(IconColor.allCases)` is copy-pasted between `FolderContentView` and `LaunchyRootView.newFolderSheet`.

**Fix:** Extract a reusable `IconColorPicker` component.

---

### 🟢 Window identification is fragile
`NSApp.windows.first(where: { $0.identifier?.rawValue != "com_apple_SwiftUI_Settings_window" })` relies on SwiftUI's internal window identifier string which could change between macOS versions.

**Fix:** Set a custom `window.identifier` on the main launcher window during configuration and filter by that known identifier.

---

## 📝 Documentation & Project

### 🟡 CHANGELOG references [Unreleased] but has no items
The `## [Unreleased]` section is empty. All the items in this TODO should be tracked there as they're completed.

---

### 🟡 README architecture diagram is stale
The mermaid diagram doesn't mention `DragCoordinator`, `LayoutUndoManager`, `MenuBarService`, `TrackpadGestureService`, `NotificationBadgeProvider`, `ICloudSyncService`, or `ApplicationIconProvider`.

**Fix:** Update the diagram to reflect the current architecture.

---

### 🟡 README says macOS 14.0+ but Swift 6.2 toolchain
The Swift 6.2 toolchain ships with Xcode 17 which targets macOS 26. Consider whether macOS 14 is the real floor (it is, per `Package.swift`), and note that building requires the Swift 6.2 toolchain specifically.

---

### 🟢 No screenshots in README
For a visual application like a Launchpad clone, screenshots or a GIF demo would greatly help contributors and users understand what they're getting.

---

### 🟢 Missing CONTRIBUTING guidance on running/testing locally
The `CONTRIBUTING.md` says "follow the pull request template" but doesn't explain how to run the app locally, how to test, or how to configure accessibility permissions for the global hotkey.

---

## 🎨 Visual Polish (to match real Launchpad)

### 🟠 Background blur is too dark / not desktop-aware enough
Real Launchpad applies a Gaussian blur to the actual desktop wallpaper with a subtle dark overlay (~15% black). The current `DesktopBackdropView` uses `.fullScreenUI` material which is much denser. The `blurIntensity` setting helps but the material itself is different.

**Fix:** Use `.hudWindow` or `.underPageBackground` material instead of `.fullScreenUI`, or capture the desktop wallpaper image directly and apply a custom `CIGaussianBlur`.

---

### 🟡 Page dots don't match real Launchpad style
Real Launchpad uses small circular dots (not capsules). The active dot is white, inactive dots are gray, and they don't change size — just opacity/color.

**Fix:** Change the page control from capsule shapes to uniform circles with only opacity/color differentiation.

---

### 🟡 Folder overlay doesn't match Launchpad's appearance
Real Launchpad's folder overlay has a full-width translucent banner that extends across the screen at the row where the folder was tapped, with a small triangle pointer. The current implementation is a centered rounded rectangle.

**Fix:** Redesign the folder overlay to match: a full-width blurred band at the folder's row position, with a triangle indicator pointing at the folder icon below it.

---

### 🟡 Search field positioning
Real Launchpad puts the search field at the **top center** of the screen. The current implementation puts it in the top-left header alongside other controls.

**Fix:** Move the search field to a centered position above the grid, possibly in its own row.

---

### 🟡 Icon shadow is too aggressive
The `shadow(color: .black.opacity(0.28), radius: 12, x: 0, y: 8)` on app icons is noticeably heavier than real Launchpad's subtle shadow.

**Fix:** Reduce to approximately `shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)`.

---

### 🟢 No icon reflection/glow effect
Real Launchpad icons have a very subtle glow/reflection on the bottom edge, giving them a slight 3D feel.

**Fix:** Add a faint gradient overlay on the lower portion of the icon, or a subtle bottom highlight.

---

### 🟢 Delete badge (× button) is oversized
The delete badge uses `dimension * 0.28` for font size and is filled with red, making it much larger and more prominent than real Launchpad's small, subtle × badge.

**Fix:** Reduce to ~`dimension * 0.18`, use a darker translucent background, and position it tighter to the icon corner.

---

### 🟢 Edit/Settings/Search UI elements should hide during non-edit mode for cleaner look
Real Launchpad has a very minimal chrome — just the search field at the top and page dots at the bottom. The edit button, settings gear, and selection summary add visual noise that the original doesn't have.

**Fix:** Consider hiding the edit button and settings gear behind a long-press or right-click menu, only showing them in edit mode, or making them auto-fade after a few seconds.

---

## 🏗️ Build & Distribution

### 🟡 Info.plist should declare accessibility usage
The app requires Accessibility permissions for the global hotkey (`CGEvent.tapCreate`). The plist should include `NSAccessibilityUsageDescription` to explain why.

**Fix:** Add `<key>NSAccessibilityUsageDescription</key><string>Launchy uses Accessibility permissions to listen for the global hotkey (F4) to show and hide the launcher.</string>` to the plist template.

---

### 🟡 No DMG background or Applications symlink
The `make dmg` target creates a plain DMG. A polished DMG should have a background image with an arrow pointing from the app icon to an `/Applications` symlink.

**Fix:** Add a DMG background image to `assets/` and update the `hdiutil` command (or use `create-dmg` tool) to set the background, icon positions, and Applications symlink.

---

### 🟢 No auto-update mechanism
Real Launchpad updates via the App Store. As a standalone app, Launchy has no way to notify users of updates.

**Fix:** Consider integrating Sparkle framework for auto-updates, or at least a simple version check against the GitHub releases API on launch.

---

### 🟢 No CI workflow for running tests
The `.github/workflows/` directory likely has CI config but tests should run on every PR to prevent regressions.

**Fix:** Ensure the GitHub Actions workflow includes `swift test` on macOS runners.