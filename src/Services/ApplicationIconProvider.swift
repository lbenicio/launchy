import AppKit

@MainActor
final class ApplicationIconProvider {
    static let shared = ApplicationIconProvider()

    private let cache = NSCache<NSURL, NSImage>()
    private let workspace = NSWorkspace.shared

    private init() {
        cache.countLimit = 512
    }

    func icon(for url: URL) -> NSImage {
        let key = url as NSURL
        if let cached = cache.object(forKey: key) {
            return cached
        }

        let image = workspace.icon(forFile: url.path)
        cache.setObject(image, forKey: key)
        return image
    }
}
