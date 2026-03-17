import Foundation
import SwiftUI

#if os(macOS)
    import AppKit
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
                URL(fileURLWithPath: "/System/Applications/Utilities"),
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
                    guard let self else { return }
                    // Coalesce burst FS events (e.g. an app update touching many
                    // files) into a single reconcile after the dust settles.
                    self.reconcileDebounceTask?.cancel()
                    self.reconcileDebounceTask = Task { [weak self] in
                        try? await Task.sleep(for: .seconds(1.5))
                        guard !Task.isCancelled, let self else { return }
                        await self.reconcileInstalledApps()
                    }
                }
            }
            applicationWatcher?.start()
        }

        /// Reconciles the current layout against the currently installed applications.
        /// Newly installed apps are appended; uninstalled apps are removed.
        /// The user's custom arrangement is preserved.
        func reconcileInstalledApps() async {
            let reconciled = await dataStore.loadAsync()
            guard reconciled != items else { return }

            // Pre-warm icon cache for any new app bundle URLs before they render.
            let oldURLs = Set(
                items.flatMap { item -> [URL] in
                    switch item {
                    case .app(let icon): return [icon.bundleURL]
                    case .folder(let folder): return folder.apps.map(\.bundleURL)
                    case .widget(_): return []  // Widgets don't have bundle URLs
                    }
                }
            )
            let newURLs = reconciled.compactMap { item -> URL? in
                guard case .app(let icon) = item, !oldURLs.contains(icon.bundleURL) else {
                    return nil
                }
                return icon.bundleURL
            }
            if !newURLs.isEmpty {
                ApplicationIconProvider.shared.preWarmCache(for: newURLs)
            }

            withAnimation(.easeInOut(duration: 0.2)) {
                items = reconciled
            }
            ensureCurrentPageInBounds()
            updateRecentlyAdded()
        }
    #endif
}
