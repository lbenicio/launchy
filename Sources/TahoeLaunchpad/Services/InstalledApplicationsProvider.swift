import Foundation

struct InstalledApplicationsProvider {
    private let fileManager: FileManager
    private let resourceKeys: Set<URLResourceKey> = [.isDirectoryKey, .isPackageKey]

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func fetchApplications() -> [AppIcon] {
        var collected: [String: AppIcon] = [:]

        for directory in searchDirectories where fileManager.fileExists(atPath: directory.path) {
            guard
                let enumerator = fileManager.enumerator(
                    at: directory,
                    includingPropertiesForKeys: Array(resourceKeys),
                    options: [.skipsHiddenFiles, .skipsPackageDescendants],
                    errorHandler: nil
                )
            else { continue }

            for case let url as URL in enumerator where url.pathExtension == "app" {
                guard let values = try? url.resourceValues(forKeys: resourceKeys),
                    values.isDirectory == true, values.isPackage == true
                else { continue }

                if let icon = makeAppIcon(from: url) {
                    if collected[icon.bundleIdentifier] == nil {
                        collected[icon.bundleIdentifier] = icon
                    }
                }
            }
        }

        return collected.values.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private var searchDirectories: [URL] {
        var directories: [URL] = []
        directories.append(URL(fileURLWithPath: "/Applications", isDirectory: true))
        directories.append(URL(fileURLWithPath: "/System/Applications", isDirectory: true))
        let userApplications = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(
            "Applications",
            isDirectory: true
        )
        directories.append(userApplications)
        return directories
    }

    private func makeAppIcon(from url: URL) -> AppIcon? {
        guard let bundle = Bundle(url: url) else { return nil }
        let identifier = bundle.bundleIdentifier ?? url.path
        let name =
            bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? url.deletingPathExtension().lastPathComponent

        return AppIcon(name: name, bundleIdentifier: identifier, bundleURL: url)
    }
}
