import Foundation

#if os(macOS)
    import AppKit
#endif

// MARK: - Finder drop (external .app bundles)

extension LaunchyViewModel {

    /// Accepts a file URL pointing to an `.app` bundle and adds it to the grid if not already present.
    @discardableResult
    func addAppFromFinder(url: URL) -> Bool {
        #if os(macOS)
            guard url.pathExtension == "app" else { return false }
            guard let bundle = Bundle(url: url),
                let bundleID = bundle.bundleIdentifier
            else { return false }

            let allBundleIDs = items.flatMap { item -> [String] in
                switch item {
                case .app(let icon): return [icon.bundleIdentifier]
                case .folder(let folder): return folder.apps.map(\.bundleIdentifier)
                case .widget(let widget): return [widget.bundleIdentifier]
                }
            }
            guard !allBundleIDs.contains(bundleID) else { return false }

            let name =
                bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                ?? url.deletingPathExtension().lastPathComponent

            let app = AppIcon(name: name, bundleIdentifier: bundleID, bundleURL: url)
            items.append(.app(app))
            saveNow()
            return true
        #else
            return false
        #endif
    }

    /// Accepts multiple file URLs from a Finder drop; returns how many were added.
    @discardableResult
    func addAppsFromFinder(urls: [URL]) -> Int {
        var count = 0
        for url in urls {
            if addAppFromFinder(url: url) { count += 1 }
        }
        return count
    }
}
