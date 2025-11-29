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

    func toggleEditing() {
        withAnimationIfPossible {
            isEditing.toggle()
            if !isEditing {
                cancelPendingStacking()
                dragItemID = nil
                clearSelection()
                persistIfNeeded()
            }
        }
    }

    func beginDrag(for itemID: UUID, sourceFolder: UUID? = nil) {
        guard isEditing else { return }
        dragItemID = itemID
        dragSourceFolderID = sourceFolder
    }

    func endDrag(commit: Bool) {
        if commit {
            persistIfNeeded()
        }
        cancelPendingStacking()
        dragItemID = nil
        dragSourceFolderID = nil
    }

    func extractDraggedItemIfNeeded() {
        guard let folderID = dragSourceFolderID, let dragItemID else { return }
        dragSourceFolderID = nil
        removeAppFromFolder(folderID: folderID, appID: dragItemID)
    }

    func moveItem(_ draggedID: UUID, before targetID: UUID?) {
        if let targetID, draggedID == targetID { return }
        guard let currentIndex = items.firstIndex(where: { $0.id == draggedID }) else { return }

        var updatedItems = items
        let element = updatedItems.remove(at: currentIndex)

        if let targetID, let targetIndex = updatedItems.firstIndex(where: { $0.id == targetID }) {
            updatedItems.insert(element, at: targetIndex)
        } else {
            updatedItems.append(element)
        }

        items = updatedItems
        markLayoutDirty()
        ensureCurrentPageInBounds()
        pruneSelection()
    }

    func shiftItem(_ id: UUID, by offset: Int) {
        guard let currentIndex = items.firstIndex(where: { $0.id == id }) else { return }
        let targetIndex = min(max(currentIndex + offset, 0), max(items.count - 1, 0))
        guard targetIndex != currentIndex else { return }

        var updatedItems = items
        let element = updatedItems.remove(at: currentIndex)
        updatedItems.insert(element, at: targetIndex)
        items = updatedItems
        markLayoutDirty()
        ensureCurrentPageInBounds()
        pruneSelection()
        persistIfNeeded()
    }

    func toggleSelection(for id: UUID) {
        var updated = selectedItemIDs
        if updated.contains(id) {
            updated.remove(id)
        } else {
            updated.insert(id)
        }
        if updated != selectedItemIDs {
            selectedItemIDs = updated
        }
    }

    func clearSelection() {
        if !selectedItemIDs.isEmpty {
            selectedItemIDs = []
        }
    }

    func isItemSelected(_ id: UUID) -> Bool {
        selectedItemIDs.contains(id)
    }

    var hasSelectedApps: Bool {
        selectedItemIDs.contains { id in
            if let item = item(with: id), case .app = item {
                return true
            }
            return false
        }
    }

    func openFolder(with id: UUID) {
        guard items.contains(where: { $0.id == id && $0.isFolder }) else { return }
        presentedFolderID = id
    }

    func closeFolder() {
        presentedFolderID = nil
    }

    func folder(by id: UUID) -> LaunchyFolder? {
        guard let index = items.firstIndex(where: { $0.id == id }),
            case .folder(let folder) = items[index]
        else {
            return nil
        }
        return folder
    }

    func item(with id: UUID) -> LaunchyItem? {
        items.first { $0.id == id }
    }

    func indexOfItem(_ id: UUID) -> Int? {
        items.firstIndex { $0.id == id }
    }

    func moveAppWithinFolder(folderID: UUID, appID: UUID, before targetAppID: UUID?) {
        guard let folderIndex = items.firstIndex(where: { $0.id == folderID }),
            case .folder(var folder) = items[folderIndex]
        else { return }
        guard let appIndex = folder.apps.firstIndex(where: { $0.id == appID }) else { return }

        var apps = folder.apps
        let app = apps.remove(at: appIndex)
        if let targetAppID, let targetIndex = apps.firstIndex(where: { $0.id == targetAppID }) {
            apps.insert(app, at: targetIndex)
        } else {
            apps.append(app)
        }

        folder.apps = apps
        items[folderIndex] = .folder(folder)
        markLayoutDirty()
        pruneSelection()
        persistIfNeeded()
    }

    func removeAppFromFolder(folderID: UUID, appID: UUID) {
        guard let folderIndex = items.firstIndex(where: { $0.id == folderID }),
            case .folder(var folder) = items[folderIndex]
        else { return }
        guard let removeIndex = folder.apps.firstIndex(where: { $0.id == appID }) else { return }

        let removedApp = folder.apps.remove(at: removeIndex)
        items[folderIndex] = .folder(folder)
        items.append(.app(removedApp))
        markLayoutDirty()
        pruneSelection()
        persistIfNeeded()
    }

    func disbandFolder(_ folderID: UUID) {
        guard let folderIndex = items.firstIndex(where: { $0.id == folderID }),
            case .folder(let folder) = items[folderIndex]
        else { return }

        var updatedItems = items
        updatedItems.remove(at: folderIndex)
        let flattenedApps = folder.apps.map { LaunchyItem.app($0) }
        updatedItems.insert(contentsOf: flattenedApps, at: folderIndex)

        items = updatedItems
        if presentedFolderID == folderID {
            presentedFolderID = nil
        }

        markLayoutDirty()
        ensureCurrentPageInBounds()
        pruneSelection()
        persistIfNeeded()
    }

    @discardableResult
    func stackDraggedItem(onto targetID: UUID) -> Bool {
        guard let draggedID = dragItemID,
            draggedID != targetID,
            let draggedIndex = items.firstIndex(where: { $0.id == draggedID }),
            let targetIndex = items.firstIndex(where: { $0.id == targetID })
        else {
            return false
        }

        guard case .app(let draggedApp) = items[draggedIndex],
            case .app(let targetApp) = items[targetIndex]
        else {
            return false
        }

        var updatedItems = items
        let upperIndex = max(draggedIndex, targetIndex)
        let lowerIndex = min(draggedIndex, targetIndex)
        // Remove dragged and target items in order to insert the new folder in their place.
        updatedItems.remove(at: upperIndex)
        updatedItems.remove(at: lowerIndex)

        let folderName = defaultFolderName(from: targetApp.name)
        var folder = LaunchyFolder(name: folderName, apps: [])
        folder.apps.append(targetApp)
        folder.apps.append(draggedApp)

        updatedItems.insert(.folder(folder), at: lowerIndex)

        items = updatedItems
        presentedFolderID = folder.id
        dragItemID = nil
        dragSourceFolderID = nil
        ensureCurrentPageInBounds()
        pruneSelection()
        markLayoutDirty()
        persistIfNeeded()
        return true
    }

    func addApp(_ appID: UUID, toFolder folderID: UUID) {
        guard let folderIndex = items.firstIndex(where: { $0.id == folderID }) else { return }
        guard let appIndex = items.firstIndex(where: { $0.id == appID }) else { return }

        var updatedItems = items
        let removedItem = updatedItems.remove(at: appIndex)
        guard case .app(let icon) = removedItem else { return }

        let targetIndex = appIndex < folderIndex ? max(folderIndex - 1, 0) : folderIndex
        guard case .folder(var folder) = updatedItems[targetIndex] else { return }

        guard !folder.apps.contains(where: { $0.id == appID }) else { return }
        folder.apps.append(icon)
        updatedItems[targetIndex] = .folder(folder)

        items = updatedItems
        presentedFolderID = folderID
        markLayoutDirty()
        pruneSelection()
        persistIfNeeded()
    }

    func addSelectedApps(toFolder folderID: UUID) {
        guard hasSelectedApps else { return }
        var updatedItems = items

        guard let initialFolderIndex = updatedItems.firstIndex(where: { $0.id == folderID }),
            case .folder = updatedItems[initialFolderIndex]
        else {
            return
        }

        var extracted: [(index: Int, app: AppIcon)] = []
        for id in selectedItemIDs {
            guard let currentIndex = updatedItems.firstIndex(where: { $0.id == id }) else {
                continue
            }
            if case .app(let icon) = updatedItems[currentIndex] {
                extracted.append((currentIndex, icon))
            }
        }

        guard !extracted.isEmpty else { return }

        for entry in extracted.sorted(by: { $0.index > $1.index }) {
            updatedItems.remove(at: entry.index)
        }

        guard let folderIndex = updatedItems.firstIndex(where: { $0.id == folderID }),
            case .folder(var folder) = updatedItems[folderIndex]
        else {
            return
        }

        let orderedApps = extracted.sorted(by: { $0.index < $1.index }).map { $0.app }
        let idsToRemove = Set(orderedApps.map { $0.id })

        folder.apps.append(contentsOf: orderedApps)
        updatedItems[folderIndex] = .folder(folder)

        items = updatedItems
        if !idsToRemove.isEmpty {
            var updated = selectedItemIDs
            updated.subtract(idsToRemove)
            selectedItemIDs = updated
        }
        markLayoutDirty()
        pruneSelection()
        persistIfNeeded()
        presentedFolderID = folderID
    }

    func deleteItem(_ id: UUID) {
        guard isEditing, let index = items.firstIndex(where: { $0.id == id }) else { return }
        items.remove(at: index)
        ensureCurrentPageInBounds()
        if selectedItemIDs.contains(id) {
            var updated = selectedItemIDs
            updated.remove(id)
            selectedItemIDs = updated
        }
        markLayoutDirty()
        pruneSelection()
        persistIfNeeded()
    }

    @discardableResult
    func createFolder(named name: String, from selection: [UUID]) -> LaunchyFolder? {
        let uniqueIDs = Array(Set(selection))
        guard !uniqueIDs.isEmpty else { return nil }

        var updatedItems = items
        var extractedApps: [(index: Int, app: AppIcon)] = []

        for id in uniqueIDs {
            guard let index = updatedItems.firstIndex(where: { $0.id == id }) else { continue }
            if case .app(let icon) = updatedItems[index] {
                extractedApps.append((index, icon))
            }
        }

        guard !extractedApps.isEmpty else { return nil }

        // Remove in descending order to keep remaining indices valid.
        for entry in extractedApps.sorted(by: { $0.index > $1.index }) {
            updatedItems.remove(at: entry.index)
        }

        let sortedApps = extractedApps.sorted(by: { $0.index < $1.index }).map { $0.app }
        let folderName: String
        if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            folderName = name
        } else if let firstApp = sortedApps.first {
            folderName = defaultFolderName(from: firstApp.name)
        } else {
            folderName = defaultFolderName(from: "")
        }

        let folder = LaunchyFolder(name: folderName, apps: sortedApps)
        let insertionIndex = min(
            extractedApps.map { $0.index }.min() ?? updatedItems.count, updatedItems.count)
        updatedItems.insert(.folder(folder), at: insertionIndex)

        items = updatedItems
        presentedFolderID = folder.id
        selectedItemIDs = []
        ensureCurrentPageInBounds()
        markLayoutDirty()
        pruneSelection()
        persistIfNeeded()
        return folder
    }

    func shiftAppInFolder(folderID: UUID, appID: UUID, by offset: Int) {
        guard let folderIndex = items.firstIndex(where: { $0.id == folderID }),
            case .folder(var folder) = items[folderIndex]
        else { return }

        guard let currentIndex = folder.apps.firstIndex(where: { $0.id == appID }) else { return }
        let targetIndex = min(max(currentIndex + offset, 0), max(folder.apps.count - 1, 0))
        guard targetIndex != currentIndex else { return }

        var apps = folder.apps
        let app = apps.remove(at: currentIndex)
        apps.insert(app, at: targetIndex)
        folder.apps = apps
        items[folderIndex] = .folder(folder)
        markLayoutDirty()
        pruneSelection()
        persistIfNeeded()
    }

    func commitChanges() {
        persistIfNeeded()
    }

    func pageForItem(id: UUID) -> Int? {
        let capacity = settings.pageCapacity
        guard capacity > 0, let index = items.firstIndex(where: { $0.id == id }) else { return nil }
        return index / capacity
    }

    func selectPage(_ index: Int, totalPages: Int) {
        let maxIndex = max(totalPages - 1, 0)
        let clamped = min(max(index, 0), maxIndex)
        if currentPage != clamped {
            cancelPendingStacking()
            currentPage = clamped
        }
        persistLastVisitedPageIfNeeded(clamped)
    }

    func goToPreviousPage(totalPages: Int) {
        selectPage(currentPage - 1, totalPages: totalPages)
    }

    func goToNextPage(totalPages: Int) {
        selectPage(currentPage + 1, totalPages: totalPages)
    }

    func requestStacking(onto targetID: UUID) {
        guard let draggedID = dragItemID,
            draggedID != targetID,
            canStack(draggedID: draggedID, onto: targetID)
        else {
            cancelPendingStacking()
            return
        }

        if pendingStackTargetID == targetID {
            return
        }

        cancelPendingStacking()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.cancelPendingStacking()
            _ = self.stackDraggedItem(onto: targetID)
        }

        pendingStackTargetID = targetID
        pendingStackWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + stackingDelay, execute: workItem)
    }

    func cancelPendingStacking() {
        pendingStackWorkItem?.cancel()
        pendingStackWorkItem = nil
        pendingStackTargetID = nil
    }

    func commitPendingStackingIfNeeded(for targetID: UUID) -> Bool {
        guard pendingStackTargetID == targetID else { return false }
        cancelPendingStacking()
        return stackDraggedItem(onto: targetID)
    }

    private func markLayoutDirty() {
        layoutDirty = true
    }

    private func persistIfNeeded() {
        guard layoutDirty else { return }
        persist()
    }

    private func persist() {
        dataStore.save(items)
        layoutDirty = false
    }

    private func defaultFolderName(from sourceName: String) -> String {
        let trimmed = sourceName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "Folder"
        }
        return "\(trimmed) Folder"
    }

    private func canStack(draggedID: UUID, onto targetID: UUID) -> Bool {
        guard let draggedIndex = items.firstIndex(where: { $0.id == draggedID }),
            let targetIndex = items.firstIndex(where: { $0.id == targetID })
        else {
            return false
        }

        if case .app = items[draggedIndex], case .app = items[targetIndex] {
            return true
        }

        return false
    }

    private func ensureCurrentPageInBounds(shouldPersist: Bool = true) {
        let pages = pageCount
        if currentPage >= pages {
            currentPage = max(0, pages - 1)
        }
        if shouldPersist {
            persistLastVisitedPageIfNeeded(currentPage)
        }
    }

    private func pruneSelection() {
        var validIDs = Set(items.map { $0.id })
        for item in items {
            if case .folder(let folder) = item {
                validIDs.formUnion(folder.apps.map { $0.id })
            }
        }

        selectedItemIDs = selectedItemIDs.intersection(validIDs)
    }

    private func persistLastVisitedPageIfNeeded(_ index: Int) {
        guard index >= 0 else { return }
        if settingsStore.settings.lastWindowedPage != index {
            settingsStore.update(lastWindowedPage: index)
        }
    }

    func beginAppLaunchSuppressionWindow() {
        launchSuppressionWorkItem?.cancel()
        isLaunchingApp = true

        let workItem = DispatchWorkItem { [weak self] in
            self?.isLaunchingApp = false
        }
        launchSuppressionWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: workItem)
    }

    func cancelAppLaunchSuppression() {
        launchSuppressionWorkItem?.cancel()
        launchSuppressionWorkItem = nil
        isLaunchingApp = false
    }

    func launch(_ item: LaunchyItem) {
        guard case .app(let app) = item else { return }

        closeFolder()

        #if os(macOS)
            beginAppLaunchSuppressionWindow()

            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true

            NSWorkspace.shared.openApplication(at: app.bundleURL, configuration: configuration) {
                [weak self] _, error in
                guard let self else { return }

                if let error {
                    print(
                        "LaunchpadViewModel: Failed to launch \(app.name) => \(error.localizedDescription)"
                    )
                    DispatchQueue.main.async {
                        self.cancelAppLaunchSuppression()
                    }
                    return
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    NSApplication.shared.terminate(nil)
                }
            }
        #endif
    }

    private func withAnimationIfPossible(_ action: () -> Void) {
        withAnimation(.easeInOut(duration: 0.25)) {
            action()
        }
    }
}
