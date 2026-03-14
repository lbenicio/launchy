import Foundation

#if os(macOS)
    import AppKit
    import SwiftUI
#endif

// MARK: - Application watcher

extension LaunchyViewModel {

    #if os(macOS)
        /// Starts (or restarts) the filesystem watcher for installed-app directories.
        /// Called once after initial load and again whenever settings change so that
        /// custom search directories are respected immediately.
        func setupApplicationWatcher() {
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
}
