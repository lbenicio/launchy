import Combine
import Foundation
import SwiftUI

#if os(macOS)
    import AppKit
#endif

@MainActor
final class LaunchyViewModel: ObservableObject {
    @Published private(set) var items: [LaunchyItem] {
        didSet { invalidateCaches() }
    }
    @Published var isEditing: Bool = false
    @Published var currentPage: Int = 0
    @Published var presentedFolderID: UUID? = nil
    @Published private(set) var dragItemID: UUID? = nil
    @Published private(set) var dragSourceFolderID: UUID? = nil
    @Published var selectedItemIDs: Set<UUID> = []
    @Published var isLaunchingApp: Bool = false
    @Published private(set) var launchingItemID: UUID? = nil
    @Published private(set) var isLayoutLoaded: Bool = false
    /// Apps removed during this session that can be restored without restarting.
    @Published private(set) var recentlyRemovedApps: [AppIcon] = []

    let dataStore: LaunchyDataStore
    let settingsStore: GridSettingsStore

    private var cancellables: Set<AnyCancellable> = []
    private var pendingStackWorkItem: DispatchWorkItem?
    private var pendingStackTargetID: UUID?
    private let stackingDelay: TimeInterval = 0.35
    private var launchSuppressionWorkItem: DispatchWorkItem?
    private var saveDebouncerWorkItem: DispatchWorkItem?
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
    }

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

    func folder(by id: UUID) -> LaunchyFolder? {
        if let item = item(with: id), case .folder(let folder) = item {
            return folder
        }
        return nil
    }

    func indexOfItem(_ id: UUID) -> Int? { items.firstIndex(where: { $0.id == id }) }

    // MARK: - Debounced persistence

    /// Schedule a debounced save. Only the last call within the delay window persists.
    private func scheduleDebouncedSave() {
        saveDebouncerWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.dataStore.save(self.items)
        }
        saveDebouncerWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + saveDebouncerDelay, execute: work)
    }

    /// Save immediately (used for user-initiated actions like folder creation, deletion, etc.)
    private func saveNow() {
        saveDebouncerWorkItem?.cancel()
        saveDebouncerWorkItem = nil
        dataStore.save(items)
    }

    // MARK: - Modifiers (create, delete, move)

    func createFolder(named name: String, from ids: [UUID]) -> LaunchyFolder? {
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

        let newFolder = LaunchyFolder(name: name, apps: moved)
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

    /// Restores a single recently removed app back to the end of the grid.
    func restoreRemovedApp(_ id: UUID) {
        guard let idx = recentlyRemovedApps.firstIndex(where: { $0.id == id }) else { return }
        let app = recentlyRemovedApps.remove(at: idx)
        items.append(.app(app))
        saveNow()
    }

    func shiftItem(_ id: UUID, by offset: Int) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        let newIndex = min(max(0, idx + offset), items.count - 1)
        if newIndex == idx { return }
        let item = items.remove(at: idx)
        items.insert(item, at: newIndex)
        saveNow()
    }

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

    func openFolder(with id: UUID) {
        presentedFolderID = id
    }

    func closeFolder() {
        presentedFolderID = nil
    }

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

    // MARK: - Drag & drop

    func beginDrag(for id: UUID, sourceFolder: UUID? = nil) {
        dragItemID = id
        dragSourceFolderID = sourceFolder
    }

    func endDrag(commit: Bool) {
        if commit {
            // Flush any pending debounced save immediately
            saveDebouncerWorkItem?.cancel()
            saveDebouncerWorkItem = nil
            dataStore.save(items)
        }
        dragItemID = nil
        dragSourceFolderID = nil
        cancelPendingStacking()
    }

    /// When an item is dragged from inside a folder onto the main grid,
    /// extract it from the source folder and insert it as a top-level item.
    func extractDraggedItemIfNeeded() {
        guard let dragID = dragItemID, let sourceFolderID = dragSourceFolderID else { return }

        // Already extracted to top level?
        if items.contains(where: { $0.id == dragID }) { return }

        guard let folderIndex = items.firstIndex(where: { $0.id == sourceFolderID }),
            var folder = items[folderIndex].asFolder,
            let appIndex = folder.apps.firstIndex(where: { $0.id == dragID })
        else { return }

        let app = folder.apps.remove(at: appIndex)

        // If the folder has only one app left, disband it
        if folder.apps.count <= 1 {
            let remainingApps = folder.apps.map { LaunchyItem.app($0) }
            items.remove(at: folderIndex)
            items.insert(contentsOf: remainingApps, at: min(folderIndex, items.count))
            items.insert(.app(app), at: min(folderIndex, items.count))
        } else {
            items[folderIndex] = .folder(folder)
            items.insert(.app(app), at: min(folderIndex + 1, items.count))
        }

        // Clear the source folder reference since item is now top-level
        dragSourceFolderID = nil
        scheduleDebouncedSave()
    }

    func requestStacking(onto id: UUID) {
        guard id != pendingStackTargetID else { return }
        cancelPendingStacking()
        pendingStackTargetID = id
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if self.dragItemID != nil {
                _ = self.stackDraggedItem(onto: id)
            }
        }
        pendingStackWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + stackingDelay, execute: work)
    }

    func cancelPendingStacking() {
        pendingStackWorkItem?.cancel()
        pendingStackWorkItem = nil
        pendingStackTargetID = nil
    }

    func commitPendingStackingIfNeeded(for id: UUID) -> Bool {
        guard let pending = pendingStackTargetID, pending == id, dragItemID != nil else {
            return false
        }
        cancelPendingStacking()
        return stackDraggedItem(onto: id)
    }

    @discardableResult
    func stackDraggedItem(onto targetID: UUID) -> Bool {
        guard let draggedID = dragItemID else { return false }

        // Case 1: Target is a folder — add dragged app into the folder
        if let targetIndex = items.firstIndex(where: { $0.id == targetID }),
            var folder = items[targetIndex].asFolder
        {
            // Source is inside a folder
            if let sourceFolderID = dragSourceFolderID,
                let sourceIndex = items.firstIndex(where: { $0.id == sourceFolderID }),
                var sourceFolder = items[sourceIndex].asFolder,
                let appIdx = sourceFolder.apps.firstIndex(where: { $0.id == draggedID })
            {
                let app = sourceFolder.apps.remove(at: appIdx)
                folder.apps.append(app)

                // Update both folders carefully (indices may be same if source == target)
                if sourceIndex == targetIndex {
                    // Same folder, just update once
                    items[targetIndex] = .folder(folder)
                } else {
                    // Update the one with the higher index first to avoid shift
                    if sourceIndex > targetIndex {
                        if sourceFolder.apps.isEmpty {
                            items.remove(at: sourceIndex)
                        } else {
                            items[sourceIndex] = .folder(sourceFolder)
                        }
                        items[targetIndex] = .folder(folder)
                    } else {
                        items[targetIndex] = .folder(folder)
                        if sourceFolder.apps.isEmpty {
                            items.remove(at: sourceIndex)
                        } else {
                            items[sourceIndex] = .folder(sourceFolder)
                        }
                    }
                }
                saveNow()
                return true
            }

            // Source is a top-level app
            if let topIndex = items.firstIndex(where: { $0.id == draggedID }),
                case .app(let app) = items[topIndex]
            {
                // Remove the dragged app first, then adjust target index
                items.remove(at: topIndex)
                let adjustedTargetIndex = topIndex < targetIndex ? targetIndex - 1 : targetIndex
                folder.apps.append(app)
                items[adjustedTargetIndex] = .folder(folder)
                saveNow()
                return true
            }

            return false
        }

        // Case 2: Target is an app — create a new folder from both apps
        if let targetIndex = items.firstIndex(where: { $0.id == targetID }),
            case .app(let targetApp) = items[targetIndex]
        {
            var draggedApp: AppIcon?

            // Get the dragged app from a source folder
            if let sourceFolderID = dragSourceFolderID,
                let sourceIndex = items.firstIndex(where: { $0.id == sourceFolderID }),
                var sourceFolder = items[sourceIndex].asFolder,
                let appIdx = sourceFolder.apps.firstIndex(where: { $0.id == draggedID })
            {
                draggedApp = sourceFolder.apps.remove(at: appIdx)
                if sourceFolder.apps.isEmpty {
                    items.remove(at: sourceIndex)
                } else {
                    items[sourceIndex] = .folder(sourceFolder)
                }
            }
            // Or get the dragged app from top-level
            else if let topIndex = items.firstIndex(where: { $0.id == draggedID }),
                case .app(let app) = items[topIndex]
            {
                draggedApp = app
                items.remove(at: topIndex)
            }

            guard let draggedApp else { return false }

            // Find the (possibly shifted) target index again
            guard let newTargetIndex = items.firstIndex(where: { $0.id == targetID }) else {
                // Target was removed somehow, just add dragged back
                items.append(.app(draggedApp))
                saveNow()
                return false
            }

            // Create a new folder with both apps
            let folderName = targetApp.name
            let newFolder = LaunchyFolder(
                name: folderName,
                apps: [targetApp, draggedApp]
            )
            items[newTargetIndex] = .folder(newFolder)
            saveNow()
            presentedFolderID = newFolder.id
            return true
        }

        return false
    }
}
