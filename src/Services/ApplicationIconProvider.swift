import AppKit

@MainActor
final class ApplicationIconProvider {
    static let shared = ApplicationIconProvider()

    private let cache = NSCache<NSURL, NSImage>()
    private let workspace = NSWorkspace.shared

    private init() {
        cache.countLimit = 512
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

    /// Pre-warms the icon cache on a background thread for the given app URLs.
    /// Icons are loaded off the main thread and then inserted into the cache on the main actor.
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
                    // Only insert if not already cached (avoid overwriting a fresher entry)
                    if self.cache.object(forKey: key) == nil {
                        self.cache.setObject(image, forKey: key)
                    }
                }
            }
        }
    }
}
