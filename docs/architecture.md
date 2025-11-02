# Architecture Overview

This document explains the high-level design of Launchy. It focuses on how the application is composed, how data flows through the system, and how the runtime lifecycle supports both full-screen and daemon modes.

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

- **Interface** (`src/Interface`): SwiftUI views, scenes, and UI composition. Responsible for rendering the grid, folders, search bar, and settings window.
- **Application** (`src/Application`): Observable stores (`AppCatalogStore`, `AppSettings`) encapsulating state transitions and side effects triggered by UI interactions.
- **Domain** (`src/Domain`): Lightweight models (`AppItem`, `FolderItem`, `CatalogEntry`) used across the application, kept free of platform dependencies.
- **Infrastructure** (`src/Infrastructure`): System-level integrations (filesystem scans, layout persistence, keyboard monitoring, window configuration, status item management).

## Data Flow

1. **Catalog Loading**
   - At launch, `AppCatalogStore` calls `AppCatalogLoader.loadCatalog()` to enumerate `.app` bundles from standard directories.
   - Results are normalized into `AppItem` and `FolderItem` instances, then persisted order is merged via `LayoutPersistence`.
   - The store publishes `rootEntries`, which drives the UI grid.

2. **User Interaction**
   - UI gestures (drag, scroll, search) mutate `AppCatalogStore` state. Combine publishes updates that re-render SwiftUI views.
   - Edits to preferences (grid dimensions, scroll threshold, daemon mode) change `AppSettings`, which writes through to `UserDefaults`.

3. **Persistence**
   - Layout updates trigger `LayoutPersistence.save()` asynchronously, keeping disk writes off the main thread.
   - Preferences are persisted immediately inside `AppSettings.persist()` to ensure crash-safe settings.

## Lifecycle & Daemon Mode

`AppLifecycleDelegate` bridges SwiftUI with AppKit:

- Adjusts the activation policy between `.regular` and `.accessory` based on `AppSettings.daemonModeEnabled`.
- Configures the primary borderless window to mirror the current screen and hide system UI when active.
- Manages a status item when in daemon mode, exposing actions to reopen Launchy, show settings, or quit.
- Handles app activation events, ensuring the overlay is brought forward only when appropriate.

ESC key behavior is context-aware:

- If the user is editing or viewing a folder, the action cancels the modal state.
- When idle in daemon mode, ESC hides the window instead of terminating.
- Otherwise, ESC quits the app (non-daemon mode) via `NSApp.terminate(nil)`.

## Settings Synchronisation

`AppSettings` is an `ObservableObject` exposed to both views and the lifecycle delegate. It coordinates:

- Grid layout (columns & rows)
- Scroll threshold (minimum scroll delta before paging)
- Daemon mode flag

The delegate observes the daemon flag to update the activation policy live without restarting the app.

## Keyboard Handling

`KeyboardMonitor` installs both local and global event taps:

- Local monitor ensures ESC, Return, and other keys work when Launchy is frontmost.
- Global monitor requires accessibility permission; it captures keystrokes to refocus search even when Launchy is in the background.
- Events are funneled back to `AppCatalogStore`, which manipulates state (exiting folders, clearing search, ending edit mode).

## Rendering Pipeline

- The grid is rendered via `LazyVGrid` with adaptive sizing derived from `AppSettings`.
- Paging relies on tracking drag and scroll deltas, with thresholds and elasticity to mimic Launchpad.
- Folder overlays animate using spring interpolations for smooth open/close transitions.
- Settings window leverages `NSHostingView` embedded into an AppKit window configured at the auxiliary level.

## Error Handling & Resilience

- All filesystem operations in `AppCatalogLoader` are guarded with optional chaining; missing directories simply yield empty results.
- Layout persistence errors are logged in debug builds but do not crash the app.
- Deployment script (`scripts/deploy`) uses strict failure checks (`set -euo pipefail`) and provides dry-run support for rehearsals.

## Future Enhancements (Ideas)

- Add Swift concurrency for asynchronous catalog loading to decouple from the main actor.
- Expand unit test coverage around `AppCatalogStore` drag-and-drop logic.
- Consider Core Data or SQLite persistence for large catalogs.
- Investigate animation performance on lower-end hardware (profiling with Instruments).
