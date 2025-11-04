# Architecture Overview

This document summarises Launchy’s high-level design, data flow, and runtime lifecycle. It complements the top-level guide with deeper notes about how components interact at runtime.

## Layered Design

Launchy uses a layered architecture to keep responsibilities separated. Each layer builds on the services provided by the layers beneath it.

```text
+------------------------------------------------------------+
|                      Interface Layer                       |
|  SwiftUI scenes, view models, gestures, animations, focus  |
+-------------------------+----------------------------------+
|        Application Layer | Observable stores (state)       |
|                          | App-level orchestration         |
+-------------------------+----------------------------------+
|         Domain Layer     | Pure value types (models)       |
+-------------------------+----------------------------------+
|     Infrastructure Layer | Persistence, catalog scanning,  |
|                          | keyboard & window integration   |
+------------------------------------------------------------+
```

- **Interface** (`src/Interface`): SwiftUI views, scenes, and UI composition. Responsible for rendering the grid, search bar, folder overlays, and settings window.
- **Application** (`src/Application`): Observable stores (`AppCatalogStore`, `AppSettings`) that coordinate asynchronous work, mutate state, and emit updates consumed by the UI.
- **Domain** (`src/Domain`): Lightweight models (`AppItem`, `FolderItem`, `CatalogEntry`) shared by all layers and free of AppKit/SwiftUI dependencies.
- **Infrastructure** (`src/Infrastructure`): System-level integrations—catalog scanning, layout persistence, accessibility permission prompts, keyboard monitoring, icon caching, and window configuration.

## Data Flow

1. **Catalog Loading**
   - At launch, `AppCatalogStore.reloadCatalog()` invokes `AppCatalogLoader.loadCatalog()` which scans known application directories on a background queue.
   - Results become `AppItem`/`FolderItem` values merged with the saved layout snapshot to restore user ordering.
   - The store publishes `rootEntries`, used directly by SwiftUI views via `@EnvironmentObject` bindings.

2. **User Interaction**
   - Gestures (drag, hover, scroll) and commands (keyboard shortcuts, context menus) call into `AppCatalogStore` APIs.
   - Store mutations are `@MainActor` and drive SwiftUI updates automatically through `@Published` properties.

3. **Persistence**
   - Layout changes enqueue async `Task` work that calls `LayoutPersistence.save(entries:)` off the main actor.
   - `AppSettings` writes immediately to `UserDefaults` in property observers, ensuring values survive crashes or sudden quits.

## Lifecycle & Daemon Mode

`AppLifecycleDelegate` bridges SwiftUI with AppKit:

- Sets the appearance and activation policy to keep Launchy frontmost and immersive.
- Mirrors the active screen’s bounds and restores the overlay whenever the app becomes active.
- Stores presentation options (Dock/Menu Bar visibility) and restores them when the app resigns active.
- Terminates the app on reopen requests (⌘Q, status menu) and ensures the primary window remains visible when appropriate.

ESC key behaviour is orchestrated by `ContentView`, `AppCatalogStore`, and `KeyboardMonitor`:

- When editing, ESC ends edit mode.
- With a folder presented, ESC dismisses the overlay.
- When a search query exists, ESC clears it.
- If none apply, ESC terminates the app via `NSApp.terminate(nil)`.

## Settings Synchronisation

`AppSettings` is an `ObservableObject` shared between the SwiftUI hierarchy and lifecycle delegate. It coordinates:

- Grid layout (columns & rows)
- Scroll threshold (minimum accumulated scroll delta before paging)

Published values flow automatically into views and drive the `GridMetricsCalculator` that resizes tiles to fit the active display.

## Keyboard Handling

`KeyboardMonitor` installs both local and global event taps:

- Local monitor ensures ESC and other keys work while Launchy is key.
- When accessibility permission is granted, a global monitor forwards key presses back into the app so the search field can activate quickly.
- Tests toggle monitors via `resetForTesting()`; production builds never expose this API.

## Rendering Pipeline

- The grid is rendered via `LazyVGrid` with adaptive sizing derived from `GridMetricsCalculator`.
- Paging relies on drag gestures and accumulated scroll deltas bounded by the user-defined threshold.
- Folder overlays animate via spring-based transitions and can spawn intra-folder drag operations.
- Settings UI is hosted inside an AppKit window configured at the auxiliary level via `AuxiliaryWindowConfigurator`.

## Error Handling & Resilience

- Filesystem operations in `AppCatalogLoader` ignore missing directories and skip unreadable bundles.
- Layout persistence catches write errors and logs them in debug builds without interrupting the UI.
- Accessibility prompts are skipped during automated tests to prevent dialogs from blocking CI.

## Future Enhancements

- Expand unit test coverage for drag-and-drop edge cases (e.g., nested folder merges).
- Consider persisting additional UI preferences (appearance, animation speed).
- Explore SwiftData/Core Data integration if catalog metadata grows in complexity.
- Profile animation performance on lower-powered hardware using Instruments.

## Future Enhancements (Ideas)

- Add Swift concurrency for asynchronous catalog loading to decouple from the main actor.
- Expand unit test coverage around `AppCatalogStore` drag-and-drop logic.
- Consider Core Data or SQLite persistence for large catalogs.
- Investigate animation performance on lower-end hardware (profiling with Instruments).
