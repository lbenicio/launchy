import Foundation

/// Optimized search index for fast app and folder searching
@MainActor
final class SearchIndex: ObservableObject {
    private var appNameIndex: [String: [UUID]] = [:]
    private var folderNameIndex: [String: [UUID]] = [:]
    private var appBundleIndex: [String: UUID] = [:]
    private var items: [UUID: LaunchyItem] = [:]

    /// Rebuilds the search index from the given items
    func rebuild(from items: [LaunchyItem]) {
        // Clear existing index
        appNameIndex.removeAll(keepingCapacity: true)
        folderNameIndex.removeAll(keepingCapacity: true)
        appBundleIndex.removeAll(keepingCapacity: true)
        self.items.removeAll(keepingCapacity: true)

        // Build new index
        for item in items {
            self.items[item.id] = item

            switch item {
            case .app(let app):
                // Index by name tokens
                let nameTokens = tokenize(app.name)
                for token in nameTokens {
                    appNameIndex[token, default: []].append(app.id)
                }

                // Index by bundle identifier
                appBundleIndex[app.bundleIdentifier.lowercased()] = app.id

            case .folder(let folder):
                // Index folder name
                let nameTokens = tokenize(folder.name)
                for token in nameTokens {
                    folderNameIndex[token, default: []].append(folder.id)
                }

                // Index apps within folder
                for app in folder.apps {
                    let appNameTokens = tokenize(app.name)
                    for token in appNameTokens {
                        appNameIndex[token, default: []].append(app.id)
                    }
                    appBundleIndex[app.bundleIdentifier.lowercased()] = app.id
                }

            case .widget(let widget):
                // Index widget name
                let nameTokens = tokenize(widget.name)
                for token in nameTokens {
                    appNameIndex[token, default: []].append(widget.id)
                }

                // Index by bundle identifier
                appBundleIndex[widget.bundleIdentifier.lowercased()] = widget.id
            }
        }
    }

    /// Performs a fast search using the pre-built index
    func search(query: String) -> [LaunchyItem] {
        let tokens = tokenize(query)
        guard !tokens.isEmpty else { return [] }

        var candidateIDs: Set<UUID> = []
        var scores: [UUID: Double] = [:]

        // Search through tokens
        for token in tokens {
            // Check app names
            if let appIDs = appNameIndex[token] {
                for id in appIDs {
                    candidateIDs.insert(id)
                    scores[id, default: 0.0] += 1.0
                }
            }

            // Check folder names
            if let folderIDs = folderNameIndex[token] {
                for id in folderIDs {
                    candidateIDs.insert(id)
                    scores[id, default: 0.0] += 1.0
                }
            }

            // Check bundle identifiers (exact match gets higher score)
            if let appID = appBundleIndex[token] {
                candidateIDs.insert(appID)
                scores[appID, default: 0.0] += 2.0
            }
        }

        // Convert to results and sort by score
        let results = candidateIDs.compactMap { id -> (LaunchyItem, Double)? in
            guard let item = items[id], let score = scores[id] else { return nil }
            return (item, score)
        }

        return results.sorted { $0.1 > $1.1 }.map { $0.0 }
    }

    /// Tokenizes a string for searching (splits on spaces, underscores, etc.)
    private func tokenize(_ string: String) -> [String] {
        let lowercase = string.lowercased()

        // Split on common separators
        let separators = CharacterSet(charactersIn: " _-.")
        let tokens = lowercase.components(separatedBy: separators)

        // Filter out empty tokens and very short ones
        return tokens.filter { $0.count >= 2 }
    }

    /// Updates the index with a single item change
    func updateItem(_ item: LaunchyItem) {
        // Remove old item if it exists
        if let oldItem = items[item.id] {
            removeFromIndex(oldItem)
        }

        // Add new item
        items[item.id] = item
        addToIndex(item)
    }

    /// Removes an item from the index
    func removeItem(_ id: UUID) {
        if let item = items[id] {
            removeFromIndex(item)
            items.removeValue(forKey: id)
        }
    }

    private func addToIndex(_ item: LaunchyItem) {
        switch item {
        case .app(let app):
            let nameTokens = tokenize(app.name)
            for token in nameTokens {
                appNameIndex[token, default: []].append(app.id)
            }
            appBundleIndex[app.bundleIdentifier.lowercased()] = app.id

        case .folder(let folder):
            let nameTokens = tokenize(folder.name)
            for token in nameTokens {
                folderNameIndex[token, default: []].append(folder.id)
            }
            for app in folder.apps {
                let appNameTokens = tokenize(app.name)
                for token in appNameTokens {
                    appNameIndex[token, default: []].append(app.id)
                }
                appBundleIndex[app.bundleIdentifier.lowercased()] = app.id
            }

        case .widget(let widget):
            let nameTokens = tokenize(widget.name)
            for token in nameTokens {
                appNameIndex[token, default: []].append(widget.id)
            }
            appBundleIndex[widget.bundleIdentifier.lowercased()] = widget.id
        }
    }

    private func removeFromIndex(_ item: LaunchyItem) {
        switch item {
        case .app(let app):
            let nameTokens = tokenize(app.name)
            for token in nameTokens {
                appNameIndex[token]?.removeAll { $0 == app.id }
                if appNameIndex[token]?.isEmpty == true {
                    appNameIndex.removeValue(forKey: token)
                }
            }
            appBundleIndex.removeValue(forKey: app.bundleIdentifier.lowercased())

        case .folder(let folder):
            let nameTokens = tokenize(folder.name)
            for token in nameTokens {
                folderNameIndex[token]?.removeAll { $0 == folder.id }
                if folderNameIndex[token]?.isEmpty == true {
                    folderNameIndex.removeValue(forKey: token)
                }
            }
            for app in folder.apps {
                let appNameTokens = tokenize(app.name)
                for token in appNameTokens {
                    appNameIndex[token]?.removeAll { $0 == app.id }
                    if appNameIndex[token]?.isEmpty == true {
                        appNameIndex.removeValue(forKey: token)
                    }
                }
                appBundleIndex.removeValue(forKey: app.bundleIdentifier.lowercased())
            }

        case .widget(let widget):
            let nameTokens = tokenize(widget.name)
            for token in nameTokens {
                appNameIndex[token]?.removeAll { $0 == widget.id }
                if appNameIndex[token]?.isEmpty == true {
                    appNameIndex.removeValue(forKey: token)
                }
            }
            appBundleIndex.removeValue(forKey: widget.bundleIdentifier.lowercased())
        }
    }
}
