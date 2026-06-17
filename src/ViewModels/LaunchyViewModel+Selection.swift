import Foundation

// MARK: - Selection & Editing

extension LaunchyViewModel {

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
}
