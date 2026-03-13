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
    @Published var selectedItemIDs: Set<UUID> = []
    @Published var isLaunchingApp: Bool = false
    @Published private(set) var launchingItemID: UUID? = nil
    @Published private(set) var isLayoutLoaded: Bool = false
    @Published private(set) var recentlyAddedBundleIDs: Set<String> = []
    /// Apps removed during this session that can be restored without restarting.
    @Published private(set) var recentlyRemovedApps: [AppIcon] = []

    let dataStore: LaunchyDataStore
    let settingsStore: GridSettingsStore

    private(set) var dragCoordinator: DragCoordinator!
    let undoManager = LayoutUndoManager()

    private var cancellables: Set<AnyCancellable> = []
    private var saveDebouncerTask: Task<Void, Never>?
    private let saveDebouncerDelay: TimeInterval = 0.5

    #if os(macOS)
        private var applicationWatcher: ApplicationWatcher?
    #endif

    // MARK: - Caches

    private var _cachedPagedItems: [[LaunchyItem]]?
    private var _cachedPageCapacity: Int?
    private var _itemLookup: [UUID: LaunchyItem]?

    private func invalidateCaches() {
        _cachedPagedItems = nil
        _itemLookup = nil
    }

    /// Records the current layout for undo before performing a mutation.
    private func recordForUndo() {
        undoManager.recordSnapshot(items)
    }

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

        if initialItems != nil {
            ensureCurrentPageInBounds()
            persistLastVisitedPageIfNeeded(currentPage)
        } else {
            Task { [weak self] in
                guard let self else { return }
                let loaded = await dataStore.loadAsync()
                self.items = loaded

                // Pre-warm the icon cache in the background
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

        dragCoordinator = DragCoordinator(viewModel: self)
        dragCoordinator.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        undoManager.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    // MARK: - Forwarding drag state

    var dragItemID: UUID? { dragCoordinator.dragItemID }
    var dragSourceFolderID: UUID? { dragCoordinator.dragSourceFolderID }
    var pendingStackTargetID: UUID? { dragCoordinator.pendingStackTargetID }

    var settings: GridSettings { settingsStore.settings }

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
                    // Folder name matches — include all apps as standalone tiles
                    for app in folder.apps {
                        scored.append(ScoredItem(item: .app(app), score: folderScore))
                    }
                } else {
                    // Check individual apps inside the folder
                    for app in folder.apps {
                        if let appScore = app.name.fuzzyMatch(normalized) {
                            scored.append(ScoredItem(item: .app(app), score: appScore))
                        }
                    }
                }
            }
        }

        // Sort by relevance score descending (higher = better match first)
        scored.sort { $0.score > $1.score }
        let filtered = scored.map(\.item)

        let capacity = settings.pageCapacity
        guard capacity > 0 else { return [filtered] }
        let chunks = filtered.chunked(into: capacity)
        return chunks.isEmpty ? [[]] : chunks
    }

    var pageCount: Int {
        pagedItems.count
    }

    // MARK: - Paging helpers

    func selectPage(_ index: Int, totalPages: Int) {
        let clamped = min(max(index, 0), max(totalPages - 1, 0))
        guard clamped != currentPage else { return }
        currentPage = clamped
        persistLastVisitedPageIfNeeded(clamped)
    }

    func goToPreviousPage(totalPages: Int) {
        selectPage(max(currentPage - 1, 0), totalPages: totalPages)
    }

    func goToNextPage(totalPages: Int) {
        selectPage(min(currentPage + 1, totalPages - 1), totalPages: totalPages)
    }

    private func persistLastVisitedPageIfNeeded(_ page: Int) {
        guard !settings.useFullScreenLayout else { return }
        settingsStore.update(lastWindowedPage: page)
    }

    private func ensureCurrentPageInBounds(shouldPersist: Bool = true) {
        let maxIndex = max(pageCount - 1, 0)
        if currentPage > maxIndex {
            currentPage = maxIndex
            if shouldPersist { persistLastVisitedPageIfNeeded(currentPage) }
        }
    }

    // MARK: - Selection & Editing

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

    // MARK: - Item accessors

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

    // MARK: - Debounced persistence

    /// Schedules a debounced save. Only the last call within the delay window persists to disk.
    func scheduleDebouncedSave() {
        saveDebouncerTask?.cancel()
        saveDebouncerTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(self?.saveDebouncerDelay ?? 0.5))
            guard !Task.isCancelled, let self else { return }
            self.dataStore.save(self.items)
        }
    }

    /// Persists the current item layout to disk immediately, cancelling any pending debounced save.
    func saveNow() {
        saveDebouncerTask?.cancel()
        saveDebouncerTask = nil
        dataStore.save(items)
        uploadToICloudIfNeeded()
    }

    // MARK: - Modifiers (create, delete, move)

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

        for (index, item) in items.enumerated() {
            switch item {
            case .app(let app) where ids.contains(app.id):
                moved.append(app)
                if firstSelectedIndex == nil { firstSelectedIndex = index }
            case .app:
                remaining.append(item)
            case .folder(let folder):
                if !ids.contains(folder.id) {
                    remaining.append(item)
                }
            }
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
        let ids = Array(selectedItemIDs)
        addApps(ids, toFolder: folderID)
    }

    /// Moves the specified top-level apps into the target folder.
    func addApps(_ appIDs: [UUID], toFolder folderID: UUID) {
        guard !appIDs.isEmpty else { return }
        recordForUndo()

        guard let folderIndex = items.firstIndex(where: { $0.id == folderID }),
            var folder = items[folderIndex].asFolder
        else { return }

        // Collect apps to move into the folder
        var appsToAdd: [AppIcon] = []
        var keptItems: [LaunchyItem] = []

        for item in items {
            if item.id == folderID {
                continue  // skip the folder itself, we'll re-insert it
            }
            if case .app(let app) = item, appIDs.contains(app.id) {
                appsToAdd.append(app)
            } else {
                keptItems.append(item)
            }
        }

        folder.apps.append(contentsOf: appsToAdd)

        // Re-insert folder at the correct (clamped) position
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
            // If it's a folder, auto-disband: move apps back to the grid
            // instead of silently destroying them.
            if let folder = items[idx].asFolder {
                let apps = folder.apps.map { LaunchyItem.app($0) }
                items.remove(at: idx)
                items.insert(contentsOf: apps, at: min(idx, items.count))
                if presentedFolderID == folder.id {
                    presentedFolderID = nil
                }
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
    /// Apps inside folders remain in their current folder order.
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
            // Don't move if already in the right position
            if from == to || (from + 1 == to) { return }
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            let item = items.remove(at: from)
            if let targetID, let to = items.firstIndex(where: { $0.id == targetID }) {
                items.insert(item, at: to)
            } else {
                items.append(item)
            }
        }
        // Don't save on every drag movement - debounce instead
        scheduleDebouncedSave()
    }

    /// Presents the folder overlay for the given folder ID.
    func openFolder(with id: UUID) {
        presentedFolderID = id
    }

    /// Dismisses the currently presented folder overlay.
    func closeFolder() {
        presentedFolderID = nil
    }

    func showInFinder(_ item: LaunchyItem) {
        #if os(macOS)
            switch item {
            case .app(let icon):
                NSWorkspace.shared.activateFileViewerSelecting([icon.bundleURL])
            case .folder:
                break
            }
        #endif
    }

    /// Opens the given app using `NSWorkspace` and dismisses the launcher window.
    func launch(_ item: LaunchyItem) {
        #if os(macOS)
            switch item {
            case .app(let icon):
                isLaunchingApp = true
                launchingItemID = icon.id
                MenuBarService.shared.recordLaunch(
                    name: icon.name,
                    bundleIdentifier: icon.bundleIdentifier,
                    bundleURL: icon.bundleURL
                )
                clearRecentlyAdded(icon.bundleIdentifier)
                NSWorkspace.shared.openApplication(
                    at: icon.bundleURL,
                    configuration: NSWorkspace.OpenConfiguration()
                ) { [weak self] runningApp, error in
                    DispatchQueue.main.async {
                        if let error {
                            print(
                                "Launchy: Failed to launch \(icon.name): \(error.localizedDescription)"
                            )
                            self?.isLaunchingApp = false
                            let alert = NSAlert()
                            alert.messageText = "Unable to Launch \"\(icon.name)\""
                            alert.informativeText = error.localizedDescription
                            alert.alertStyle = .warning
                            alert.addButton(withTitle: "OK")
                            alert.runModal()
                            return
                        }

                        // Dismiss the launcher after launching, matching real Launchpad behavior.
                        // Restore presentation options so dock/menubar reappear immediately,
                        // then fade out the window and hide instead of terminating.
                        self?.dismissAfterLaunch()
                    }
                }
            case .folder:
                break
            }
        #endif
    }

    /// Resets transient launch state so the launcher can be re-shown cleanly.
    func resetLaunchState() {
        isLaunchingApp = false
        launchingItemID = nil
    }

    // MARK: - Recently Added Tracking

    /// Marks an app as no longer "recently added" (e.g., after first launch).
    func clearRecentlyAdded(_ bundleIdentifier: String) {
        recentlyAddedBundleIDs.remove(bundleIdentifier)
    }

    /// Compares the current set of bundle IDs against the previously stored
    /// set and marks any new ones as "recently added".
    private func updateRecentlyAdded() {
        let key = "dev.lbenicio.launchy.known-bundle-ids"
        let storedIDs = Set(
            UserDefaults.standard.stringArray(forKey: key) ?? []
        )
        let currentIDs = Set(allBundleIdentifiers())
        let newIDs = currentIDs.subtracting(storedIDs)
        if !storedIDs.isEmpty {
            recentlyAddedBundleIDs = newIDs
        }
        UserDefaults.standard.set(Array(currentIDs), forKey: key)
    }

    /// Returns every bundle identifier present in the current layout.
    private func allBundleIdentifiers() -> [String] {
        items.flatMap { item -> [String] in
            switch item {
            case .app(let icon):
                return [icon.bundleIdentifier]
            case .folder(let folder):
                return folder.apps.map(\.bundleIdentifier)
            }
        }
    }

    // MARK: - iCloud Sync

    private func setupICloudSync() {
        guard settingsStore.settings.iCloudSyncEnabled else { return }
        let syncService = ICloudSyncService.shared
        syncService.onRemoteChange = { [weak self] remoteItems in
            guard let self, self.settingsStore.settings.iCloudSyncEnabled else { return }
            // Only replace if remote is different
            if remoteItems != self.items {
                self.items = remoteItems
                self.ensureCurrentPageInBounds()
            }
        }
        syncService.startObserving()
    }

    /// Uploads the current layout to iCloud if sync is enabled.
    private func uploadToICloudIfNeeded() {
        guard settingsStore.settings.iCloudSyncEnabled else { return }
        ICloudSyncService.shared.upload(items: items)
    }

    /// Dismisses the launcher after an app has been successfully launched.
    /// Posts the `dismissLauncher` notification to use the same dismiss path
    /// as Escape/background-tap (zoom-out animation → fade → hide).
    private func dismissAfterLaunch() {
        #if os(macOS)
            NotificationCenter.default.post(name: .dismissLauncher, object: nil)
        #endif
    }

    // MARK: - Application Watcher

    #if os(macOS)
        /// Starts (or restarts) the filesystem watcher for installed-app directories.
        /// Called once after initial load and again whenever settings change so that
        /// custom search directories are respected immediately.
        private func setupApplicationWatcher() {
            var directories: [URL] = [
                URL(fileURLWithPath: "/Applications"),
                URL(fileURLWithPath: "/System/Applications"),
                FileManager.default.homeDirectoryForCurrentUser
                    .appendingPathComponent("Applications"),
            ]
            for path in settings.customSearchDirectories where !path.isEmpty {
                let expanded = NSString(string: path).expandingTildeInPath
                directories.append(URL(fileURLWithPath: expanded))
            }

            applicationWatcher?.stop()
            applicationWatcher = ApplicationWatcher(directories: directories) { [weak self] in
                Task { @MainActor [weak self] in
                    await self?.reconcileInstalledApps()
                }
            }
            applicationWatcher?.start()
        }

        /// Reconciles the current layout against the currently installed applications.
        /// Newly installed apps are appended; uninstalled apps are removed.
        /// The user's custom arrangement is preserved.
        private func reconcileInstalledApps() async {
            let reconciled = await dataStore.loadAsync()
            guard reconciled != items else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                items = reconciled
            }
            ensureCurrentPageInBounds()
            updateRecentlyAdded()
        }
    #endif

    // MARK: - Folder contents manipulation

    func renameFolder(_ folderID: UUID, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let index = items.firstIndex(where: { $0.id == folderID }),
            var folder = items[index].asFolder
        else { return }
        folder.name = trimmed
        items[index] = .folder(folder)
        saveNow()
    }

    func updateFolderColor(_ folderID: UUID, to color: IconColor) {
        guard let index = items.firstIndex(where: { $0.id == folderID }),
            var folder = items[index].asFolder
        else { return }
        folder.color = color
        items[index] = .folder(folder)
        saveNow()
    }

    /// Shifts an app within a folder by the given offset.
    func shiftAppInFolder(folderID: UUID, appID: UUID, by offset: Int) {
        guard let idx = items.firstIndex(where: { $0.id == folderID }),
            var folder = items[idx].asFolder,
            let appIdx = folder.apps.firstIndex(where: { $0.id == appID })
        else { return }

        let newIdx = min(max(0, appIdx + offset), folder.apps.count - 1)
        if newIdx == appIdx { return }
        let a = folder.apps.remove(at: appIdx)
        folder.apps.insert(a, at: newIdx)
        items[idx] = .folder(folder)
        saveNow()
    }

    /// Repositions an app within a folder before the target app, or appends if target is `nil`.
    func moveAppWithinFolder(folderID: UUID, appID: UUID, before targetAppID: UUID?) {
        guard let idx = items.firstIndex(where: { $0.id == folderID }),
            var folder = items[idx].asFolder,
            let appIdx = folder.apps.firstIndex(where: { $0.id == appID })
        else { return }

        let app = folder.apps.remove(at: appIdx)
        if let target = targetAppID,
            let tIdx = folder.apps.firstIndex(where: { $0.id == target })
        {
            folder.apps.insert(app, at: tIdx)
        } else {
            folder.apps.append(app)
        }
        items[idx] = .folder(folder)
        scheduleDebouncedSave()
    }

    // MARK: - Finder drop (external .app bundles)

    /// Accepts a file URL pointing to an `.app` bundle and adds it to the grid if not already present.
    func addAppFromFinder(url: URL) -> Bool {
        #if os(macOS)
            guard url.pathExtension == "app" else { return false }
            guard let bundle = Bundle(url: url),
                let bundleID = bundle.bundleIdentifier
            else { return false }

            // Check if already present
            let allBundleIDs = items.flatMap { item -> [String] in
                switch item {
                case .app(let icon): return [icon.bundleIdentifier]
                case .folder(let folder): return folder.apps.map(\.bundleIdentifier)
                }
            }
            guard !allBundleIDs.contains(bundleID) else { return false }

            let name =
                bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                ?? url.deletingPathExtension().lastPathComponent

            let app = AppIcon(name: name, bundleIdentifier: bundleID, bundleURL: url)
            items.append(.app(app))
            saveNow()
            return true
        #else
            return false
        #endif
    }

    /// Accepts multiple file URLs from a Finder drop, returns how many were added.
    func addAppsFromFinder(urls: [URL]) -> Int {
        var count = 0
        for url in urls {
            if addAppFromFinder(url: url) {
                count += 1
            }
        }
        return count
    }

    // MARK: - Undo / Redo

    func undo() {
        if let previous = undoManager.undo(current: items) {
            items = previous
            saveNow()
        }
    }

    func redo() {
        if let next = undoManager.redo(current: items) {
            items = next
            saveNow()
        }
    }

    // MARK: - Drag & drop (forwarded to DragCoordinator)

    /// Starts a drag session for the given item. Forwarded to `DragCoordinator`.
    /// Records an undo snapshot once at drag start so that the entire reorder
    /// operation can be undone in a single Cmd+Z.
    func beginDrag(for id: UUID, sourceFolder: UUID? = nil) {
        recordForUndo()
        dragCoordinator.beginDrag(for: id, sourceFolder: sourceFolder)
    }

    /// Ends the current drag session. If `commit` is true, persists changes immediately.
    func endDrag(commit: Bool) {
        dragCoordinator.endDrag(commit: commit)
    }

    /// Extracts a dragged item from its source folder into the top-level grid.
    /// No-op if the item is already top-level or no drag is active.
    func extractDraggedItemIfNeeded() {
        dragCoordinator.extractDraggedItemIfNeeded()
    }

    /// Requests folder-creation stacking onto the target item after a short delay.
    /// Cancels any previous pending stacking request.
    func requestStacking(onto id: UUID) {
        dragCoordinator.requestStacking(onto: id)
    }

    /// Cancels any pending stacking timer.
    func cancelPendingStacking() {
        dragCoordinator.cancelPendingStacking()
    }

    /// Commits the pending stacking if it matches the given target ID.
    /// Returns whether stacking occurred.
    func commitPendingStackingIfNeeded(for id: UUID) -> Bool {
        dragCoordinator.commitPendingStackingIfNeeded(for: id)
    }

    /// Immediately stacks the currently dragged item onto the target
    /// (creating a folder or adding to an existing one).
    @discardableResult
    func stackDraggedItem(onto targetID: UUID) -> Bool {
        dragCoordinator.stackDraggedItem(onto: targetID)
    }

    /// Moves the currently dragged item to the end of the flat items array,
    /// effectively placing it on a new last page when the current last page is full.
    func moveDraggedItemToEnd() {
        extractDraggedItemIfNeeded()
        guard let dragID = dragItemID else { return }
        moveItem(dragID, before: nil)
    }

    // MARK: - Import / Export Layout

    /// Exports the current layout to a JSON file chosen by the user via a save panel.
    func exportLayout() {
        #if os(macOS)
            let panel = NSSavePanel()
            panel.title = "Export Launchy Layout"
            panel.nameFieldStringValue = "launchy-layout.json"
            panel.allowedContentTypes = [.json]
            panel.canCreateDirectories = true

            guard panel.runModal() == .OK, let url = panel.url else { return }

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

            do {
                let data = try encoder.encode(items)
                try data.write(to: url, options: [.atomic])
            } catch {
                let alert = NSAlert()
                alert.messageText = "Export Failed"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        #endif
    }

    /// Imports a layout from a user-selected JSON file, replacing the current arrangement.
    func importLayout() {
        #if os(macOS)
            let panel = NSOpenPanel()
            panel.title = "Import Launchy Layout"
            panel.allowedContentTypes = [.json]
            panel.allowsMultipleSelection = false
            panel.canChooseDirectories = false

            guard panel.runModal() == .OK, let url = panel.url else { return }

            do {
                let data = try Data(contentsOf: url)
                let imported = try JSONDecoder().decode([LaunchyItem].self, from: data)
                items = imported
                currentPage = 0
                presentedFolderID = nil
                selectedItemIDs.removeAll()
                recentlyRemovedApps.removeAll()
                isEditing = false
                saveNow()
            } catch {
                let alert = NSAlert()
                alert.messageText = "Import Failed"
                alert.informativeText =
                    "The file could not be read as a valid Launchy layout. \(error.localizedDescription)"
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        #endif
    }
}
