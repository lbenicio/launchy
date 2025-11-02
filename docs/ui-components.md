# Interface & Interaction Guide

This guide documents the major user-facing components in Launchy, their responsibilities, and the interaction patterns that tie them together. It is designed to help developers reason about UI changes, maintain consistent behaviour, and implement new surfaces confidently.

## Top-Level Scene

### `LaunchyApp`

- Defined in `src/Interface/App/LaunchyApp.swift`.
- Creates shared `AppCatalogStore` and `AppSettings` instances using `@StateObject` so they persist across scene reloads.
- Injects those stores into SwiftUI environment, hosts `ContentView`, and applies a `VisualEffectView` backdrop for translucency.
- Configures app commands (`CommandGroup`) to remap settings, quit, close, and catalog reload shortcuts.

### `AppLifecycleDelegate`

- Configures AppKit presentation options once the app finishes launching.
- Ensures the primary window occupies the active screen and remains visible on activation.
- Restores Dock/menu bar visibility when Launchy resigns active or terminates.
- Responds to reopen events (dock icon, status item) by re-showing the primary window.

## Primary Overlay

### `ContentView`

- Central grid surface responsible for layout, pagination, folder presentation, and keyboard focus.
- Maintains local state (`tileFrames`, `selectedPage`, etc.) to drive animations and interactions.
- Uses `GridMetricsCalculator` to derive tile size, spacing, and pagination capacity from window dimensions and user preferences.
- Hosts overlays:
  - `ScrollWheelCaptureView` for smooth horizontal paging via scroll gestures.
  - `KeyPressCaptureView` to funnel type-to-search behaviour when search is not focused.
  - `FolderOverlay` when a folder is presented.
- Reacts to `AppCatalogStore` changes through `@EnvironmentObject` bindings (e.g., resets pagination when search query updates).

## Tiles & Gestures

### `CatalogEntryTile`

- Wrapper around either `AppIconView` or `FolderIconView` depending on the entry type.
- Tracks global frame updates for drag target detection.
- Handles long-press to enter edit mode and drag gestures to reorder or merge entries.
- Delegates drop completion to `AppCatalogStore.completeDrop(...)`, which persists layout changes when necessary.

### `AppIconView`

- Displays an application tile with icon, name, hover highlighting, and context menu.
- Handles primary action (launch app via `AppCatalogStore.launch(_)`).
- Context menu exposes Finder reveal while outside edit mode.

### `FolderIconView`

- Similar to `AppIconView` but opens folders instead of launching apps.
- In edit mode, the context menu offers a rename prompt implemented via `NSAlert`.
- Calls into `AppCatalogStore.present(_)` or `renameFolder` depending on user action.

## Folder Overlay

Defined in `src/Interface/Views/FolderOverlay.swift`.

- Animates from the originating tile to a centred overlay using spring interpolation.
- Uses `GridMetricsCalculator` to provide consistent paging inside folder layouts.
- Supports drag-out gestures (`FolderEditableAppTile`) so apps can be removed from folders and inserted into the root grid.
- Maintains local pagination state independent of the root grid.
- Exposes a "Dissolve" button in edit mode that removes the folder and re-inserts member apps into the root list.

## Settings

### `SettingsView`

- Tabbed interface with "Layout" and "About" sections.
- Binds sliders and steppers to `AppSettings` to update grid columns, rows, and scroll sensitivity in real time.
- Shows version/build metadata via `AppInfo` helper.
- Wrapped in `AuxiliaryWindowConfigurator` to ensure it floats above the main overlay.

### `SettingsWindowManager`

- Creates and manages the AppKit window hosting `SettingsView`.
- Reuses the same window controller across invocations to maintain state.
- Configures window level (`launchyAuxiliary`), collection behaviour, and close handling.

## Window Configuration

- `TransparentWindowConfigurator`: applied to the primary SwiftUI hierarchy to enforce borderless, full-screen, translucent behaviour at `launchyPrimary` level.
- `AuxiliaryWindowConfigurator`: applied to secondary hosts (settings, alerts) to float above the overlay while respecting full-screen spaces.

## Keyboard & Pointer Interactions

### Search Field Focus

- `ContentView` keeps the search field focused when not editing or interacting with folders.
- Keyboard events captured by `KeyPressCaptureView` feed text into the search bar when focus was lost.

### Scroll & Paging

- Horizontal drag gestures animate between pages; thresholds prevent accidental page flips.
- Scroll wheel deltas accumulate and must exceed `AppSettings.scrollThreshold` to change pages.
- Edge auto-advance monitors pointer position near screen edges during drags to trigger page navigation.

### Accessibility

- `KeyboardMonitor` requests accessibility permission the first time global keyboard capture is required. The UI degrades gracefully if permission is denied (type-to-search only works while Launchy is active).
- Context menus and buttons provide `help` and accessibility labels so VoiceOver can navigate the interface.

## Visual Design Notes

- Tile hover states use subtle opacity changes on rounded rectangles to avoid overwhelming the icon art.
- Folder overlays employ layered translucent backgrounds and strokes for visual depth.
- `VisualEffectView` with `.fullScreenUI` material ensures the primary overlay blends naturally with the desktop.
- `PageIndicator` and folder page indicators use small capsules to mirror macOS aesthetics.

## Extending the UI

1. **Add components under `src/Interface/Views/...`** with clear separation between reusable building blocks (`components/`) and feature-specific views.
2. **Mirror the file in `tests/Interface/Views/...`** to guarantee hostability and interaction behaviour.
3. **Update documentation** (`docs/ui-components.md`, `docs/structure.md`) when new top-level components or layouts are introduced.
4. **Respect existing focus and drag logic**: interact with `AppCatalogStore` methods instead of duplicating state to keep behaviour consistent.

Understanding these components and their contracts ensures UI changes integrate smoothly and maintain Launchy’s responsive, polished feel.
