import AppKit
import Foundation

@MainActor
final class ApplicationIconProvider {
    static let shared = ApplicationIconProvider()

    private let cache = NSCache<NSURL, NSImage>()
    private let workspace = NSWorkspace.shared

    private init() {
        cache.countLimit = 512
        observeAppTerminations()
    }

    /// Returns the icon for the app at the given URL, using the cache when available.
    func icon(for url: URL) -> NSImage {
        let key = url as NSURL
        if let cached = cache.object(forKey: key) {
            return cached
        }

        let image = workspace.icon(forFile: url.path)
        cache.setObject(image, forKey: key)
        return image
    }

    /// Removes the cached icon for a specific app bundle URL so it will be
    /// re-fetched from disk on the next access. Useful when an app updates
    /// its icon (e.g. after an in-place upgrade).
    func invalidateIcon(for bundleURL: URL) {
        cache.removeObject(forKey: bundleURL as NSURL)
    }

    /// Removes all cached icons. The cache will be repopulated lazily as
    /// icons are requested again.
    func invalidateAll() {
        cache.removeAllObjects()
    }

    /// Pre-warms the icon cache on a background thread for the given app URLs.
    /// Icons are loaded off the main thread and then inserted into the cache
    /// on the main actor.
    func preWarmCache(for urls: [URL]) {
        let paths = urls.map { ($0, $0.path) }
        Task.detached(priority: .userInitiated) {
            var loaded: [(NSURL, NSImage)] = []
            loaded.reserveCapacity(paths.count)
            for (url, path) in paths {
                let image = NSWorkspace.shared.icon(forFile: path)
                loaded.append((url as NSURL, image))
            }
            await MainActor.run {
                for (key, image) in loaded {
                    // Only insert if not already cached (avoid overwriting
                    // a fresher entry).
                    if self.cache.object(forKey: key) == nil {
                        self.cache.setObject(image, forKey: key)
                    }
                }
            }
        }
    }

    // MARK: - Private

    /// Observes app termination events from NSWorkspace. When an app
    /// terminates, its cached icon is evicted so that the next access
    /// picks up any icon changes that may have occurred during an update.
    private func observeAppTerminations() {
        workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: workspace,
            queue: .main
        ) { [weak self] notification in
            guard
                let app = notification.userInfo?[
                    NSWorkspace.applicationUserInfoKey
                ] as? NSRunningApplication
            else {
                return
            }
            guard let bundleURL = app.bundleURL else { return }
            MainActor.assumeIsolated {
                self?.invalidateIcon(for: bundleURL)
            }
        }
    }
}
