import Foundation
import SwiftUI

// MARK: - Item mutation (create, delete, move, sort)

extension LaunchyViewModel {

    /// Creates a new folder from the given app IDs, inserting it at the position of the first
    /// selected app. Returns `nil` if fewer than two apps are provided.
    func createFolder(
        named name: String,
        color: IconColor = .blue,
        from ids: [UUID]
    ) -> LaunchyFolder? {
        recordForUndo()
        var moved: [AppIcon] = []
        var remaining: [LaunchyItem] = []
        var firstSelectedIndex: Int? = nil

        // Collect indices to remove first to avoid index shifting issues
        var indicesToRemove: [Int] = []

        for (index, item) in items.enumerated() {
            switch item {
            case .app(let app) where ids.contains(app.id):
                moved.append(app)
                indicesToRemove.append(index)
                if firstSelectedIndex == nil { firstSelectedIndex = index }
            case .folder(let folder) where ids.contains(folder.id):
                moved.append(contentsOf: folder.apps)
                indicesToRemove.append(index)
            case .widget(let widget) where ids.contains(widget.id):
                // Widgets can be moved but don't have apps to extract
                indicesToRemove.append(index)
            default:
                remaining.append(item)
            }
        }

        // Remove items in reverse order to maintain correct indices
        for index in indicesToRemove.sorted(by: >) {
            items.remove(at: index)
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
        addApps(Array(selectedItemIDs), toFolder: folderID)
    }

    /// Moves the specified top-level apps into the target folder.
    func addApps(_ appIDs: [UUID], toFolder folderID: UUID) {
        guard !appIDs.isEmpty else { return }
        recordForUndo()

        guard let folderIndex = items.firstIndex(where: { $0.id == folderID }),
            var folder = items[folderIndex].asFolder
        else { return }

        var appsToAdd: [AppIcon] = []
        var keptItems: [LaunchyItem] = []

        for item in items {
            if item.id == folderID { continue }
            if case .app(let app) = item, appIDs.contains(app.id) {
                appsToAdd.append(app)
            } else {
                keptItems.append(item)
            }
        }

        folder.apps.append(contentsOf: appsToAdd)

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
        recordForUndo()
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
        recordForUndo()
        if let idx = items.firstIndex(where: { $0.id == id }) {
            if let folder = items[idx].asFolder {
                let apps = folder.apps.map { LaunchyItem.app($0) }
                items.remove(at: idx)
                items.insert(contentsOf: apps, at: min(idx, items.count))
                if presentedFolderID == folder.id { presentedFolderID = nil }
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
                    if presentedFolderID == folder.id { presentedFolderID = nil }
                } else if folder.apps.count == 1 {
                    // Disband the folder when only one app remains — matches real Launchpad behaviour
                    items[i] = .app(folder.apps[0])
                    if presentedFolderID == folder.id { presentedFolderID = nil }
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
        recordForUndo()
        let restored = recentlyRemovedApps.map { LaunchyItem.app($0) }
        items.append(contentsOf: restored)
        recentlyRemovedApps.removeAll()
        saveNow()
    }

    /// Deletes the persisted layout and reloads a fresh one from installed applications.
    func resetToDefaultLayout() {
        recordForUndo()
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

    /// Sorts all top-level items alphabetically by display name.
    func sortAlphabetically() {
        recordForUndo()
        items.sort {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
        saveNow()
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
        recordForUndo()
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
            if from == to || (from + 1 == to) { return }
        }

        withAnimation(.spring(response: 0.25, dampingFraction: 0.72)) {
            let item = items.remove(at: from)
            if let targetID, let to = items.firstIndex(where: { $0.id == targetID }) {
                items.insert(item, at: to)
            } else {
                items.append(item)
            }
        }
        scheduleDebouncedSave()
    }
}
