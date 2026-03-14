import Foundation

#if os(macOS)
    import AppKit
#endif

// MARK: - App launch, recently-added tracking, and post-launch dismiss

extension LaunchyViewModel {

    /// Opens the given app using `NSWorkspace` and dismisses the launcher window.
    func launch(_ item: LaunchyItem) {
        #if os(macOS)
            guard case .app(let icon) = item else { return }
            isLaunchingApp = true
            launchingItemID = icon.id
            clearRecentlyAdded(icon.bundleIdentifier)
            NSWorkspace.shared.openApplication(
                at: icon.bundleURL,
                configuration: NSWorkspace.OpenConfiguration()
            ) { [weak self] _, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let error {
                        print("Launchy: Failed to launch \(icon.name): \(error.localizedDescription)")
                        self.isLaunchingApp = false
                        self.launchingItemID = nil
                        let alert = NSAlert()
                        alert.messageText = "Unable to Launch \"\(icon.name)\""
                        alert.informativeText = error.localizedDescription
                        alert.alertStyle = .warning
                        alert.addButton(withTitle: "OK")
                        alert.runModal()
                        return
                    }
                    // Record only on success, then let the tile animation play
                    // before dismissing (~0.25 s matches the spring animation).
                    MenuBarService.shared.recordLaunch(
                        name: icon.name,
                        bundleIdentifier: icon.bundleIdentifier,
                        bundleURL: icon.bundleURL
                    )
                    try? await Task.sleep(for: .milliseconds(250))
                    self.dismissAfterLaunch()
                }
            }
        #endif
    }

    /// Resets transient launch state so the launcher can be re-shown cleanly.
    func resetLaunchState() {
        isLaunchingApp = false
        launchingItemID = nil
    }

    // MARK: - Recently added tracking

    /// Marks an app as no longer "recently added" (e.g., after first launch).
    func clearRecentlyAdded(_ bundleIdentifier: String) {
        recentlyAddedBundleIDs.remove(bundleIdentifier)
    }

    /// Compares the current set of bundle IDs against the previously stored set
    /// and marks any new ones as "recently added".
    // Internal — also called from ApplicationWatcher and ImportExport extensions.
    func updateRecentlyAdded() {
        let key = "dev.lbenicio.launchy.known-bundle-ids"
        let storedIDs = Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
        let currentIDs = Set(allBundleIdentifiers())
        let newIDs = currentIDs.subtracting(storedIDs)
        if !storedIDs.isEmpty {
            recentlyAddedBundleIDs = newIDs
        }
        UserDefaults.standard.set(Array(currentIDs), forKey: key)
    }

    private func allBundleIdentifiers() -> [String] {
        items.flatMap { item -> [String] in
            switch item {
            case .app(let icon): return [icon.bundleIdentifier]
            case .folder(let folder): return folder.apps.map(\.bundleIdentifier)
            }
        }
    }

    private func dismissAfterLaunch() {
        #if os(macOS)
            AppCoordinator.shared.send(.dismissLauncher)
        #endif
    }
}
