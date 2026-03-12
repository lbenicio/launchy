import XCTest

@testable import Launchy

@MainActor
final class LaunchyViewModelTests: XCTestCase {
    private var tempDirectory: URL!
    private var fileManager: StubFileManager!
    private var dataStore: LaunchyDataStore!
    private var userDefaults: UserDefaults!
    private var userDefaultsSuiteName: String!

    override func setUp() async throws {
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "LaunchpadViewModelTests-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: tempDirectory, withIntermediateDirectories: true)

        fileManager = StubFileManager(applicationSupportDirectory: tempDirectory)
        let applicationsProvider = InstalledApplicationsProvider(fileManager: fileManager)
        dataStore = LaunchyDataStore(
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

    override func tearDown() async throws {
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

    func testAddSelectedAppsMovesAppsIntoFolder() throws {
        let appAlpha = makeAppIcon(name: "Alpha", bundleIdentifier: "com.test.alpha")
        let appBeta = makeAppIcon(name: "Beta", bundleIdentifier: "com.test.beta")
        let existingApp = makeAppIcon(name: "Console", bundleIdentifier: "com.test.console")
        let utilitiesFolder = LaunchyFolder(name: "Utilities", apps: [existingApp])

        let initialItems: [LaunchyItem] = [
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
        let viewModel = LaunchyViewModel(
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

    // MARK: - extractDraggedItemIfNeeded Tests

    func testExtractDraggedItemFromFolderWithMultipleApps() throws {
        let appA = makeAppIcon(name: "AppA", bundleIdentifier: "com.test.a")
        let appB = makeAppIcon(name: "AppB", bundleIdentifier: "com.test.b")
        let appC = makeAppIcon(name: "AppC", bundleIdentifier: "com.test.c")
        let appD = makeAppIcon(name: "AppD", bundleIdentifier: "com.test.d")
        let folder = LaunchyFolder(name: "Tools", apps: [appA, appB, appC])

        let initialItems: [LaunchyItem] = [
            .app(appD),
            .folder(folder),
        ]

        let viewModel = makeViewModel(initialItems: initialItems)

        // Simulate dragging appB out of the folder
        viewModel.beginDrag(for: appB.id, sourceFolder: folder.id)
        viewModel.extractDraggedItemIfNeeded()

        // The dragged app should now be a top-level item
        XCTAssertTrue(
            viewModel.items.contains(where: { $0.id == appB.id && $0.asApp != nil }),
            "Extracted app should appear as a top-level item"
        )

        // The folder should still exist with the remaining 2 apps
        guard let updatedFolder = viewModel.folder(by: folder.id) else {
            XCTFail("Folder should still exist when it has 2+ apps remaining")
            return
        }
        XCTAssertEqual(updatedFolder.apps.count, 2)
        XCTAssertTrue(updatedFolder.apps.contains(where: { $0.id == appA.id }))
        XCTAssertTrue(updatedFolder.apps.contains(where: { $0.id == appC.id }))
        XCTAssertFalse(updatedFolder.apps.contains(where: { $0.id == appB.id }))

        // dragSourceFolderID should be cleared since the item is now top-level
        XCTAssertNil(viewModel.dragSourceFolderID)
    }

    func testExtractDraggedItemDisbandsFolderWhenOneAppLeft() throws {
        let appA = makeAppIcon(name: "AppA", bundleIdentifier: "com.test.a")
        let appB = makeAppIcon(name: "AppB", bundleIdentifier: "com.test.b")
        let appC = makeAppIcon(name: "AppC", bundleIdentifier: "com.test.c")
        let folder = LaunchyFolder(name: "Duo", apps: [appA, appB])

        let initialItems: [LaunchyItem] = [
            .app(appC),
            .folder(folder),
        ]

        let viewModel = makeViewModel(initialItems: initialItems)

        // Simulate dragging appA out of the folder (leaves only appB)
        viewModel.beginDrag(for: appA.id, sourceFolder: folder.id)
        viewModel.extractDraggedItemIfNeeded()

        // The folder should be disbanded since only 1 app would remain
        XCTAssertNil(
            viewModel.folder(by: folder.id),
            "Folder should be disbanded when only 1 app remains"
        )

        // Both apps from the folder should now be top-level items
        XCTAssertTrue(
            viewModel.items.contains(where: { $0.id == appA.id && $0.asApp != nil }),
            "Dragged app should be a top-level item"
        )
        XCTAssertTrue(
            viewModel.items.contains(where: { $0.id == appB.id && $0.asApp != nil }),
            "Remaining app should be promoted to top-level after folder disband"
        )

        // The original non-folder app should still be present
        XCTAssertTrue(viewModel.items.contains(where: { $0.id == appC.id }))

        // No folders should remain
        XCTAssertFalse(viewModel.items.contains(where: { $0.isFolder }))
    }

    func testExtractDraggedItemDisbandsFolderWhenZeroAppsLeft() throws {
        let appA = makeAppIcon(name: "AppA", bundleIdentifier: "com.test.a")
        let folder = LaunchyFolder(name: "Solo", apps: [appA])

        let initialItems: [LaunchyItem] = [
            .folder(folder)
        ]

        let viewModel = makeViewModel(initialItems: initialItems)

        // Simulate dragging the only app out of the folder
        viewModel.beginDrag(for: appA.id, sourceFolder: folder.id)
        viewModel.extractDraggedItemIfNeeded()

        // The folder should be gone
        XCTAssertNil(viewModel.folder(by: folder.id))

        // The app should be top-level
        XCTAssertTrue(viewModel.items.contains(where: { $0.id == appA.id && $0.asApp != nil }))
        XCTAssertEqual(viewModel.items.count, 1)
    }

    func testExtractDraggedItemNoOpWhenAlreadyTopLevel() throws {
        let appA = makeAppIcon(name: "AppA", bundleIdentifier: "com.test.a")
        let appB = makeAppIcon(name: "AppB", bundleIdentifier: "com.test.b")

        let initialItems: [LaunchyItem] = [
            .app(appA),
            .app(appB),
        ]

        let viewModel = makeViewModel(initialItems: initialItems)

        // Begin a drag for a top-level item (no source folder)
        viewModel.beginDrag(for: appA.id)
        viewModel.extractDraggedItemIfNeeded()

        // Items should be unchanged
        XCTAssertEqual(viewModel.items.count, 2)
        XCTAssertTrue(viewModel.items.contains(where: { $0.id == appA.id }))
        XCTAssertTrue(viewModel.items.contains(where: { $0.id == appB.id }))
    }

    func testExtractDraggedItemNoOpWhenNoDragActive() throws {
        let appA = makeAppIcon(name: "AppA", bundleIdentifier: "com.test.a")

        let initialItems: [LaunchyItem] = [
            .app(appA)
        ]

        let viewModel = makeViewModel(initialItems: initialItems)

        // No drag in progress — should be a no-op
        viewModel.extractDraggedItemIfNeeded()

        XCTAssertEqual(viewModel.items.count, 1)
    }

    func testExtractDraggedItemIdempotentWhenCalledTwice() throws {
        let appA = makeAppIcon(name: "AppA", bundleIdentifier: "com.test.a")
        let appB = makeAppIcon(name: "AppB", bundleIdentifier: "com.test.b")
        let appC = makeAppIcon(name: "AppC", bundleIdentifier: "com.test.c")
        let folder = LaunchyFolder(name: "Tools", apps: [appA, appB, appC])

        let initialItems: [LaunchyItem] = [
            .folder(folder)
        ]

        let viewModel = makeViewModel(initialItems: initialItems)

        viewModel.beginDrag(for: appA.id, sourceFolder: folder.id)
        viewModel.extractDraggedItemIfNeeded()

        let itemsAfterFirst = viewModel.items

        // Calling again should be a no-op (app is already top-level)
        viewModel.extractDraggedItemIfNeeded()

        XCTAssertEqual(viewModel.items, itemsAfterFirst, "Second call should be a no-op")
    }

    func testExtractDraggedItemPreservesOrderOfOtherItems() throws {
        let appA = makeAppIcon(name: "AppA", bundleIdentifier: "com.test.a")
        let appB = makeAppIcon(name: "AppB", bundleIdentifier: "com.test.b")
        let appC = makeAppIcon(name: "AppC", bundleIdentifier: "com.test.c")
        let appD = makeAppIcon(name: "AppD", bundleIdentifier: "com.test.d")
        let folder = LaunchyFolder(name: "Tools", apps: [appA, appB, appC])

        let initialItems: [LaunchyItem] = [
            .app(appD),
            .folder(folder),
        ]

        let viewModel = makeViewModel(initialItems: initialItems)

        viewModel.beginDrag(for: appB.id, sourceFolder: folder.id)
        viewModel.extractDraggedItemIfNeeded()

        // appD should still be at position 0
        XCTAssertEqual(viewModel.items[0].id, appD.id)

        // The folder should be at position 1 (with appA, appC)
        XCTAssertEqual(viewModel.items[1].id, folder.id)

        // The extracted app should be right after the folder
        XCTAssertEqual(viewModel.items[2].id, appB.id)
    }

    // MARK: - Helpers

    private func makeViewModel(initialItems: [LaunchyItem]) -> LaunchyViewModel {
        dataStore.save(initialItems)
        let settingsStore = GridSettingsStore(defaults: userDefaults)
        return LaunchyViewModel(
            dataStore: dataStore,
            settingsStore: settingsStore,
            initialItems: initialItems
        )
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
