import AppKit
import Foundation

final class IconStore {
    static let shared = IconStore()

    private var cache: [String: NSImage] = [:]
    private let queue = DispatchQueue(label: "icon-store", qos: .userInitiated)

    private init() {}

    func icon(for bundleURL: URL) -> NSImage {
        let key = bundleURL.path
        if let cached = queue.sync(execute: { cache[key] }) {
            return cached
        }
        let icon = NSWorkspace.shared.icon(forFile: bundleURL.path)
        icon.size = NSSize(width: 128, height: 128)
        queue.async {
            self.cache[key] = icon
        }
        return icon
    }
}
