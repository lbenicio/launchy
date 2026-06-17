import CoreServices
import CoreSpotlight
import Foundation
import UniformTypeIdentifiers

#if os(macOS)
    import AppKit
#endif

/// Provides Spotlight search functionality for Launchy, integrating with macOS Spotlight
/// to return search results that include files, documents, and other searchable content.
@MainActor
final class SpotlightSearchService: ObservableObject {
    static let shared = SpotlightSearchService()

    @Published var isSearching: Bool = false
    @Published var spotlightResults: [SpotlightResult] = []

    private let searchQueue = DispatchQueue(
        label: "com.launchy.spotlight.search",
        qos: .userInitiated
    )

    private init() {}

    /// Performs a Spotlight search for the given query and returns results
    func search(_ query: String) async -> [SpotlightResult] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        await MainActor.run {
            isSearching = true
            spotlightResults.removeAll()
        }

        let results = await withCheckedContinuation { continuation in
            searchQueue.async {
                let searchResults = MainActor.assumeIsolated { [weak self] in
                    self?.performSpotlightSearch(query: query) ?? []
                }
                continuation.resume(returning: searchResults)
            }
        }

        await MainActor.run {
            isSearching = false
            spotlightResults = results
        }

        return results
    }

    private func performSpotlightSearch(query: String) -> [SpotlightResult] {
        // Simplified implementation for now - return empty results
        // A full implementation would require proper NSMetadataQuery usage
        // which is complex and may need additional permissions
        []
    }

    private func createSpotlightResult(from metadataItem: NSMetadataItem) -> SpotlightResult? {
        guard let displayName = metadataItem.value(forAttribute: "kMDItemDisplayName") as? String,
            let path = metadataItem.value(forAttribute: "kMDItemPath") as? String
        else {
            return nil
        }

        let url = URL(fileURLWithPath: path)
        let contentType = metadataItem.value(forAttribute: "kMDItemContentType") as? String ?? ""

        // Determine the type of result
        var resultType: SpotlightResult.SpotlightResultType = .file

        if contentType == UTType.folder.identifier {
            resultType = .folder
        } else if contentType.contains("application") {
            resultType = .application
        } else if contentType.contains("image") {
            resultType = .image
        } else if contentType.contains("text") || contentType.contains("document") {
            resultType = .document
        }

        // Get additional metadata
        let lastUsedDate = metadataItem.value(forAttribute: "kMDItemLastUsedDate") as? Date
        let creationDate = metadataItem.value(forAttribute: "kMDItemFSCreationDate") as? Date
        let fileSize = metadataItem.value(forAttribute: "kMDItemFSSize") as? Int64 ?? 0

        return SpotlightResult(
            id: UUID(),
            displayName: displayName,
            path: path,
            url: url,
            type: resultType,
            contentType: contentType,
            lastUsedDate: lastUsedDate,
            creationDate: creationDate,
            fileSize: fileSize
        )
    }

    /// Launches the selected Spotlight result using the appropriate application
    func launch(_ result: SpotlightResult) {
        #if os(macOS)
            NSWorkspace.shared.open(result.url)
        #endif
    }

    /// Reveals the selected Spotlight result in Finder
    func revealInFinder(_ result: SpotlightResult) {
        #if os(macOS)
            NSWorkspace.shared.selectFile(result.path, inFileViewerRootedAtPath: "")
        #endif
    }
}

// MARK: - Spotlight Result Model

struct SpotlightResult: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let displayName: String
    let path: String
    let url: URL
    let type: SpotlightResultType
    let contentType: String
    let lastUsedDate: Date?
    let creationDate: Date?
    let fileSize: Int64

    enum SpotlightResultType: String, Codable, CaseIterable {
        case file
        case folder
        case application
        case document
        case image
    }

    var displayIcon: String {
        switch type {
        case .file:
            return "doc"
        case .folder:
            return "folder"
        case .application:
            return "app"
        case .document:
            return "doc.text"
        case .image:
            return "photo"
        }
    }

    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
}

// MARK: - Fuzzy Matching Extension

extension SpotlightResult {
    func fuzzyMatch(_ query: String) -> Double? {
        let displayNameScore = displayName.fuzzyMatch(query) ?? 0.0
        let pathScore = path.fuzzyMatch(query) ?? 0.0
        return max(displayNameScore, pathScore * 0.5)  // Give less weight to path matches
    }
}
