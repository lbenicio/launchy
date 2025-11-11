import XCTest

@testable import TahoeLaunchpad

final class LaunchpadViewModelTests: XCTestCase {
    private var tempDirectory: URL!
    private var fileManager: StubFileManager!
    private var dataStore: LaunchpadDataStore!
    private var userDefaults: UserDefaults!
    private var userDefaultsSuiteName: String!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "LaunchpadViewModelTests-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: tempDirectory, withIntermediateDirectories: true)

        fileManager = StubFileManager(applicationSupportDirectory: tempDirectory)
        let applicationsProvider = InstalledApplicationsProvider(fileManager: fileManager)
        dataStore = LaunchpadDataStore(
            fileManager: fileManager,
            applicationsProvider: applicationsProvider
        )

        let suiteName = "LaunchpadViewModelTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw XCTSkip("Unable to create UserDefaults suite for tests")
        }
        defaults.removePersistentDomain(forName: suiteName)
        userDefaults = defaults
        userDefaultsSuiteName = suiteName
    }

    override func tearDownWithError() throws {
        if let suiteName = userDefaultsSuiteName, let userDefaults {
            userDefaults.removePersistentDomain(forName: suiteName)
        }
        userDefaults = nil
        userDefaultsSuiteName = nil
        dataStore = nil
        fileManager = nil
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        tempDirectory = nil
    }

    @MainActor
    func testAddSelectedAppsMovesAppsIntoFolder() throws {
        let appAlpha = makeAppIcon(name: "Alpha", bundleIdentifier: "com.test.alpha")
        let appBeta = makeAppIcon(name: "Beta", bundleIdentifier: "com.test.beta")
        let existingApp = makeAppIcon(name: "Console", bundleIdentifier: "com.test.console")
        let utilitiesFolder = LaunchpadFolder(name: "Utilities", apps: [existingApp])

        let initialItems: [LaunchpadItem] = [
            .app(appAlpha),
            .app(appBeta),
            .folder(utilitiesFolder),
        ]

        dataStore.save(initialItems)

        guard let userDefaults, let dataStore else {
            XCTFail("Expected test infrastructure to be configured")
            return
        }

        let settingsStore = GridSettingsStore(defaults: userDefaults)
        let viewModel = LaunchpadViewModel(
            dataStore: dataStore,
            settingsStore: settingsStore,
            initialItems: initialItems
        )

        viewModel.toggleEditing()
        viewModel.toggleSelection(for: appAlpha.id)
        viewModel.toggleSelection(for: appBeta.id)

        XCTAssertTrue(viewModel.hasSelectedApps)

        viewModel.addSelectedApps(toFolder: utilitiesFolder.id)

        guard let updatedFolder = viewModel.folder(by: utilitiesFolder.id) else {
            XCTFail("Expected folder to exist after insertion")
            return
        }

        XCTAssertEqual(updatedFolder.apps.count, 3)
        XCTAssertTrue(updatedFolder.apps.contains(where: { $0.id == appAlpha.id }))
        XCTAssertTrue(updatedFolder.apps.contains(where: { $0.id == appBeta.id }))
        XCTAssertTrue(updatedFolder.apps.contains(where: { $0.id == existingApp.id }))
        XCTAssertFalse(viewModel.items.contains(where: { $0.id == appAlpha.id && $0.asApp != nil }))
        XCTAssertFalse(viewModel.items.contains(where: { $0.id == appBeta.id && $0.asApp != nil }))
        XCTAssertEqual(viewModel.presentedFolderID, utilitiesFolder.id)
        XCTAssertTrue(viewModel.selectedItemIDs.isEmpty)
    }

    private func makeAppIcon(name: String, bundleIdentifier: String) -> AppIcon {
        AppIcon(
            name: name,
            bundleIdentifier: bundleIdentifier,
            bundleURL: URL(fileURLWithPath: "/Applications/\(name).app")
        )
    }
}

private final class StubFileManager: FileManager {
    private let applicationSupportDirectory: URL
    private let blockedPaths: Set<String>

    init(applicationSupportDirectory: URL) {
        self.applicationSupportDirectory = applicationSupportDirectory

        let homeApplications = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications", isDirectory: true)
            .path

        blockedPaths = Set([
            "/Applications",
            "/System/Applications",
            NSString(string: homeApplications).standardizingPath,
        ])

        super.init()
    }

    override func urls(
        for directory: FileManager.SearchPathDirectory,
        in domainMask: FileManager.SearchPathDomainMask
    ) -> [URL] {
        if directory == .applicationSupportDirectory {
            return [applicationSupportDirectory]
        }
        return super.urls(for: directory, in: domainMask)
    }

    override func fileExists(atPath path: String) -> Bool {
        let normalized = NSString(string: path).standardizingPath
        if blockedPaths.contains(normalized) {
            return false
        }
        return super.fileExists(atPath: path)
    }

    override func fileExists(
        atPath path: String,
        isDirectory: UnsafeMutablePointer<ObjCBool>?
    ) -> Bool {
        let normalized = NSString(string: path).standardizingPath
        if blockedPaths.contains(normalized) {
            isDirectory?.pointee = false
            return false
        }
        return super.fileExists(atPath: path, isDirectory: isDirectory)
    }
}
