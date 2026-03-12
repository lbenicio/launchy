# Launchy — Roadmap & TODO

> Living document with findings from the v0.4.2 codebase review.
> Items are grouped by category and sorted roughly by impact.
> Priority labels: **P0** ship-blocker · **P1** important · **P2** should-do · **P3** nice-to-have · **Idea** future exploration

---

## 🐛 Bugs

### P0 — Ship-blockers

- [x] **App launch doesn't dismiss the launcher**
  `launch()` in `LaunchyViewModel` opens the target application but the Launchy window stays on screen. Real Launchpad fades out immediately after you click an app. After calling `NSWorkspace.shared.openApplication` the launcher should hide or terminate itself.
  _File: `LaunchyViewModel.swift` → `launch(_:)`_

- [x] **No Escape key handling**
  Pressing Escape should close the launcher (or close an open folder / settings overlay first). There is no key handler for `keyCode 53` anywhere. `PageNavigationKeyHandler` handles arrows but not Escape.
  _File: `PageNavigationKeyHandler.swift`, `LaunchyRootView.swift`_

### P1 — Important

- [x] **Deleting a folder silently destroys all apps inside it**
  `deleteItem` on a folder removes it and every app it contains — no confirmation, no undo. Expected behavior: either show a confirmation alert or auto-disband (move apps back to the grid) before removing the folder shell.
  _File: `LaunchyViewModel.swift` → `deleteItem(_:)`_

- [ ] **Delete button removes apps from layout with no way to recover**
  The ✕ badge in editing mode removes an `AppIcon` from the persisted `items` array. The app will reappear on next launch (reconciliation re-adds installed apps), but during the session it's gone with no undo. Consider hiding instead of removing, or adding a "recently removed" staging area.
  _File: `LaunchyViewModel.swift` → `deleteItem(_:)`_

- [ ] **`FolderContentView` holds a stale snapshot of the folder**
  The view receives `let folder: LaunchyFolder` (a value type). Drag operations that mutate the folder's apps (reorder, add, remove) update `viewModel.items` but the view still holds the old copy. It re-renders only when SwiftUI detects changes through `@ObservedObject var viewModel`, but the `folder` local passed to sub-views is stale. Should derive the folder reactively via `viewModel.folder(by: folderID)` inside the body.
  _File: `FolderContentView.swift`_

- [ ] **`presentationOptions` not restored on unexpected termination**
  If the app is force-quit or crashes while fullscreen, `NSApp.presentationOptions` stays at `[.autoHideDock, .autoHideMenuBar]`. The dock and menubar remain auto-hidden until another app resets them. Add cleanup in `applicationWillTerminate` or use `NSApp.delegate`.
  _File: `WindowConfigurator.swift`, `LaunchyApp.swift`_

- [ ] **Duplicate `Settings` scene in `LaunchyApp`**
  The app declares both a system `Settings { SettingsView(...) }` scene AND an in-app overlay in `LaunchyRootView`. In fullscreen mode the system settings window opens *behind* the Launchy window and is unreachable. Either remove the `Settings` scene or wire ⌘, to toggle the in-app overlay instead.
  _File: `LaunchyApp.swift`_

### P2 — Should-do

- [ ] **Search should flatten folders and show individual apps**
  `pagedItems(matching:)` returns the entire folder when any child matches. The folder preview grid doesn't highlight which app matched. Real Launchpad breaks folders open during search and shows each matching app as a standalone tile.
  _File: `LaunchyViewModel.swift` → `pagedItems(matching:)`_

- [ ] **`NSWorkspace.openApplication` errors are silently ignored**
  The completion handler `{ _, _ in }` discards both the running application reference and any error. On failure the user sees nothing. Should surface a brief alert or console log.
  _File: `LaunchyViewModel.swift` → `launch(_:)`_

- [ ] **`LaunchyDataStore` is not concurrency-safe**
  The class is not annotated `@MainActor` or `Sendable`. `save()` is called from `DispatchWorkItem`s that may execute on arbitrary queues. Under Swift 6 strict concurrency this is a latent data race.
  _File: `LaunchyDataStore.swift`_

### P3 — Nice-to-have

- [ ] **`folderCapacity` computed property is never used**
  `GridSettings.folderCapacity` exists but no code references it. Either implement folder content pagination or remove the dead code.
  _File: `GridSettings.swift`_

- [ ] **Release workflow doesn't bundle the app icon**
  `.github/workflows/release.yml` copies the binary into a `.app` bundle but skips the `Resources/` directory and `launchy.icns`. The Makefile `bundle` target handles this correctly — the workflow should match.
  _File: `.github/workflows/release.yml`_

---

## ⚡ Performance

### P1

- [ ] **`ApplicationIconProvider.icon(for:)` loads icons synchronously on the main thread**
  `NSWorkspace.shared.icon(forFile:)` can be slow for apps on network volumes or APFS snapshots. With 150+ apps, this blocks the first layout pass. Consider pre-warming the cache on a background thread during `LaunchyDataStore.load()`.
  _File: `ApplicationIconProvider.swift`_

- [ ] **`InstalledApplicationsProvider.fetchApplications()` blocks the main thread**
  FileManager enumeration of `/Applications`, `/System/Applications`, and `~/Applications` is synchronous disk I/O. Should run on a background task and publish results.
  _File: `InstalledApplicationsProvider.swift`_

### P2

- [ ] **`pagedItems` is a computed property re-chunked on every access**
  Used by `pages` (in the view body), `pageCount`, `ensureCurrentPageInBounds`, and `pagedItems(matching:)`. Each access re-runs `chunked(into:)` over the full items array. Cache the result and invalidate when `items` or `settings.pageCapacity` changes.
  _File: `LaunchyViewModel.swift`_

- [ ] **`item(with:)` does a linear scan on every call**
  Called per-tile during rendering and selection checks. For large grids (100+ items) a `[UUID: LaunchyItem]` lookup dictionary would be O(1) instead of O(n).
  _File: `LaunchyViewModel.swift`_

---

## 🧪 Test Coverage

The test suite currently has **4 tests** across 3 files. The drag-and-drop, folder management, and pagination code paths — where most of the recent bugs lived — have zero coverage.

### P1 — High-value tests to add

- [ ] **`extractDraggedItemIfNeeded`** — drag from folder to grid, folder auto-disband when 1 app left
- [ ] **`stackDraggedItem` (app → folder)** — index adjustment after removal
- [ ] **`stackDraggedItem` (app → app)** — new folder creation, target index re-lookup
- [ ] **`moveItem`** — no-op when already adjacent, append when target is nil
- [ ] **`deleteItem`** — deleting last app in folder removes the folder
- [ ] **`disbandFolder`** — apps inserted at correct index
- [ ] **`createFolder`** — insertion at first selected index, minimum 2 apps guard
- [ ] **`pagedItems(matching:)`** — query normalization, folder name match, child app match

### P2 — Additional coverage

- [ ] **`GridLayoutMetrics`** — distributed spacing math, ultrawide clamp, tighten loop convergence
- [ ] **`GridSettingsStore`** — round-trip encode/decode, clamping boundary values
- [ ] **`Array.chunked(into:)`** — empty array, size larger than count, size of 1
- [ ] **Page navigation** — `selectPage`, `goToPreviousPage`, `goToNextPage` boundary clamping
- [ ] **Reconciliation** — `LaunchyDataStore.reconcile` with missing apps, new apps, stale folders

---

## ✨ Features — Launchpad Parity

These are behaviors present in the original macOS Launchpad that Launchy doesn't yet replicate.

### P1

- [ ] **Long-press to enter wiggle mode**
  Real Launchpad enters editing (wiggle) mode when you long-press any icon. Currently Launchy only has a toolbar toggle button and ⌘E shortcut. Add a long-press gesture on `LaunchyItemView` that calls `viewModel.toggleEditing()`.

- [ ] **Hide window instead of terminating on background tap**
  `handleBackgroundTap` calls `NSApplication.shared.terminate(nil)`. Real Launchpad dismisses the overlay and returns to the desktop without quitting. Consider `NSApp.hide(nil)` or `window.orderOut(nil)` with a global hotkey to bring it back.

- [ ] **Folder name inline editing**
  Real Launchpad lets you click the folder title to rename it. `FolderContentView` renders the name as a static `Text`. Replace with a `TextField` that activates on tap during editing mode.

### P2

- [ ] **Cross-page drag-and-drop**
  Dragging an icon to the left/right edge of the screen should switch to the adjacent page and allow dropping there. Currently drag-and-drop only works within a single page.

- [ ] **Smooth open/close folder animation**
  Real Launchpad zooms the folder open from its icon position. The current implementation uses a generic `.scale + .opacity` transition. A matched geometry effect from the folder icon to the expanded content would look closer to the original.

- [ ] **App launching fade-out animation**
  Real Launchpad plays a subtle zoom + fade when you tap an app. The current launch is instant with no visual feedback.

### P3

- [ ] **Notification badges on app icons**
  Real Launchpad mirrors dock badge counts. This requires reading `NSApp.dockTile` or `DistributedNotificationCenter` for badge updates from other apps.

- [ ] **Multi-display support**
  `WindowConfigurator` uses `window.screen ?? NSScreen.main`. On multi-monitor setups the launcher should appear on the screen where the cursor is, matching real Launchpad behavior.

---

## 🎨 UX & Polish

### P1

- [ ] **Global hotkey to toggle Launchy**
  Real Launchpad can be triggered with F4, a trackpad gesture, or a hot corner. Launchy has no activation mechanism other than launching the app. Register a global hotkey (e.g., `CGEvent.tapCreate` or `MASShortcut`) or at least support a configurable keyboard shortcut in Settings.

- [ ] **Restore presentation options on quit**
  Add an `NSApplicationDelegate` method (`applicationWillTerminate`) that resets `NSApp.presentationOptions = []` to guarantee the dock and menubar come back even on a clean quit.

### P2

- [ ] **Folder color picker**
  `IconColor` has 10 beautiful colors but new folders always get `.gray`. Add a color picker strip in `FolderContentView` header (visible in editing mode) or in the folder creation sheet.

- [ ] **Right-click context menu on app tiles**
  Options: "Open", "Show in Finder", "Remove from Launchy", "Get Info". Would provide discoverability for power users who don't want wiggle mode.

- [ ] **"Reset to Default Layout" button in Settings**
  Deletes the persisted JSON and reloads from `InstalledApplicationsProvider`. Useful when the layout gets into a bad state.

### P3

- [ ] **Icon size preview in Settings**
  The "Icon Scale" slider changes a number but gives no visual feedback. Show a small preview tile that scales in real-time.

- [ ] **Smooth page transition on search**
  When the search text changes, the grid jumps to page 0 without animation. Add a cross-fade or slide transition.

- [ ] **Empty-state illustration**
  When no apps match the search, show a friendlier empty state than just a text capsule — maybe a magnifying glass icon with a subtitle.

---

## 🏗️ Architecture & Code Quality

### P2

- [ ] **Extract drag-and-drop logic into a dedicated `DragCoordinator`**
  `LaunchyViewModel` is ~590 lines with drag state, stacking timers, debounced saves, and folder mutation all interleaved. A focused `DragCoordinator` object would be easier to test and reason about.

- [ ] **Replace `DispatchWorkItem` timers with structured concurrency**
  The stacking delay, save debouncer, and launch suppression all use raw `DispatchWorkItem` + `asyncAfter`. Swift concurrency `Task.sleep` with cancellation would be cleaner and avoid retain-cycle risks.

- [ ] **Add `@MainActor` to `LaunchyDataStore`**
  Or make `save()` / `load()` explicitly async. Currently relies on callers always being on the main thread, which isn't enforced by the type system.

- [ ] **Make `LaunchyFolder.color` part of folder creation UI**
  The model supports it, the view renders it, but the creation flow never sets it.

### P3

- [ ] **Rename test file `LaunchpadViewModelTests.swift` → `LaunchyViewModelTests.swift`**
  Leftover from the pre-rebrand naming. The class inside is already `LaunchyViewModelTests` but the filename still says `Launchpad`.

- [ ] **Add `Sendable` conformance to model types**
  `AppIcon`, `LaunchyFolder`, `LaunchyItem`, `GridSettings` are all value types and should be explicitly `Sendable` for Swift 6.

- [ ] **Consolidate `makeProvider(for:)` helper**
  The same `NSItemProvider` creation code is duplicated in `LaunchyGridPageView` and `FolderContentView`. Extract into an extension on `LaunchyDragIdentifier`.

---

## 📦 Build & CI

### P2

- [ ] **Add app icon to release workflow**
  The `.github/workflows/release.yml` `Create .app bundle` step doesn't copy `assets/icon/launchy.icns` into `Contents/Resources/`. The Makefile does — sync them.

- [ ] **Add a CI workflow for pull requests**
  Currently there's only a manual release workflow and a notification workflow. A PR workflow that runs `swift build && swift test` on every push would catch regressions early.

- [ ] **Pin `actions/create-release` and `actions/upload-release-asset`**
  Both use `@v1` which is deprecated. Migrate to `softprops/action-gh-release` or pin to SHA digests.

### P3

- [ ] **Add `swift-format` config file**
  The Makefile has `fmt` and `lint` targets using `swift format`, but there's no `.swift-format` configuration file to enforce consistent style across contributors.

- [ ] **Code signing and notarization in CI**
  The release artifact is unsigned. macOS Gatekeeper will block it on first launch. Add `codesign` and `notarytool` steps (requires Apple Developer credentials as secrets).

---

## 📝 Documentation

### P2

- [ ] **Add keyboard shortcuts reference to README**
  Document ⌘E (toggle wiggle mode), arrow keys for page navigation, and the planned Escape behavior.

- [ ] **Architecture overview diagram**
  A simple Mermaid diagram showing the data flow: `InstalledApplicationsProvider → LaunchyDataStore → LaunchyViewModel → Views` would help new contributors.

### P3

- [ ] **Add inline doc comments to public ViewModel methods**
  Methods like `extractDraggedItemIfNeeded`, `stackDraggedItem`, `requestStacking` have non-obvious semantics that would benefit from `///` documentation.

- [ ] **CONTRIBUTING.md needs updating**
  Still references generic steps. Should mention `make fmt`, `make test`, the StubFileManager pattern for testing, and the `TODO.md` file.

---

## 💡 Ideas for the Future

These aren't bugs or missing parity features — just things that could make Launchy special.

- [ ] **Spotlight-style instant search with fuzzy matching**
  Use `String.localizedStandardContains` or a Levenshtein distance for typo-tolerant search.

- [ ] **Import/export layout as JSON**
  Let users backup, share, or sync their icon arrangement across machines.

- [ ] **Undo/redo stack for layout changes**
  Integrate with `UndoManager` so ⌘Z reverts the last move, folder creation, or deletion.

- [ ] **Drag apps from Finder into the grid**
  Accept `.fileURL` drops on the grid to add apps that aren't in the standard directories.

- [ ] **Widget / menu bar companion**
  A small menu bar icon that shows recently launched apps and provides a one-click way to open Launchy.

- [ ] **Theming / custom backgrounds**
  Let users pick a solid color, gradient, or wallpaper blur intensity for the backdrop.

- [ ] **Trackpad gesture activation**
  Register a four-finger pinch gesture (like real Launchpad) using `CGEventTap` or accessibility APIs.

- [ ] **iCloud sync for layout**
  Persist `launchy-data.json` to `NSUbiquitousKeyValueStore` or CloudKit so the layout follows the user across Macs.

---

_Last reviewed: 2026-03-12 · Launchy v0.4.2_