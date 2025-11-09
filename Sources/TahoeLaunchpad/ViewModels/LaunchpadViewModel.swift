import Combine
import Foundation
import SwiftUI

@MainActor
final class LaunchpadViewModel: ObservableObject {
    @Published private(set) var items: [LaunchpadItem]
    @Published var isEditing: Bool = false
    @Published var currentPage: Int = 0
    @Published var presentedFolderID: UUID? = nil
    @Published private(set) var dragItemID: UUID? = nil
    @Published private(set) var dragSourceFolderID: UUID? = nil

    let dataStore: LaunchpadDataStore
    let settingsStore: GridSettingsStore

    private var cancellables: Set<AnyCancellable> = []

    init(dataStore: LaunchpadDataStore, settingsStore: GridSettingsStore) {
        self.dataStore = dataStore
        self.settingsStore = settingsStore
        items = dataStore.load()

        settingsStore.$settings
            .dropFirst()
            .sink { [weak self] _ in
                self?.ensureCurrentPageInBounds()
            }
            .store(in: &cancellables)

        ensureCurrentPageInBounds()
    }

    var settings: GridSettings { settingsStore.settings }

    var pagedItems: [[LaunchpadItem]] {
        let capacity = settings.pageCapacity
        guard capacity > 0 else { return [items] }
        let chunks = items.chunked(into: capacity)
        return chunks.isEmpty ? [[]] : chunks
    }

    func pagedItems(matching query: String) -> [[LaunchpadItem]] {
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
                dragItemID = nil
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
            persist()
        }
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
        ensureCurrentPageInBounds()
    }

    func openFolder(with id: UUID) {
        guard items.contains(where: { $0.id == id && $0.isFolder }) else { return }
        presentedFolderID = id
    }

    func closeFolder() {
        presentedFolderID = nil
    }

    func folder(by id: UUID) -> LaunchpadFolder? {
        guard let index = items.firstIndex(where: { $0.id == id }),
            case .folder(let folder) = items[index]
        else {
            return nil
        }
        return folder
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
    }

    func removeAppFromFolder(folderID: UUID, appID: UUID) {
        guard let folderIndex = items.firstIndex(where: { $0.id == folderID }),
            case .folder(var folder) = items[folderIndex]
        else { return }
        guard let removeIndex = folder.apps.firstIndex(where: { $0.id == appID }) else { return }

        let removedApp = folder.apps.remove(at: removeIndex)
        items[folderIndex] = .folder(folder)
        items.append(.app(removedApp))
        persist()
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
        persist()
    }

    func deleteItem(_ id: UUID) {
        guard isEditing, let index = items.firstIndex(where: { $0.id == id }) else { return }
        items.remove(at: index)
        ensureCurrentPageInBounds()
        persist()
    }

    func commitChanges() {
        persist()
    }

    func pageForItem(id: UUID) -> Int? {
        let capacity = settings.pageCapacity
        guard capacity > 0, let index = items.firstIndex(where: { $0.id == id }) else { return nil }
        return index / capacity
    }

    private func persist() {
        dataStore.save(items)
    }

    private func ensureCurrentPageInBounds() {
        let pages = pageCount
        if currentPage >= pages {
            currentPage = max(0, pages - 1)
        }
    }

    private func withAnimationIfPossible(_ action: () -> Void) {
        withAnimation(.easeInOut(duration: 0.25)) {
            action()
        }
    }
}
