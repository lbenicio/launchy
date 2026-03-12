import Combine
import Foundation
import SwiftUI

#if os(macOS)
    import AppKit
#endif

@MainActor
final class LaunchyViewModel: ObservableObject {
    @Published var items: [LaunchyItem] {
        didSet { invalidateCaches() }
    }
    @Published var isEditing: Bool = false
    @Published var currentPage: Int = 0
    @Published var presentedFolderID: UUID? = nil
    @Published var selectedItemIDs: Set<UUID> = []
    @Published var isLaunchingApp: Bool = false
    @Published private(set) var launchingItemID: UUID? = nil
    @Published private(set) var isLayoutLoaded: Bool = false
    /// Apps removed during this session that can be restored without restarting.
    @Published private(set) var recentlyRemovedApps: [AppIcon] = []

    let dataStore: LaunchyDataStore
    let settingsStore: GridSettingsStore

    private(set) var dragCoordinator: DragCoordinator!

    private var cancellables: Set<AnyCancellable> = []
    private var saveDebouncerTask: Task<Void, Never>?
    private let saveDebouncerDelay: TimeInterval = 0.5

    // MARK: - Caches

    private var _cachedPagedItems: [[LaunchyItem]]?
    private var _cachedPageCapacity: Int?
    private var _itemLookup: [UUID: LaunchyItem]?

    private func invalidateCaches() {
        _cachedPagedItems = nil
        _itemLookup = nil
    }

    private func buildItemLookup() -> [UUID: LaunchyItem] {
        var lookup = [UUID: LaunchyItem]()
        lookup.reserveCapacity(items.count * 2)
        for item in items {
            lookup[item.id] = item
            if case .folder(let folder) = item {
                for app in folder.apps {
                    lookup[app.id] = .app(app)
                }
            }
        }
        return lookup
    }

    init(
        dataStore: LaunchyDataStore,
        settingsStore: GridSettingsStore,
        initialItems: [LaunchyItem]? = nil
    ) {
        self.dataStore = dataStore
        self.settingsStore = settingsStore
        if let initialItems {
            items = initialItems
            isLayoutLoaded = true
        } else {
            items = []
            isLayoutLoaded = false
        }

        let storedPage = settingsStore.settings.lastWindowedPage ?? 0
        currentPage = min(max(storedPage, 0), max(pageCount - 1, 0))

        settingsStore.$settings
            .dropFirst()
            .sink { [weak self] _ in
                self?._cachedPagedItems = nil
                self?.ensureCurrentPageInBounds(shouldPersist: false)
            }
            .store(in: &cancellables)

        if initialItems != nil {
            ensureCurrentPageInBounds()
            persistLastVisitedPageIfNeeded(currentPage)
        } else {
            Task { [weak self] in
                guard let self else { return }
                let loaded = await dataStore.loadAsync()
                self.items = loaded

                // Pre-warm the icon cache in the background
                let appURLs = loaded.flatMap { item -> [URL] in
                    switch item {
                    case .app(let icon): return [icon.bundleURL]
                    case .folder(let folder): return folder.apps.map(\.bundleURL)
                    }
                }
                ApplicationIconProvider.shared.preWarmCache(for: appURLs)

                self.ensureCurrentPageInBounds()
                self.persistLastVisitedPageIfNeeded(self.currentPage)
                self.isLayoutLoaded = true
            }
        }

        dragCoordinator = DragCoordinator(viewModel: self)
        dragCoordinator.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    // MARK: - Forwarding drag state

    var dragItemID: UUID? { dragCoordinator.dragItemID }
    var dragSourceFolderID: UUID? { dragCoordinator.dragSourceFolderID }
    var pendingStackTargetID: UUID? { dragCoordinator.pendingStackTargetID }

    var settings: GridSettings { settingsStore.settings }

    var pagedItems: [[LaunchyItem]] {
        let capacity = settings.pageCapacity
        if let cached = _cachedPagedItems, _cachedPageCapacity == capacity {
            return cached
        }
        let result: [[LaunchyItem]]
        if capacity <= 0 {
            result = [items]
        } else {
            let chunks = items.chunked(into: capacity)
            result = chunks.isEmpty ? [[]] : chunks
        }
        _cachedPagedItems = result
        _cachedPageCapacity = capacity
        return result
    }

    func pagedItems(matching query: String) -> [[LaunchyItem]] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return pagedItems }

        var filtered: [LaunchyItem] = []

        for item in items {
            switch item {
            case .app(let icon):
                if icon.name.localizedCaseInsensitiveContains(normalized) {
                    filtered.append(item)
                }
            case .folder(let folder):
                if folder.name.localizedCaseInsensitiveContains(normalized) {
                    // Folder name matches — include all apps as standalone tiles
                    for app in folder.apps {
                        filtered.append(.app(app))
                    }
                } else {
                    // Check individual apps inside the folder
                    for app in folder.apps
                    where app.name.localizedCaseInsensitiveContains(normalized) {
                        filtered.append(.app(app))
                    }
                }
            }
        }

        let capacity = settings.pageCapacity
        guard capacity > 0 else { return [filtered] }
        let chunks = filtered.chunked(into: capacity)
        return chunks.isEmpty ? [[]] : chunks
    }

    var pageCount: Int {
        pagedItems.count
    }

    // MARK: - Paging helpers

    func selectPage(_ index: Int, totalPages: Int) {
        let clamped = min(max(index, 0), max(totalPages - 1, 0))
        guard clamped != currentPage else { return }
        currentPage = clamped
        persistLastVisitedPageIfNeeded(clamped)
    }

    func goToPreviousPage(totalPages: Int) {
        selectPage(max(currentPage - 1, 0), totalPages: totalPages)
    }

    func goToNextPage(totalPages: Int) {
        selectPage(min(currentPage + 1, totalPages - 1), totalPages: totalPages)
    }

    private func persistLastVisitedPageIfNeeded(_ page: Int) {
        guard !settings.useFullScreenLayout else { return }
        settingsStore.update(lastWindowedPage: page)
    }

    private func ensureCurrentPageInBounds(shouldPersist: Bool = true) {
        let maxIndex = max(pageCount - 1, 0)
        if currentPage > maxIndex {
            currentPage = maxIndex
            if shouldPersist { persistLastVisitedPageIfNeeded(currentPage) }
        }
    }

    // MARK: - Selection & Editing

    /// Toggles wiggle (edit) mode. Clears any active selection when exiting.
    func toggleEditing() {
        isEditing.toggle()
        if !isEditing {
            clearSelection()
        }
    }

    var hasSelectedApps: Bool {
        for id in selectedItemIDs {
            if let item = item(with: id), item.asApp != nil { return true }
        }
        return false
    }

    /// Toggles the selection state of the item with the given ID for batch operations.
    func toggleSelection(for id: UUID) {
        if selectedItemIDs.contains(id) {
            selectedItemIDs.remove(id)
        } else {
            selectedItemIDs.insert(id)
        }
    }

    func isItemSelected(_ id: UUID) -> Bool { selectedItemIDs.contains(id) }

    func clearSelection() {
        selectedItemIDs.removeAll()
    }

    // MARK: - Item accessors

    /// Looks up any item (app or folder, including apps nested inside folders) by ID.
    /// Uses a cached lookup table for O(1) access.
    func item(with id: UUID) -> LaunchyItem? {
        let lookup: [UUID: LaunchyItem]
        if let cached = _itemLookup {
            lookup = cached
        } else {
            lookup = buildItemLookup()
            _itemLookup = lookup
        }
        return lookup[id]
    }

    /// Returns the folder with the given ID, or `nil` if no folder matches.
    func folder(by id: UUID) -> LaunchyFolder? {
        if let item = item(with: id), case .folder(let folder) = item {
            return folder
        }
        return nil
    }

    /// Returns the top-level index of the item in the flat items array.
    func indexOfItem(_ id: UUID) -> Int? { items.firstIndex(where: { $0.id == id }) }

    // MARK: - Debounced persistence

    /// Schedules a debounced save. Only the last call within the delay window persists to disk.
    func scheduleDebouncedSave() {
        saveDebouncerTask?.cancel()
        saveDebouncerTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(self?.saveDebouncerDelay ?? 0.5))
            guard !Task.isCancelled, let self else { return }
            self.dataStore.save(self.items)
        }
    }

    /// Persists the current item layout to disk immediately, cancelling any pending debounced save.
    func saveNow() {
        saveDebouncerTask?.cancel()
        saveDebouncerTask = nil
        dataStore.save(items)
    }

    // MARK: - Modifiers (create, delete, move)

    /// Creates a new folder from the given app IDs, inserting it at the position of the first
    /// selected app. Returns `nil` if fewer than two apps are provided.
    func createFolder(
        named name: String, color: IconColor = .blue, from ids: [UUID]
    ) -> LaunchyFolder? {
        var moved: [AppIcon] = []
        var remaining: [LaunchyItem] = []
        var firstSelectedIndex: Int? = nil

        for (index, item) in items.enumerated() {
            switch item {
            case .app(let app) where ids.contains(app.id):
                moved.append(app)
                if firstSelectedIndex == nil { firstSelectedIndex = index }
            case .app:
                remaining.append(item)
            case .folder(let folder):
                if !ids.contains(folder.id) {
                    remaining.append(item)
                }
            }
        }

        guard moved.count >= 2 else { return nil }

        let newFolder = LaunchyFolder(name: name, color: color, apps: moved)
        let insertIndex = min(firstSelectedIndex ?? remaining.count, remaining.count)
        remaining.insert(.folder(newFolder), at: insertIndex)
        items = remaining
        saveNow()
        presentedFolderID = newFolder.id
        selectedItemIDs.removeAll()
        return newFolder
    }

    func addSelectedApps(toFolder folderID: UUID) {
        let ids = Array(selectedItemIDs)
        addApps(ids, toFolder: folderID)
    }

    /// Moves the specified top-level apps into the target folder.
    func addApps(_ appIDs: [UUID], toFolder folderID: UUID) {
        guard !appIDs.isEmpty else { return }

        guard let folderIndex = items.firstIndex(where: { $0.id == folderID }),
            var folder = items[folderIndex].asFolder
        else { return }

        // Collect apps to move into the folder
        var appsToAdd: [AppIcon] = []
        var keptItems: [LaunchyItem] = []

        for item in items {
            if item.id == folderID {
                continue  // skip the folder itself, we'll re-insert it
            }
            if case .app(let app) = item, appIDs.contains(app.id) {
                appsToAdd.append(app)
            } else {
                keptItems.append(item)
            }
        }

        folder.apps.append(contentsOf: appsToAdd)

        // Re-insert folder at the correct (clamped) position
        let insertAt = min(folderIndex, keptItems.count)
        keptItems.insert(.folder(folder), at: insertAt)

        items = keptItems
        presentedFolderID = folderID
        selectedItemIDs.removeAll()
        saveNow()
    }

    func addApp(_ appID: UUID, toFolder folderID: UUID) {
        addApps([appID], toFolder: folderID)
    }

    /// Dissolves a folder, inserting its apps back into the grid at the folder's former position.
    func disbandFolder(_ folderID: UUID) {
        guard let index = items.firstIndex(where: { $0.id == folderID }),
            let folder = items[index].asFolder
        else { return }

        let apps = folder.apps.map { LaunchyItem.app($0) }
        items.remove(at: index)
        items.insert(contentsOf: apps, at: min(index, items.count))
        saveNow()
        presentedFolderID = nil
    }

    /// Removes an item from the grid. Folders are auto-disbanded (apps returned to grid);
    /// apps are moved to the recently-removed list for possible restoration.
    func deleteItem(_ id: UUID) {
        if let idx = items.firstIndex(where: { $0.id == id }) {
            // If it's a folder, auto-disband: move apps back to the grid
            // instead of silently destroying them.
            if let folder = items[idx].asFolder {
                let apps = folder.apps.map { LaunchyItem.app($0) }
                items.remove(at: idx)
                items.insert(contentsOf: apps, at: min(idx, items.count))
                if presentedFolderID == folder.id {
                    presentedFolderID = nil
                }
            } else if let app = items[idx].asApp {
                recentlyRemovedApps.append(app)
                items.remove(at: idx)
            } else {
                items.remove(at: idx)
            }
            saveNow()
            return
        }
        for i in items.indices {
            if case .folder(var folder) = items[i],
                let appIdx = folder.apps.firstIndex(where: { $0.id == id })
            {
                let removedApp = folder.apps.remove(at: appIdx)
                recentlyRemovedApps.append(removedApp)
                if folder.apps.isEmpty {
                    items.remove(at: i)
                } else {
                    items[i] = .folder(folder)
                }
                saveNow()
                return
            }
        }
    }

    /// Restores all recently removed apps back to the end of the grid.
    func restoreRemovedApps() {
        guard !recentlyRemovedApps.isEmpty else { return }
        let restored = recentlyRemovedApps.map { LaunchyItem.app($0) }
        items.append(contentsOf: restored)
        recentlyRemovedApps.removeAll()
        saveNow()
    }

    /// Deletes the persisted layout and reloads a fresh one from installed applications.
    func resetToDefaultLayout() {
        Task { [weak self] in
            guard let self else { return }
            let fresh = await dataStore.loadFresh()
            self.items = fresh
            self.currentPage = 0
            self.presentedFolderID = nil
            self.selectedItemIDs.removeAll()
            self.recentlyRemovedApps.removeAll()
            self.isEditing = false
            self.saveNow()
        }
    }

    /// Restores a single recently removed app back to the end of the grid.
    func restoreRemovedApp(_ id: UUID) {
        guard let idx = recentlyRemovedApps.firstIndex(where: { $0.id == id }) else { return }
        let app = recentlyRemovedApps.remove(at: idx)
        items.append(.app(app))
        saveNow()
    }

    /// Shifts a top-level item by the given offset (positive = rightward, negative = leftward).
    func shiftItem(_ id: UUID, by offset: Int) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        let newIndex = min(max(0, idx + offset), items.count - 1)
        if newIndex == idx { return }
        let item = items.remove(at: idx)
        items.insert(item, at: newIndex)
        saveNow()
    }

    /// Repositions a top-level item before the target item, or appends it if target is `nil`.
    /// Used during drag reordering; saves are debounced.
    func moveItem(_ id: UUID, before targetID: UUID?) {
        guard let from = items.firstIndex(where: { $0.id == id }) else { return }

        if let targetID {
            guard let to = items.firstIndex(where: { $0.id == targetID }) else { return }
            // Don't move if already in the right position
            if from == to || (from + 1 == to) { return }
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            let item = items.remove(at: from)
            if let targetID, let to = items.firstIndex(where: { $0.id == targetID }) {
                items.insert(item, at: to)
            } else {
                items.append(item)
            }
        }
        // Don't save on every drag movement - debounce instead
        scheduleDebouncedSave()
    }

    /// Presents the folder overlay for the given folder ID.
    func openFolder(with id: UUID) {
        presentedFolderID = id
    }

    /// Dismisses the currently presented folder overlay.
    func closeFolder() {
        presentedFolderID = nil
    }

    func showInFinder(_ item: LaunchyItem) {
        #if os(macOS)
            switch item {
            case .app(let icon):
                NSWorkspace.shared.activateFileViewerSelecting([icon.bundleURL])
            case .folder:
                break
            }
        #endif
    }

    /// Opens the given app using `NSWorkspace` and dismisses the launcher window.
    func launch(_ item: LaunchyItem) {
        #if os(macOS)
            switch item {
            case .app(let icon):
                isLaunchingApp = true
                launchingItemID = icon.id
                NSWorkspace.shared.openApplication(
                    at: icon.bundleURL,
                    configuration: NSWorkspace.OpenConfiguration()
                ) { [weak self] runningApp, error in
                    DispatchQueue.main.async {
                        if let error {
                            print(
                                "Launchy: Failed to launch \(icon.name): \(error.localizedDescription)"
                            )
                            self?.isLaunchingApp = false
                            let alert = NSAlert()
                            alert.messageText = "Unable to Launch \"\(icon.name)\""
                            alert.informativeText = error.localizedDescription
                            alert.alertStyle = .warning
                            alert.addButton(withTitle: "OK")
                            alert.runModal()
                            return
                        }

                        // Dismiss the launcher after launching, matching real Launchpad behavior.
                        // Restore presentation options so dock/menubar reappear immediately,
                        // then fade out the window and hide instead of terminating.
                        self?.dismissAfterLaunch()
                    }
                }
            case .folder:
                break
            }
        #endif
    }

    /// Resets transient launch state so the launcher can be re-shown cleanly.
    func resetLaunchState() {
        isLaunchingApp = false
        launchingItemID = nil
    }

    /// Hides the launcher window after a successful app launch, matching
    /// real Launchpad's dismiss-on-launch behavior. The app stays alive
    /// so it can be brought back via the dock icon or a global hotkey.
    private func dismissAfterLaunch() {
        #if os(macOS)
            NSApp.presentationOptions = []

            if let window = NSApp.windows.first(where: { $0.isVisible }) {
                NSAnimationContext.runAnimationGroup(
                    { context in
                        context.duration = 0.2
                        window.animator().alphaValue = 0
                    },
                    completionHandler: {
                        DispatchQueue.main.async {
                            window.orderOut(nil)
                            NSApp.hide(nil)
                        }
                    })
            } else {
                NSApp.hide(nil)
            }
        #endif
    }

    // MARK: - Folder contents manipulation

    func renameFolder(_ folderID: UUID, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let index = items.firstIndex(where: { $0.id == folderID }),
            var folder = items[index].asFolder
        else { return }
        folder.name = trimmed
        items[index] = .folder(folder)
        saveNow()
    }

    func updateFolderColor(_ folderID: UUID, to color: IconColor) {
        guard let index = items.firstIndex(where: { $0.id == folderID }),
            var folder = items[index].asFolder
        else { return }
        folder.color = color
        items[index] = .folder(folder)
        saveNow()
    }

    /// Shifts an app within a folder by the given offset.
    func shiftAppInFolder(folderID: UUID, appID: UUID, by offset: Int) {
        guard let idx = items.firstIndex(where: { $0.id == folderID }),
            var folder = items[idx].asFolder,
            let appIdx = folder.apps.firstIndex(where: { $0.id == appID })
        else { return }

        let newIdx = min(max(0, appIdx + offset), folder.apps.count - 1)
        if newIdx == appIdx { return }
        let a = folder.apps.remove(at: appIdx)
        folder.apps.insert(a, at: newIdx)
        items[idx] = .folder(folder)
        saveNow()
    }

    /// Repositions an app within a folder before the target app, or appends if target is `nil`.
    func moveAppWithinFolder(folderID: UUID, appID: UUID, before targetAppID: UUID?) {
        guard let idx = items.firstIndex(where: { $0.id == folderID }),
            var folder = items[idx].asFolder,
            let appIdx = folder.apps.firstIndex(where: { $0.id == appID })
        else { return }

        let app = folder.apps.remove(at: appIdx)
        if let target = targetAppID,
            let tIdx = folder.apps.firstIndex(where: { $0.id == target })
        {
            folder.apps.insert(app, at: tIdx)
        } else {
            folder.apps.append(app)
        }
        items[idx] = .folder(folder)
        scheduleDebouncedSave()
    }

    // MARK: - Drag & drop (forwarded to DragCoordinator)

    /// Starts a drag session for the given item. Forwarded to `DragCoordinator`.
    func beginDrag(for id: UUID, sourceFolder: UUID? = nil) {
        dragCoordinator.beginDrag(for: id, sourceFolder: sourceFolder)
    }

    /// Ends the current drag session. If `commit` is true, persists changes immediately.
    func endDrag(commit: Bool) {
        dragCoordinator.endDrag(commit: commit)
    }

    /// Extracts a dragged item from its source folder into the top-level grid.
    /// No-op if the item is already top-level or no drag is active.
    func extractDraggedItemIfNeeded() {
        dragCoordinator.extractDraggedItemIfNeeded()
    }

    /// Requests folder-creation stacking onto the target item after a short delay.
    /// Cancels any previous pending stacking request.
    func requestStacking(onto id: UUID) {
        dragCoordinator.requestStacking(onto: id)
    }

    /// Cancels any pending stacking timer.
    func cancelPendingStacking() {
        dragCoordinator.cancelPendingStacking()
    }

    /// Commits the pending stacking if it matches the given target ID.
    /// Returns whether stacking occurred.
    func commitPendingStackingIfNeeded(for id: UUID) -> Bool {
        dragCoordinator.commitPendingStackingIfNeeded(for: id)
    }

    /// Immediately stacks the currently dragged item onto the target
    /// (creating a folder or adding to an existing one).
    @discardableResult
    func stackDraggedItem(onto targetID: UUID) -> Bool {
        dragCoordinator.stackDraggedItem(onto: targetID)
    }
}
