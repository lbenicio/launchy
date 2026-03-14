import XCTest

@testable import Launchy

/// Tests for `LaunchyDataStore.reconcile(stored:installed:)`.
/// This exercises the core persistence merging logic in isolation.
@MainActor
final class LaunchyDataStoreTests: XCTestCase {
    private var tempDirectory: URL!
    private var dataStore: LaunchyDataStore!

    override func setUp() async throws {
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "LaunchyDataStoreTests-\(UUID().uuidString)", isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: tempDirectory, withIntermediateDirectories: true
        )
        let fileManager = StubFileManager(applicationSupportDirectory: tempDirectory)
        let provider = InstalledApplicationsProvider(fileManager: fileManager)
        dataStore = LaunchyDataStore(fileManager: fileManager, applicationsProvider: provider)
    }

    override func tearDown() async throws {
        dataStore = nil
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        tempDirectory = nil
    }

    // MARK: - Helpers

    private func makeApp(
        name: String,
        bundleID: String,
        url: URL? = nil,
        id: UUID = UUID()
    ) -> AppIcon {
        AppIcon(
            id: id,
            name: name,
            bundleIdentifier: bundleID,
            bundleURL: url ?? URL(fileURLWithPath: "/Applications/\(name).app")
        )
    }

    private func makeFolder(name: String, apps: [AppIcon]) -> LaunchyFolder {
        LaunchyFolder(name: name, apps: apps)
    }

    // MARK: - App removal

    func testReconcileRemovesUninstalledApps() {
        let appA = makeApp(name: "A", bundleID: "com.test.a")
        let appB = makeApp(name: "B", bundleID: "com.test.b")
        let stored: [LaunchyItem] = [.app(appA), .app(appB)]
        let installed: [AppIcon] = [appA]              // B is no longer installed

        let result = dataStore.reconcile(stored: stored, installed: installed)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].asApp?.bundleIdentifier, "com.test.a")
    }

    // MARK: - New app append

    func testReconcileAppendsNewInstalledAppsAtEnd() {
        let existing = makeApp(name: "Existing", bundleID: "com.test.existing")
        let newApp   = makeApp(name: "NewApp",   bundleID: "com.test.new")
        let stored: [LaunchyItem]  = [.app(existing)]
        let installed: [AppIcon]   = [existing, newApp]

        let result = dataStore.reconcile(stored: stored, installed: installed)

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].asApp?.bundleIdentifier, "com.test.existing")
        XCTAssertEqual(result[1].asApp?.bundleIdentifier, "com.test.new")
    }

    // MARK: - URL refresh

    func testReconcileRefreshesBundleURLFromInstalledList() {
        let originalID = UUID()
        let oldURL = URL(fileURLWithPath: "/OldPath/App.app")
        let newURL = URL(fileURLWithPath: "/NewPath/App.app")
        let stored = makeApp(name: "App", bundleID: "com.test.app", url: oldURL, id: originalID)
        let installed = makeApp(name: "App", bundleID: "com.test.app", url: newURL)

        let result = dataStore.reconcile(stored: [.app(stored)], installed: [installed])

        XCTAssertEqual(result.count, 1)
        let refreshed = result[0].asApp
        XCTAssertEqual(refreshed?.bundleURL, newURL, "URL should be updated from installed list")
        XCTAssertEqual(refreshed?.id, originalID, "ID should be preserved from stored layout")
    }

    // MARK: - Folder reconcile

    func testReconcileFolderWithPartialAppsRemoved() {
        let appA = makeApp(name: "A", bundleID: "com.test.a")
        let appB = makeApp(name: "B", bundleID: "com.test.b")
        let folder = makeFolder(name: "MyFolder", apps: [appA, appB])
        let stored: [LaunchyItem]  = [.folder(folder)]
        let installed: [AppIcon]   = [appA]            // B removed

        let result = dataStore.reconcile(stored: stored, installed: installed)

        XCTAssertEqual(result.count, 1)
        let resultFolder = result[0].asFolder
        XCTAssertNotNil(resultFolder, "Folder should remain when at least one app survives")
        XCTAssertEqual(resultFolder?.apps.count, 1)
        XCTAssertEqual(resultFolder?.apps[0].bundleIdentifier, "com.test.a")
    }

    func testReconcileFolderWithAllAppsRemovedDropsFolder() {
        let appA = makeApp(name: "A", bundleID: "com.test.a")
        let folder = makeFolder(name: "EmptyFolder", apps: [appA])
        let stored: [LaunchyItem] = [.folder(folder)]
        let installed: [AppIcon]  = []                 // nothing installed

        let result = dataStore.reconcile(stored: stored, installed: installed)

        XCTAssertTrue(result.isEmpty, "Folder with no surviving apps should be dropped")
    }

    func testReconcileFolderAppsGetRefreshedURLs() {
        let originalID = UUID()
        let oldURL  = URL(fileURLWithPath: "/old/FolderApp.app")
        let newURL  = URL(fileURLWithPath: "/new/FolderApp.app")
        let stored  = makeApp(name: "FolderApp", bundleID: "com.test.fa", url: oldURL, id: originalID)
        let folder  = makeFolder(name: "Utilities", apps: [stored])
        let installed = makeApp(name: "FolderApp", bundleID: "com.test.fa", url: newURL)

        let result = dataStore.reconcile(stored: [.folder(folder)], installed: [installed])

        XCTAssertEqual(result.count, 1)
        let resultFolder = result[0].asFolder
        XCTAssertEqual(resultFolder?.apps.first?.bundleURL, newURL)
        XCTAssertEqual(resultFolder?.apps.first?.id, originalID)
    }

    // MARK: - Order preservation

    func testReconcilePreservesStoredOrder() {
        let appA = makeApp(name: "A", bundleID: "com.test.a")
        let appB = makeApp(name: "B", bundleID: "com.test.b")
        let appC = makeApp(name: "C", bundleID: "com.test.c")
        let stored: [LaunchyItem]  = [.app(appC), .app(appA), .app(appB)]
        let installed: [AppIcon]   = [appA, appB, appC]

        let result = dataStore.reconcile(stored: stored, installed: installed)

        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0].asApp?.bundleIdentifier, "com.test.c")
        XCTAssertEqual(result[1].asApp?.bundleIdentifier, "com.test.a")
        XCTAssertEqual(result[2].asApp?.bundleIdentifier, "com.test.b")
    }

    func testReconcileAppendsMultipleNewAppsAlphabetically() {
        let existing = makeApp(name: "Existing", bundleID: "com.test.e")
        let newZ     = makeApp(name: "Zebra",    bundleID: "com.test.z")
        let newA     = makeApp(name: "Aardvark", bundleID: "com.test.aardvark")
        let stored: [LaunchyItem] = [.app(existing)]
        let installed: [AppIcon]  = [existing, newZ, newA]

        let result = dataStore.reconcile(stored: stored, installed: installed)

        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0].asApp?.bundleIdentifier, "com.test.e")
        // New apps should be appended alphabetically
        let newNames = result.dropFirst().compactMap { $0.asApp?.name }
        XCTAssertEqual(newNames, newNames.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        })
    }

    // MARK: - Renamed bundle identifier

    func testReconcileTreatsRenamedBundleIDAsNewApp() {
        let oldApp = makeApp(name: "App", bundleID: "com.old.id")
        let newApp = makeApp(name: "App", bundleID: "com.new.id")
        let stored: [LaunchyItem] = [.app(oldApp)]
        let installed: [AppIcon]  = [newApp]

        let result = dataStore.reconcile(stored: stored, installed: installed)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].asApp?.bundleIdentifier, "com.new.id",
                       "App with renamed bundle ID should appear as new app at end")
    }
}
