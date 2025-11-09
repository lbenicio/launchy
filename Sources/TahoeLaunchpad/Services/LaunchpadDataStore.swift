import Foundation

final class LaunchpadDataStore {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let storageURL: URL
    private let fileManager: FileManager
    private let applicationsProvider: InstalledApplicationsProvider

    init(
        fileManager: FileManager = .default,
        applicationsProvider: InstalledApplicationsProvider = InstalledApplicationsProvider()
    ) {
        self.fileManager = fileManager
        self.applicationsProvider = applicationsProvider
        encoder = JSONEncoder()
        decoder = JSONDecoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let support =
            fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let directory = support.appendingPathComponent("TahoeLaunchpad", isDirectory: true)
        storageURL = directory.appendingPathComponent("launchpad-data.json", conformingTo: .json)

        if !fileManager.fileExists(atPath: directory.path) {
            do {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            } catch {
                print("LaunchpadDataStore: Failed to create storage directory: \(error)")
            }
        }
    }

    func load() -> [LaunchpadItem] {
        let installedApps = applicationsProvider.fetchApplications()

        guard fileManager.fileExists(atPath: storageURL.path) else {
            return installedApps.map { LaunchpadItem.app($0) }
        }

        do {
            let data = try Data(contentsOf: storageURL)
            let storedItems = try decoder.decode([LaunchpadItem].self, from: data)
            let reconciled = reconcile(stored: storedItems, installed: installedApps)
            if reconciled != storedItems {
                save(reconciled)
            }
            return reconciled
        } catch {
            print("LaunchpadDataStore: Load error => \(error)")
            return installedApps.map { LaunchpadItem.app($0) }
        }
    }

    func save(_ items: [LaunchpadItem]) {
        do {
            let data = try encoder.encode(items)
            try data.write(to: storageURL, options: [.atomic])
        } catch {
            print("LaunchpadDataStore: Save error => \(error)")
        }
    }
}

extension LaunchpadDataStore {
    fileprivate func reconcile(stored: [LaunchpadItem], installed: [AppIcon]) -> [LaunchpadItem] {
        var available = Dictionary(
            uniqueKeysWithValues: installed.map { ($0.bundleIdentifier, $0) })
        var results: [LaunchpadItem] = []

        for item in stored {
            switch item {
            case .app(let icon):
                guard var refreshed = available.removeValue(forKey: icon.bundleIdentifier) else {
                    continue
                }
                refreshed.id = icon.id
                results.append(.app(refreshed))

            case .folder(var folder):
                var updatedApps: [AppIcon] = []
                for app in folder.apps {
                    guard var refreshed = available.removeValue(forKey: app.bundleIdentifier) else {
                        continue
                    }
                    refreshed.id = app.id
                    updatedApps.append(refreshed)
                }

                if !updatedApps.isEmpty {
                    folder.apps = updatedApps
                    results.append(.folder(folder))
                }
            }
        }

        let remainingApps = available.values
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        results.append(contentsOf: remainingApps.map { LaunchpadItem.app($0) })

        return results
    }
}
