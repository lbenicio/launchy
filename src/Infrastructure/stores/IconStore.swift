import AppKit
import Foundation

@MainActor
final class IconStore {
    static let shared = IconStore()

    private var cache: [String: NSImage] = [:]

    private init() {}

    func icon(for bundleURL: URL) -> NSImage {
        let key = bundleURL.path
        if let cached = cache[key] {
            return cached
        }

        let icon = NSWorkspace.shared.icon(forFile: bundleURL.path)
        icon.size = NSSize(width: 128, height: 128)
        cache[key] = icon
        return icon
    }
}
