import AppKit
import Foundation

@MainActor
final class ApplicationIconProvider {
    static let shared = ApplicationIconProvider()

    private let cache = NSCache<NSURL, NSImage>()
    private let workspace = NSWorkspace.shared
    /// Stores the `Info.plist` modification date at the time the icon was cached,
    /// so we can detect bundle updates (e.g. in-place app upgrades).
    private var cachedMtimes: [NSURL: Date] = [:]

    private init() {
        cache.countLimit = 512
        observeAppTerminations()
    }

    /// Returns the icon for the app at the given URL, using the cache when available.
    /// If the bundle's `Contents/Info.plist` has been modified since the icon was
    /// cached, the cache entry is evicted and the icon is re-fetched from disk.
    func icon(for url: URL) -> NSImage {
        let key = url as NSURL
        if let cached = cache.object(forKey: key) {
            if !isBundleStale(key: key, bundleURL: url) {
                return cached
            }
            // Bundle updated — evict stale entry
            cache.removeObject(forKey: key)
            cachedMtimes.removeValue(forKey: key)
        }

        let image = workspace.icon(forFile: url.path)
        cache.setObject(image, forKey: key)
        cachedMtimes[key] = ApplicationIconProvider.infoPlistMtime(url)
        return image
    }

    /// Removes the cached icon for a specific app bundle URL so it will be
    /// re-fetched from disk on the next access.
    func invalidateIcon(for bundleURL: URL) {
        let key = bundleURL as NSURL
        cache.removeObject(forKey: key)
        cachedMtimes.removeValue(forKey: key)
    }

    /// Removes all cached icons. The cache will be repopulated lazily on access.
    func invalidateAll() {
        cache.removeAllObjects()
        cachedMtimes.removeAll()
    }

    /// Pre-warms the icon cache on a background thread for the given app URLs.
    /// Icons are loaded off the main thread and then inserted into the cache
    /// on the main actor.
    func preWarmCache(for urls: [URL]) {
        let paths = urls.map { ($0, $0.path) }
        Task.detached(priority: .userInitiated) {
            var loaded: [(NSURL, NSImage, Date?)] = []
            loaded.reserveCapacity(paths.count)
            for (url, path) in paths {
                let image = NSWorkspace.shared.icon(forFile: path)
                let mtime = ApplicationIconProvider.infoPlistMtime(url)
                loaded.append((url as NSURL, image, mtime))
            }
            await MainActor.run {
                for (key, image, mtime) in loaded {
                    if self.cache.object(forKey: key) == nil {
                        self.cache.setObject(image, forKey: key)
                        self.cachedMtimes[key] = mtime
                    }
                }
            }
        }
    }

    // MARK: - Private helpers

    private func isBundleStale(key: NSURL, bundleURL: URL) -> Bool {
        guard let stored = cachedMtimes[key] else { return false }
        guard let current = ApplicationIconProvider.infoPlistMtime(bundleURL) else { return false }
        return current > stored
    }

    /// Non-isolated helper so it can be called from detached Tasks.
    nonisolated private static func infoPlistMtime(_ bundleURL: URL) -> Date? {
        let keys = Set<URLResourceKey>([.contentModificationDateKey])
        let infoPlist = bundleURL.appendingPathComponent("Contents/Info.plist")
        return try? infoPlist.resourceValues(forKeys: keys).contentModificationDate
    }

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
