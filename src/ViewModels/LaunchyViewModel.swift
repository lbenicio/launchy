import Combine
import Foundation
import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
    import AppKit
#endif

@MainActor
final class LaunchyViewModel: ObservableObject {
    @Published var items: [LaunchyItem] {
        didSet { invalidateCaches() }
    }
    @Published var isEditing: Bool = false
    @Published var currentPage: Int = 0
    @Published var presentedFolderID: UUID? = nil
    /// Screen-coordinate X of the folder icon that was tapped to open the overlay.
    /// Used to position the triangular notch on `FolderContentView`. Nil → centered.
    @Published var folderOpenScreenX: CGFloat? = nil
    @Published var selectedItemIDs: Set<UUID> = []
    @Published var isLaunchingApp: Bool = false
    @Published var launchingItemID: UUID? = nil
    @Published var isLayoutLoaded: Bool = false
    @Published var recentlyAddedBundleIDs: Set<String> = []
    /// Apps removed during this session that can be restored without restarting.
    @Published var recentlyRemovedApps: [AppIcon] = []

    let dataStore: LaunchyDataStore
    let settingsStore: GridSettingsStore

    private(set) var dragCoordinator: DragCoordinator!
    let undoManager = LayoutUndoManager()

    var cancellables: Set<AnyCancellable> = []
    var saveDebouncerTask: Task<Void, Never>?
    let saveDebouncerDelay: TimeInterval = 0.5

    #if os(macOS)
        var applicationWatcher: ApplicationWatcher?
    #endif

    // MARK: - Caches

    var _cachedPagedItems: [[LaunchyItem]]?
    var _cachedPageCapacity: Int?
    var _itemLookup: [UUID: LaunchyItem]?

    private func invalidateCaches() {
        _cachedPagedItems = nil
        _itemLookup = nil
    }

    // Internal — called from mutation extensions that need to record undo state.
    func recordForUndo() {
        undoManager.recordSnapshot(items)
    }

    // MARK: - Forwarded drag state

    var dragItemID: UUID? { dragCoordinator.dragItemID }
    var dragSourceFolderID: UUID? { dragCoordinator.dragSourceFolderID }
    var pendingStackTargetID: UUID? { dragCoordinator.pendingStackTargetID }
    var pendingSpringloadFolderID: UUID? { dragCoordinator.pendingSpringloadFolderID }

    var settings: GridSettings { settingsStore.settings }

    // MARK: - Paged items (cached)

    var pagedItems: [[LaunchyItem]] {
        let capacity = settings.pageCapacity
        if let cached = _cachedPagedItems, _cachedPageCapacity == capacity {
            return cached
        }
        let result: [[LaunchyItem]]
        if capacity <= 0 {
            result = [items]
        } else {
            let chunks = items.chunked(into: capacity)
            result = chunks.isEmpty ? [[]] : chunks
        }
        _cachedPagedItems = result
        _cachedPageCapacity = capacity
        return result
    }

    func pagedItems(matching query: String) -> [[LaunchyItem]] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return pagedItems }

        struct ScoredItem: Sendable {
            let item: LaunchyItem
            let score: Double
        }

        var scored: [ScoredItem] = []

        for item in items {
            switch item {
            case .app(let icon):
                if let score = icon.name.fuzzyMatch(normalized) {
                    scored.append(ScoredItem(item: item, score: score))
                }
            case .folder(let folder):
                if let folderScore = folder.name.fuzzyMatch(normalized) {
                    for app in folder.apps {
                        scored.append(ScoredItem(item: .app(app), score: folderScore))
                    }
                } else {
                    for app in folder.apps {
                        if let appScore = app.name.fuzzyMatch(normalized) {
                            scored.append(ScoredItem(item: .app(app), score: appScore))
                        }
                    }
                }
            }
        }

        scored.sort { $0.score > $1.score }
        let filtered = scored.map(\.item)

        let capacity = settings.pageCapacity
        guard capacity > 0 else { return [filtered] }
        let chunks = filtered.chunked(into: capacity)
        return chunks.isEmpty ? [[]] : chunks
    }

    var pageCount: Int { pagedItems.count }

    // MARK: - Init

    init(
        dataStore: LaunchyDataStore,
        settingsStore: GridSettingsStore,
        initialItems: [LaunchyItem]? = nil
    ) {
        self.dataStore = dataStore
        self.settingsStore = settingsStore
        if let initialItems {
            items = initialItems
            isLayoutLoaded = true
        } else {
            items = []
            isLayoutLoaded = false
        }

        let storedPage = settingsStore.settings.lastWindowedPage ?? 0
        currentPage = min(max(storedPage, 0), max(pageCount - 1, 0))

        settingsStore.$settings
            .dropFirst()
            .sink { [weak self] _ in
                self?._cachedPagedItems = nil
                self?.ensureCurrentPageInBounds(shouldPersist: false)
                #if os(macOS)
                    self?.setupApplicationWatcher()
                #endif
            }
            .store(in: &cancellables)

        // Initialise the coordinator and wire change propagation before any
        // async work starts, so methods called from the load Task can safely
        // access dragCoordinator without risking a nil force-unwrap.
        dragCoordinator = DragCoordinator(viewModel: self)
        dragCoordinator.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        undoManager.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        if initialItems != nil {
            ensureCurrentPageInBounds()
            persistLastVisitedPageIfNeeded(currentPage)
        } else {
            Task { [weak self] in
                guard let self else { return }
                let loaded = await dataStore.loadAsync()
                self.items = loaded

                let appURLs = loaded.flatMap { item -> [URL] in
                    switch item {
                    case .app(let icon): return [icon.bundleURL]
                    case .folder(let folder): return folder.apps.map(\.bundleURL)
                    }
                }
                ApplicationIconProvider.shared.preWarmCache(for: appURLs)

                self.ensureCurrentPageInBounds()
                self.persistLastVisitedPageIfNeeded(self.currentPage)
                self.isLayoutLoaded = true
                self.updateRecentlyAdded()
                self.setupICloudSync()
                #if os(macOS)
                    self.setupApplicationWatcher()
                #endif
            }
        }
    }
}
