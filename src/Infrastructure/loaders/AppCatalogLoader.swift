import AppKit
import Foundation

struct AppCatalogLoader {
    private let roots: [URL]

    init(
        roots: [URL] = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(
                "Applications", isDirectory: true
            )
        ]
    ) {
        self.roots = roots
    }

    func loadCatalog() async -> [CatalogEntry] {
        let roots = roots
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let entries = Self.scanCatalog(roots: roots)
                continuation.resume(returning: entries)
            }
        }
    }

    private static func scanCatalog(roots: [URL]) -> [CatalogEntry] {
        var appEntries: [String: AppItem] = [:]
        var folderEntries: [String: FolderItem] = [:]
        var seenPaths: Set<String> = []
        let fileManager = FileManager.default

        for root in roots {
            guard
                let contents = try? fileManager.contentsOfDirectory(
                    at: root,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles]
                ) else {
                continue
            }
            for url in contents {
                let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey])
                let isDirectory = resourceValues?.isDirectory ?? false
                if url.pathExtension.lowercased() == "app" {
                    if seenPaths.insert(url.path).inserted {
                        if let app = makeAppItem(from: url) {
                            appEntries[app.id] = app
                        }
                    }
                } else if isDirectory {
                    let folderName = url.lastPathComponent
                    let folderApps = collectApps(in: url, fileManager: fileManager)
                    if !folderApps.isEmpty {
                        let folder = FolderItem(
                            id: url.path,
                            name: prettifiedFolderName(folderName),
                            apps: folderApps.sorted(by: { lhs, rhs in
                                lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName)
                                    == .orderedAscending
                            })
                        )
                        folderEntries[folder.id] = folder
                    }
                }
            }
        }

        var entries: [CatalogEntry] = []
        let sortedFolders = folderEntries.values.sorted { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
        entries.append(contentsOf: sortedFolders.map { CatalogEntry.folder($0) })
        let sortedApps = appEntries.values.sorted { lhs, rhs in
            lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
        entries.append(contentsOf: sortedApps.map { CatalogEntry.app($0) })
        return entries
    }

    private static func collectApps(in folderURL: URL, fileManager: FileManager) -> [AppItem] {
        guard
            let enumerator = fileManager.enumerator(
                at: folderURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else {
            return []
        }
        var apps: [AppItem] = []
        for case let url as URL in enumerator {
            if url.pathExtension.lowercased() == "app", let app = makeAppItem(from: url) {
                apps.append(app)
                enumerator.skipDescendants()
            }
        }
        return apps
    }

    private static func makeAppItem(from bundleURL: URL) -> AppItem? {
        guard let bundle = Bundle(url: bundleURL) else { return nil }
        let displayName =
            bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? bundle.object(
                forInfoDictionaryKey: "CFBundleName") as? String
            ?? bundleURL.deletingPathExtension().lastPathComponent
        let identifier = bundle.bundleIdentifier
        return AppItem(
            id: bundleURL.path,
            displayName: displayName,
            bundleIdentifier: identifier,
            bundleURL: bundleURL
        )
    }

    private static func prettifiedFolderName(_ name: String) -> String {
        switch name.lowercased() {
        case "utilities": "Utilities"
        case "other": "Other"
        case "tools": "Tools"
        default: name.replacingOccurrences(of: "-", with: " ").capitalized
        }
    }
}
