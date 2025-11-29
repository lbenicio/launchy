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

    // ... rest remains same with LaunchyItem / LaunchyFolder replacements already made earlier
}
