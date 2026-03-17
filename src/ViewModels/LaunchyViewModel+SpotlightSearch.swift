import Foundation

// MARK: - Spotlight Search Integration

extension LaunchyViewModel {

    /// Performs a combined search of apps and Spotlight results
    func performSpotlightSearch(for query: String) async {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            spotlightResults.removeAll()
            isSearchingSpotlight = false
            return
        }

        isSearchingSpotlight = true

        Task {
            let results = await spotlightService.search(normalized)
            await MainActor.run {
                self.spotlightResults = results
                self.isSearchingSpotlight = false
            }
        }
    }

    /// Cancels any ongoing Spotlight search
    func cancelSpotlightSearch() {
        isSearchingSpotlight = false
        spotlightResults.removeAll()
    }

    /// Launches a Spotlight result
    func launchSpotlightResult(_ result: SpotlightResult) {
        spotlightService.launch(result)
    }

    /// Reveals a Spotlight result in Finder
    func revealSpotlightResult(_ result: SpotlightResult) {
        spotlightService.revealInFinder(result)
    }

    /// Gets combined search results (apps + Spotlight)
    func getCombinedSearchResults(for query: String) -> [SearchResult] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return [] }

        var results: [SearchResult] = []

        // Add app/folder results
        for item in items {
            switch item {
            case .app(let icon):
                if let score = icon.name.fuzzyMatch(normalized) {
                    results.append(SearchResult(launchyItem: item, score: score))
                }
            case .folder(let folder):
                if let folderScore = folder.name.fuzzyMatch(normalized) {
                    results.append(SearchResult(launchyItem: item, score: folderScore))
                }
                // Also add individual apps from folders
                for app in folder.apps {
                    if let appScore = app.name.fuzzyMatch(normalized) {
                        results.append(SearchResult(launchyItem: .app(app), score: appScore * 0.8))  // Lower score for items in folders
                    }
                }
            case .widget(let widget):
                if let widgetScore = widget.name.fuzzyMatch(normalized) {
                    results.append(SearchResult(launchyItem: item, score: widgetScore * 0.7))  // Lower score for widgets
                }
            }
        }

        // Add Spotlight results
        for spotlightResult in spotlightResults {
            if let score = spotlightResult.fuzzyMatch(normalized) {
                results.append(SearchResult(spotlightResult: spotlightResult, score: score * 0.6))  // Lower score for Spotlight results
            }
        }

        // Sort by score and return
        results.sort { $0.score > $1.score }
        return results
    }
}

// MARK: - Unified Search Result

struct SearchResult: Identifiable, Sendable {
    let id = UUID()
    let launchyItem: LaunchyItem?
    let spotlightResult: SpotlightResult?
    let score: Double

    init(launchyItem: LaunchyItem, score: Double) {
        self.launchyItem = launchyItem
        self.spotlightResult = nil
        self.score = score
    }

    init(spotlightResult: SpotlightResult, score: Double) {
        self.launchyItem = nil
        self.spotlightResult = spotlightResult
        self.score = score
    }

    var displayName: String {
        launchyItem?.displayName ?? spotlightResult?.displayName ?? ""
    }

    var isSpotlightResult: Bool {
        spotlightResult != nil
    }

    var isLaunchyItem: Bool {
        launchyItem != nil
    }
}
