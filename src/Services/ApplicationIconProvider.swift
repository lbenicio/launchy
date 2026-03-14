import AppKit
import Foundation

// MARK: - Cache entry wrapper

/// Wraps an `NSImage` together with its cache key so the `NSCacheDelegate`
/// can remove the matching `cachedMtimes` entry when NSCache evicts it.
private final class IconCacheEntry: NSObject {
    let key: NSURL
    let image: NSImage

    init(key: NSURL, image: NSImage) {
        self.key = key
        self.image = image
    }
}

// MARK: - Provider

@MainActor
final class ApplicationIconProvider: NSObject {
    static let shared = ApplicationIconProvider()

    private let cache = NSCache<NSURL, IconCacheEntry>()
    private let workspace = NSWorkspace.shared
    /// Stores the `Info.plist` modification date at the time the icon was cached,
    /// so we can detect bundle updates (e.g. in-place app upgrades).
    private var cachedMtimes: [NSURL: Date] = [:]

    override private init() {
        super.init()
        cache.countLimit = 512
        cache.delegate = self
        observeWorkspaceNotifications()
    }

    /// Returns the icon for the app at the given URL, using the cache when available.
    /// If the bundle's `Contents/Info.plist` has been modified since the icon was
    /// cached, the cache entry is evicted and the icon is re-fetched from disk.
    func icon(for url: URL) -> NSImage {
        let key = url as NSURL
        if let entry = cache.object(forKey: key) {
            if !isBundleStale(key: key, bundleURL: url) {
                return entry.image
            }
            // Bundle updated — evict stale entry (delegate cleans up cachedMtimes)
            cache.removeObject(forKey: key)
        }

        let image = workspace.icon(forFile: url.path)
        let entry = IconCacheEntry(key: key, image: image)
        cache.setObject(entry, forKey: key)
        cachedMtimes[key] = ApplicationIconProvider.infoPlistMtime(url)
        return image
    }

    /// Removes the cached icon for a specific app bundle URL so it will be
    /// re-fetched from disk on the next access.
    func invalidateIcon(for bundleURL: URL) {
        let key = bundleURL as NSURL
        cache.removeObject(forKey: key)
        // NSCacheDelegate handles cachedMtimes cleanup; belt-and-suspenders:
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
                        let entry = IconCacheEntry(key: key, image: image)
                        self.cache.setObject(entry, forKey: key)
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

    private func observeWorkspaceNotifications() {
        // Evict the icon after an app terminates in case it was updated in-place.
        workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: workspace,
            queue: .main
        ) { [weak self] notification in
            guard
                let app = notification.userInfo?[
                    NSWorkspace.applicationUserInfoKey
                ] as? NSRunningApplication,
                let bundleURL = app.bundleURL
            else { return }
            MainActor.assumeIsolated {
                self?.invalidateIcon(for: bundleURL)
            }
        }

        // Evict the icon when an app is launched — covers cases where the app
        // bundle was silently replaced (e.g. auto-updater) between launches.
        workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: workspace,
            queue: .main
        ) { [weak self] notification in
            guard
                let app = notification.userInfo?[
                    NSWorkspace.applicationUserInfoKey
                ] as? NSRunningApplication,
                let bundleURL = app.bundleURL
            else { return }
            MainActor.assumeIsolated {
                self?.invalidateIcon(for: bundleURL)
            }
        }
    }
}

// MARK: - NSCacheDelegate

extension ApplicationIconProvider: NSCacheDelegate {
    /// Called by NSCache when it decides to evict an entry under memory pressure.
    /// Removes the corresponding `cachedMtimes` entry so the dictionary doesn't
    /// grow unboundedly as NSCache silently discards images.
    nonisolated func cache(
        _ cache: NSCache<AnyObject, AnyObject>,
        willEvictObject object: Any
    ) {
        guard let entry = object as? IconCacheEntry else { return }
        let key = entry.key
        Task { @MainActor [weak self] in
            self?.cachedMtimes.removeValue(forKey: key)
        }
    }
}
