import Foundation

/// Manages app exclusion settings - which apps should be hidden from Launchpad
@MainActor
final class AppExclusionService: ObservableObject {
    static let shared = AppExclusionService()

    @Published var excludedBundleIDs: Set<String> = []
    @Published var excludedApps: [AppIcon] = []

    private let userDefaults = UserDefaults.standard
    private let excludedAppsKey = "LaunchyExcludedApps"

    private init() {
        loadExcludedApps()
    }

    // MARK: - Public Interface

    /// Excludes an app from Launchpad
    func excludeApp(_ app: AppIcon) {
        excludedBundleIDs.insert(app.bundleIdentifier)
        saveExcludedApps()
        updateExcludedAppsList()
    }

    /// Includes an app back in Launchpad
    func includeApp(_ app: AppIcon) {
        excludedBundleIDs.remove(app.bundleIdentifier)
        saveExcludedApps()
        updateExcludedAppsList()
    }

    /// Includes all apps back in Launchpad
    func includeAllApps() {
        excludedBundleIDs.removeAll()
        saveExcludedApps()
        updateExcludedAppsList()
    }

    /// Checks if an app is excluded
    func isAppExcluded(_ app: AppIcon) -> Bool {
        excludedBundleIDs.contains(app.bundleIdentifier)
    }

    /// Checks if an app is excluded by bundle identifier
    func isAppExcluded(bundleID: String) -> Bool {
        excludedBundleIDs.contains(bundleID)
    }

    /// Filters a list of apps to remove excluded ones
    func filterExcludedApps(_ apps: [AppIcon]) -> [AppIcon] {
        apps.filter { !isAppExcluded($0) }
    }

    /// Filters LaunchyItems to remove excluded apps (including those in folders)
    func filterExcludedItems(_ items: [LaunchyItem]) -> [LaunchyItem] {
        items.compactMap { item in
            switch item {
            case .app(let app):
                return isAppExcluded(app) ? nil : item
            case .folder(var folder):
                // Filter apps within folders
                folder.apps = filterExcludedApps(folder.apps)

                // If folder becomes empty or has only one app, disband it
                if folder.apps.isEmpty {
                    return nil
                } else if folder.apps.count == 1 {
                    return .app(folder.apps.first!)
                } else {
                    return .folder(folder)
                }
            case .widget:
                return item  // Widgets are never excluded
            }
        }
    }

    // MARK: - Private Methods

    private func loadExcludedApps() {
        if let bundleIDs = userDefaults.stringArray(forKey: excludedAppsKey) {
            excludedBundleIDs = Set(bundleIDs)
        }
        updateExcludedAppsList()
    }

    private func saveExcludedApps() {
        userDefaults.set(Array(excludedBundleIDs), forKey: excludedAppsKey)
    }

    private func updateExcludedAppsList() {
        // This would typically be called with the full app list
        // For now, we'll just keep the bundle IDs
    }

    /// Updates the excluded apps list with actual AppIcon objects
    func updateExcludedAppsList(with allApps: [AppIcon]) {
        excludedApps = allApps.filter { isAppExcluded($0) }
    }

    // MARK: - Default Exclusions

    /// Adds commonly excluded system apps
    func addDefaultExclusions() {
        let defaultExclusions = [
            "com.apple.finder",
            "com.apple.systempreferences",
            "com.apple.ActivityMonitor",
            "com.apple.Console",
            "com.apple.dock",
            "com.apple.loginwindow",
            "com.apple.screencaptureui",
            "com.apple.screenshot.services",
            "com.apple.spotlight",
            "com.apple.Terminal",
        ]

        excludedBundleIDs.formUnion(defaultExclusions)
        saveExcludedApps()
    }

    /// Removes all default exclusions
    func removeDefaultExclusions() {
        let defaultExclusions = [
            "com.apple.finder",
            "com.apple.systempreferences",
            "com.apple.ActivityMonitor",
            "com.apple.Console",
            "com.apple.dock",
            "com.apple.loginwindow",
            "com.apple.screencaptureui",
            "com.apple.screenshot.services",
            "com.apple.spotlight",
            "com.apple.Terminal",
        ]

        excludedBundleIDs.subtract(defaultExclusions)
        saveExcludedApps()
    }
}

// MARK: - LaunchyViewModel Extension

extension LaunchyViewModel {

    /// Excludes an app from Launchpad
    func excludeApp(_ app: AppIcon) {
        AppExclusionService.shared.excludeApp(app)
        refreshItemsWithExclusions()
    }

    /// Includes an app back in Launchpad
    func includeApp(_ app: AppIcon) {
        AppExclusionService.shared.includeApp(app)
        refreshItemsWithExclusions()
    }

    /// Toggles app exclusion
    func toggleAppExclusion(_ app: AppIcon) {
        if AppExclusionService.shared.isAppExcluded(app) {
            includeApp(app)
        } else {
            excludeApp(app)
        }
    }

    /// Refreshes items list applying current exclusion settings
    private func refreshItemsWithExclusions() {
        Task { [weak self] in
            guard let self else { return }
            let allItems = await dataStore.loadAsync()
            let filteredItems = AppExclusionService.shared.filterExcludedItems(allItems)

            await MainActor.run {
                self.items = filteredItems
                self.saveNow()
            }
        }
    }

    /// Gets the list of excluded apps for UI display
    var excludedApps: [AppIcon] {
        AppExclusionService.shared.excludedApps
    }

    /// Checks if an app is currently excluded
    func isAppExcluded(_ app: AppIcon) -> Bool {
        AppExclusionService.shared.isAppExcluded(app)
    }
}
