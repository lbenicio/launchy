import Foundation

// MARK: - Item accessors

extension LaunchyViewModel {

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
}
