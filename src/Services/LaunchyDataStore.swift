import Foundation

@MainActor
final class LaunchyDataStore {
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
        let directory = support.appendingPathComponent("Launchy", isDirectory: true)
        storageURL = directory.appendingPathComponent("launchy-data.json", conformingTo: .json)

        if !fileManager.fileExists(atPath: directory.path) {
            do {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            } catch {
                print("LaunchyDataStore: Failed to create storage directory: \(error)")
            }
        }
    }

    func load() -> [LaunchyItem] {
        let installedApps = applicationsProvider.fetchApplications()

        guard fileManager.fileExists(atPath: storageURL.path) else {
            return installedApps.map { LaunchyItem.app($0) }
        }

        do {
            let data = try Data(contentsOf: storageURL)
            let storedItems = try decoder.decode([LaunchyItem].self, from: data)
            let reconciled = reconcile(stored: storedItems, installed: installedApps)
            if reconciled != storedItems {
                save(reconciled)
            }
            return reconciled
        } catch {
            print("LaunchyDataStore: Load error => \(error)")
            return installedApps.map { LaunchyItem.app($0) }
        }
    }

    /// Loads items asynchronously, running all disk I/O (app scanning + JSON reading)
    /// off the main actor so startup never blocks the UI.
    func loadAsync() async -> [LaunchyItem] {
        // Capture stable value types so the detached task doesn't reference self
        let url = storageURL

        struct RawLoad: Sendable {
            let installedApps: [AppIcon]
            let storedItems: [LaunchyItem]?
        }

        // Run both filesystem operations together in one detached task
        let raw: RawLoad = await Task.detached(priority: .userInitiated) {
            let provider = InstalledApplicationsProvider(fileManager: .default)
            let apps = provider.fetchApplications()

            guard FileManager.default.fileExists(atPath: url.path),
                let data = try? Data(contentsOf: url),
                let stored = try? JSONDecoder().decode([LaunchyItem].self, from: data)
            else {
                return RawLoad(installedApps: apps, storedItems: nil)
            }
            return RawLoad(installedApps: apps, storedItems: stored)
        }.value

        guard let storedItems = raw.storedItems else {
            return raw.installedApps.map { LaunchyItem.app($0) }
        }

        let reconciled = reconcile(stored: storedItems, installed: raw.installedApps)
        if reconciled != storedItems {
            save(reconciled)
        }
        return reconciled
    }

    /// Returns a fresh layout from currently installed applications,
    /// ignoring any previously persisted arrangement.
    func loadFresh() async -> [LaunchyItem] {
        // Construct a fresh provider inside the detached task to avoid
        // capturing main-actor-isolated state across isolation boundaries.
        let installedApps: [AppIcon] = await Task.detached(priority: .userInitiated) {
            let provider = InstalledApplicationsProvider(fileManager: .default)
            return provider.fetchApplications()
        }.value
        return installedApps.map { LaunchyItem.app($0) }
    }

    func save(_ items: [LaunchyItem]) {
        do {
            let data = try encoder.encode(items)
            try data.write(to: storageURL, options: [.atomic])
        } catch {
            print("LaunchyDataStore: Save error => \(error)")
        }
    }
}

extension LaunchyDataStore {
    func reconcile(stored: [LaunchyItem], installed: [AppIcon]) -> [LaunchyItem] {
        var available = Dictionary(
            uniqueKeysWithValues: installed.map { ($0.bundleIdentifier, $0) }
        )
        var results: [LaunchyItem] = []

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

                if updatedApps.count > 1 {
                    folder.apps = updatedApps
                    results.append(.folder(folder))
                } else if updatedApps.count == 1 {
                    // Disband — matches Launchpad behaviour of auto-disbanding 1-app folders
                    results.append(.app(updatedApps[0]))
                }
            }
        }

        let remainingApps = available.values
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        results.append(contentsOf: remainingApps.map { LaunchyItem.app($0) })

        return results
    }
}
