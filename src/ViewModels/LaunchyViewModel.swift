import Combine
import Foundation
import SwiftUI

#if os(macOS)
    import AppKit
#endif

@MainActor
final class LaunchyViewModel: ObservableObject {
    @Published private(set) var items: [LaunchyItem]
    @Published var isEditing: Bool = false
    @Published var currentPage: Int = 0
    @Published var presentedFolderID: UUID? = nil
    @Published private(set) var dragItemID: UUID? = nil
    @Published private(set) var dragSourceFolderID: UUID? = nil
    @Published var selectedItemIDs: Set<UUID> = []
    @Published private(set) var isLaunchingApp: Bool = false
    @Published private(set) var isLayoutLoaded: Bool = false

    let dataStore: LaunchyDataStore
    let settingsStore: GridSettingsStore

    private var cancellables: Set<AnyCancellable> = []
    private var pendingStackWorkItem: DispatchWorkItem?
    private var pendingStackTargetID: UUID?
    private let stackingDelay: TimeInterval = 0.18
    private var launchSuppressionWorkItem: DispatchWorkItem?
    private var layoutDirty: Bool = false

    init(
        dataStore: LaunchyDataStore,
        settingsStore: GridSettingsStore,
        initialItems: [LaunchyItem]? = nil
    ) {
        self.dataStore = dataStore
        self.settingsStore = settingsStore
        if let initialItems {
            items = initialItems
        } else {
            items = dataStore.load()
        }

        let storedPage = settingsStore.settings.lastWindowedPage ?? 0
        currentPage = min(max(storedPage, 0), max(pageCount - 1, 0))

        settingsStore.$settings
            .dropFirst()
            .sink { [weak self] _ in
                self?.ensureCurrentPageInBounds(shouldPersist: false)
            }
            .store(in: &cancellables)

        ensureCurrentPageInBounds()
        persistLastVisitedPageIfNeeded(currentPage)
        isLayoutLoaded = true
    }

    var settings: GridSettings { settingsStore.settings }

    var pagedItems: [[LaunchyItem]] {
        let capacity = settings.pageCapacity
        guard capacity > 0 else { return [items] }
        let chunks = items.chunked(into: capacity)
        return chunks.isEmpty ? [[]] : chunks
    }

    func pagedItems(matching query: String) -> [[LaunchyItem]] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return pagedItems }

        let filtered = items.filter { item in
            switch item {
            case .app(let icon):
                return icon.name.localizedCaseInsensitiveContains(normalized)
            case .folder(let folder):
                if folder.name.localizedCaseInsensitiveContains(normalized) {
                    return true
                }
                return folder.apps.contains { $0.name.localizedCaseInsensitiveContains(normalized) }
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
        if selectedItemIDs.contains(id) { selectedItemIDs.remove(id) } else { selectedItemIDs.insert(id) }
    }

    func isItemSelected(_ id: UUID) -> Bool { selectedItemIDs.contains(id) }

    func clearSelection() {
        selectedItemIDs.removeAll()
    }

    // MARK: - Item accessors
    func item(with id: UUID) -> LaunchyItem? {
        if let top = items.first(where: { $0.id == id }) { return top }
        // search inside folders for apps
        for item in items {
            if case .folder(let folder) = item {
                if let appIcon = folder.apps.first(where: { $0.id == id }) {
                    return .app(appIcon)
                }
            }
        }
        return nil
    }

    func folder(by id: UUID) -> LaunchyFolder? {
        for item in items {
            if case .folder(let folder) = item, folder.id == id { return folder }
        }
        return nil
    }

    func indexOfItem(_ id: UUID) -> Int? { items.firstIndex(where: { $0.id == id }) }

    // MARK: - Modifiers (create, delete, move)
    func createFolder(named name: String, from ids: [UUID]) -> LaunchyFolder? {
        var moved: [AppIcon] = []
        var remaining: [LaunchyItem] = []

        for item in items {
            switch item {
            case .app(let app) where ids.contains(app.id):
                moved.append(app)
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
        // insert at first selected index or end
        let insertIndex = max(0, remaining.count)
        remaining.insert(.folder(newFolder), at: insertIndex)
        items = remaining
        dataStore.save(items)
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
        guard let folderIndex = items.firstIndex(where: { item in
            switch item {
            case .folder(let f): return f.id == folderID
            default: return false
            }
        }) else { return }
        var folder = items[folderIndex].asFolder!
        var newItems: [LaunchyItem] = []
        for item in items where item.id != folderID {
            switch item {
            case .app(let app) where appIDs.contains(app.id):
                folder.apps.append(app)
            default:
                newItems.append(item)
            }
        }
        items = newItems
        // re-insert folder
        var updatedItems = items
        updatedItems.insert(.folder(folder), at: min(folderIndex, updatedItems.count))
        items = updatedItems
        presentedFolderID = folderID
        selectedItemIDs.removeAll()
        dataStore.save(items)
    }

    func addApp(_ appID: UUID, toFolder folderID: UUID) {
        addApps([appID], toFolder: folderID)
    }

    func disbandFolder(_ folderID: UUID) {
        guard let index = items.firstIndex(where: { item in
            switch item {
            case .folder(let f): return f.id == folderID
            default: return false
            }
        }) else { return }
        let folder = items[index].asFolder!
        let apps = folder.apps.map { LaunchyItem.app($0) }
        items.remove(at: index)
        items.insert(contentsOf: apps, at: index)
        dataStore.save(items)
        presentedFolderID = nil
    }

    func deleteItem(_ id: UUID) {
        if let idx = items.firstIndex(where: { $0.id == id }) {
            items.remove(at: idx)
            dataStore.save(items)
            return
        }
        // remove app from folders
        for i in items.indices {
            if case .folder(var folder) = items[i], let appIdx = folder.apps.firstIndex(where: { $0.id == id }) {
                folder.apps.remove(at: appIdx)
                items[i] = .folder(folder)
                dataStore.save(items)
                return
            }
        }
    }

    func shiftItem(_ id: UUID, by offset: Int) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        let newIndex = min(max(0, idx + offset), items.count - 1)
        if newIndex == idx { return }
        let item = items.remove(at: idx)
        items.insert(item, at: newIndex)
        dataStore.save(items)
    }

    func moveItem(_ id: UUID, before targetID: UUID?) {
        guard let from = items.firstIndex(where: { $0.id == id }) else { return }
        let item = items.remove(at: from)
        if let targetID, let to = items.firstIndex(where: { $0.id == targetID }) {
            items.insert(item, at: to)
        } else {
            // Move to end
            items.append(item)
        }
        dataStore.save(items)
    }

    func openFolder(with id: UUID) {
        presentedFolderID = id
    }

    func closeFolder() {
        presentedFolderID = nil
    }

    func launch(_ item: LaunchyItem) {
        // placeholder: for now we only track launching, primarily used in UI
        isLaunchingApp = true
        // emulate small suppression interval
        launchSuppressionWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.isLaunchingApp = false
        }
        launchSuppressionWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    // Helpers for folder contents manipulation
    func shiftAppInFolder(folderID: UUID, appID: UUID, by offset: Int) {
        guard let idx = items.firstIndex(where: { item in
            switch item {
            case .folder(let f): return f.id == folderID
            default: return false
            }
        }) else { return }
        var folder = items[idx].asFolder!
        guard let appIdx = folder.apps.firstIndex(where: { $0.id == appID }) else { return }
        let newIdx = min(max(0, appIdx + offset), folder.apps.count - 1)
        if newIdx == appIdx { return }
        let a = folder.apps.remove(at: appIdx)
        folder.apps.insert(a, at: newIdx)
        items[idx] = .folder(folder)
        dataStore.save(items)
    }

    func moveAppWithinFolder(folderID: UUID, appID: UUID, before targetAppID: UUID?) {
        guard let idx = items.firstIndex(where: { item in
            switch item {
            case .folder(let f): return f.id == folderID
            default: return false
            }
        }) else { return }
        var folder = items[idx].asFolder!
        guard let appIdx = folder.apps.firstIndex(where: { $0.id == appID }) else { return }
        let app = folder.apps.remove(at: appIdx)
        if let target = targetAppID, let tIdx = folder.apps.firstIndex(where: { $0.id == target }) {
            folder.apps.insert(app, at: tIdx)
        } else {
            folder.apps.append(app)
        }
        items[idx] = .folder(folder)
        dataStore.save(items)
    }

    // MARK: - Drag & drop
    func beginDrag(for id: UUID, sourceFolder: UUID? = nil) {
        dragItemID = id
        dragSourceFolderID = sourceFolder
    }

    func endDrag(commit: Bool) {
        if commit {
            dataStore.save(items)
        }
        dragItemID = nil
        dragSourceFolderID = nil
        cancelPendingStacking()
    }

    func extractDraggedItemIfNeeded() {}

    func requestStacking(onto id: UUID) {
        cancelPendingStacking()
        pendingStackTargetID = id
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
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
        guard let pending = pendingStackTargetID, pending == id, dragItemID != nil else { return false }
        cancelPendingStacking()
        return stackDraggedItem(onto: id)
    }

    func stackDraggedItem(onto id: UUID) -> Bool {
        guard let dragged = dragItemID else { return false }
        // if dragging into a folder, add app(s) into that folder and remove source
        guard let targetIndex = items.firstIndex(where: { item in
            switch item {
            case .folder(let f): return f.id == id
            default: return false
            }
        }) else { return false }
        var folder = items[targetIndex].asFolder!
        // remove dragged from either top-level or from a folder
          if let sourceFolderID = dragSourceFolderID,
              let sourceIndex = items.firstIndex(where: { item in
                    switch item {
                    case .folder(let f): return f.id == sourceFolderID
                    default: return false
                    }
              }), var sourceFolder = items[sourceIndex].asFolder, let appIdx = sourceFolder.apps.firstIndex(where: { $0.id == dragged }) {
               let app = sourceFolder.apps.remove(at: appIdx)
               items[sourceIndex] = .folder(sourceFolder)
               folder.apps.append(app)
               items[targetIndex] = .folder(folder)
               dataStore.save(items)
               return true
        }

        if let topIndex = items.firstIndex(where: { item in switch item { case .app(let a): return a.id == dragged default: return false } }), case .app(let app) = items[topIndex] {
            items.remove(at: topIndex)
            folder.apps.append(app)
            items[targetIndex] = .folder(folder)
            dataStore.save(items)
            return true
        }

        return false
    }


    // ... rest remains same with LaunchyItem / LaunchyFolder replacements already made earlier
}
