import XCTest

@testable import Launchy

@MainActor
final class DragCoordinatorTests: XCTestCase {
    private var tempDirectory: URL!
    private var fileManager: StubFileManager!
    private var dataStore: LaunchyDataStore!
    private var userDefaults: UserDefaults!
    private var userDefaultsSuiteName: String!

    override func setUp() async throws {
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "DragCoordinatorTests-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )

        fileManager = StubFileManager(applicationSupportDirectory: tempDirectory)
        let applicationsProvider = InstalledApplicationsProvider(fileManager: fileManager)
        dataStore = LaunchyDataStore(
            fileManager: fileManager,
            applicationsProvider: applicationsProvider
        )

        let suiteName = "DragCoordinatorTests-\(UUID().uuidString)"
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

    // MARK: - Tests

    /// Verifies that `beginDrag` sets `dragItemID` and `dragSourceFolderID`.
    func testBeginDragSetsState() throws {
        let appA = makeAppIcon(name: "AppA", bundleIdentifier: "com.test.a")
        let appB = makeAppIcon(name: "AppB", bundleIdentifier: "com.test.b")
        let folder = LaunchyFolder(name: "Folder", apps: [appB])

        let viewModel = makeViewModel(initialItems: [
            .app(appA),
            .folder(folder),
        ])

        // Drag a top-level app — no source folder
        viewModel.beginDrag(for: appA.id)
        XCTAssertEqual(viewModel.dragItemID, appA.id)
        XCTAssertNil(viewModel.dragSourceFolderID)

        // End and start a new drag from inside a folder
        viewModel.endDrag(commit: false)
        viewModel.beginDrag(for: appB.id, sourceFolder: folder.id)
        XCTAssertEqual(viewModel.dragItemID, appB.id)
        XCTAssertEqual(viewModel.dragSourceFolderID, folder.id)
    }

    /// Verifies that `endDrag` clears all drag-related state.
    func testEndDragClearsDragState() throws {
        let appA = makeAppIcon(name: "AppA", bundleIdentifier: "com.test.a")

        let viewModel = makeViewModel(initialItems: [.app(appA)])

        viewModel.beginDrag(for: appA.id)
        XCTAssertNotNil(viewModel.dragItemID)

        viewModel.endDrag(commit: false)

        XCTAssertNil(viewModel.dragItemID)
        XCTAssertNil(viewModel.dragSourceFolderID)
        XCTAssertNil(viewModel.pendingStackTargetID)
    }

    /// Verifies that `endDrag(commit: true)` persists the current layout.
    func testEndDragWithCommitSaves() throws {
        let appA = makeAppIcon(name: "AppA", bundleIdentifier: "com.test.a")
        let appB = makeAppIcon(name: "AppB", bundleIdentifier: "com.test.b")

        let viewModel = makeViewModel(initialItems: [
            .app(appA),
            .app(appB),
        ])

        viewModel.beginDrag(for: appA.id)

        // Manually reorder to simulate a drag move
        viewModel.items = [.app(appB), .app(appA)]
        viewModel.endDrag(commit: true)

        // Read the raw persisted JSON to verify saveNow() wrote to disk.
        // We avoid dataStore.load() because it reconciles against installed
        // apps (which are empty in the stub environment).
        let storageURL =
            tempDirectory
            .appendingPathComponent("Launchy", isDirectory: true)
            .appendingPathComponent("launchy-data.json")
        let data = try Data(contentsOf: storageURL)
        let persisted = try JSONDecoder().decode([LaunchyItem].self, from: data)

        XCTAssertEqual(persisted.count, 2)
        XCTAssertEqual(persisted.first?.id, appB.id)
        XCTAssertEqual(persisted.last?.id, appA.id)
    }

    /// Verifies that extracting a dragged item from a folder promotes it to the
    /// top-level grid and removes it from the source folder.
    func testExtractDraggedItemFromFolder() throws {
        let appA = makeAppIcon(name: "AppA", bundleIdentifier: "com.test.a")
        let appB = makeAppIcon(name: "AppB", bundleIdentifier: "com.test.b")
        let appC = makeAppIcon(name: "AppC", bundleIdentifier: "com.test.c")
        let folder = LaunchyFolder(name: "Tools", apps: [appA, appB, appC])

        let viewModel = makeViewModel(initialItems: [.folder(folder)])

        viewModel.beginDrag(for: appB.id, sourceFolder: folder.id)
        viewModel.extractDraggedItemIfNeeded()

        // appB should now be a top-level item
        XCTAssertTrue(
            viewModel.items.contains(where: { $0.id == appB.id && $0.asApp != nil }),
            "Extracted app should appear as a top-level item"
        )

        // Source folder should still exist with the remaining two apps
        guard let updatedFolder = viewModel.folder(by: folder.id) else {
            XCTFail("Folder should still exist when 2+ apps remain")
            return
        }
        XCTAssertEqual(updatedFolder.apps.count, 2)
        XCTAssertFalse(updatedFolder.apps.contains(where: { $0.id == appB.id }))

        // dragSourceFolderID should be cleared since the item is now top-level
        XCTAssertNil(viewModel.dragSourceFolderID)
    }

    /// Verifies that extraction is a no-op when the dragged item is already
    /// a top-level item (no source folder).
    func testExtractDraggedItemNoOpWhenTopLevel() throws {
        let appA = makeAppIcon(name: "AppA", bundleIdentifier: "com.test.a")
        let appB = makeAppIcon(name: "AppB", bundleIdentifier: "com.test.b")

        let viewModel = makeViewModel(initialItems: [
            .app(appA),
            .app(appB),
        ])

        viewModel.beginDrag(for: appA.id)
        viewModel.extractDraggedItemIfNeeded()

        XCTAssertEqual(viewModel.items.count, 2)
        XCTAssertTrue(viewModel.items.contains(where: { $0.id == appA.id }))
        XCTAssertTrue(viewModel.items.contains(where: { $0.id == appB.id }))
    }

    /// Verifies that `requestStacking` sets the `pendingStackTargetID` after
    /// the internal delay elapses.
    func testRequestStackingSetsTargetAfterDelay() throws {
        let appA = makeAppIcon(name: "AppA", bundleIdentifier: "com.test.a")
        let appB = makeAppIcon(name: "AppB", bundleIdentifier: "com.test.b")

        let viewModel = makeViewModel(initialItems: [
            .app(appA),
            .app(appB),
        ])

        viewModel.beginDrag(for: appA.id)
        viewModel.requestStacking(onto: appB.id)

        // The pending target should be set immediately (task is scheduled)
        XCTAssertEqual(viewModel.pendingStackTargetID, appB.id)
    }

    /// Verifies that `cancelPendingStacking` clears `pendingStackTargetID`.
    func testCancelPendingStackingClearsTarget() throws {
        let appA = makeAppIcon(name: "AppA", bundleIdentifier: "com.test.a")
        let appB = makeAppIcon(name: "AppB", bundleIdentifier: "com.test.b")

        let viewModel = makeViewModel(initialItems: [
            .app(appA),
            .app(appB),
        ])

        viewModel.beginDrag(for: appA.id)
        viewModel.requestStacking(onto: appB.id)
        XCTAssertEqual(viewModel.pendingStackTargetID, appB.id)

        viewModel.cancelPendingStacking()
        XCTAssertNil(viewModel.pendingStackTargetID)
    }

    /// Verifies that stacking a top-level app onto another top-level app
    /// creates a new folder containing both apps.
    func testStackDraggedItemCreatesFolder() throws {
        let appA = makeAppIcon(name: "AppA", bundleIdentifier: "com.test.a")
        let appB = makeAppIcon(name: "AppB", bundleIdentifier: "com.test.b")
        let appC = makeAppIcon(name: "AppC", bundleIdentifier: "com.test.c")

        let viewModel = makeViewModel(initialItems: [
            .app(appA),
            .app(appB),
            .app(appC),
        ])

        viewModel.beginDrag(for: appA.id)
        let result = viewModel.stackDraggedItem(onto: appB.id)

        XCTAssertTrue(result, "Stacking should succeed")

        let folderItems = viewModel.items.filter { $0.isFolder }
        XCTAssertEqual(folderItems.count, 1, "Exactly one folder should exist")

        guard let newFolder = folderItems.first?.asFolder else {
            XCTFail("A new folder should have been created")
            return
        }
        // Folder takes the target app's name
        XCTAssertEqual(newFolder.name, "AppB")
        XCTAssertEqual(newFolder.apps.count, 2)
        XCTAssertTrue(newFolder.apps.contains(where: { $0.id == appA.id }))
        XCTAssertTrue(newFolder.apps.contains(where: { $0.id == appB.id }))

        // The third app should remain as a top-level item
        XCTAssertTrue(viewModel.items.contains(where: { $0.id == appC.id && $0.asApp != nil }))

        // The presented folder should open to the newly created folder
        XCTAssertEqual(viewModel.presentedFolderID, newFolder.id)
    }

    /// Verifies that stacking a top-level app onto an existing folder
    /// adds the app into the folder rather than creating a new one.
    func testStackDraggedItemOntoExistingFolder() throws {
        let appA = makeAppIcon(name: "AppA", bundleIdentifier: "com.test.a")
        let appB = makeAppIcon(name: "AppB", bundleIdentifier: "com.test.b")
        let appC = makeAppIcon(name: "AppC", bundleIdentifier: "com.test.c")
        let folder = LaunchyFolder(name: "Tools", apps: [appB, appC])

        let viewModel = makeViewModel(initialItems: [
            .app(appA),
            .folder(folder),
        ])

        viewModel.beginDrag(for: appA.id)
        let result = viewModel.stackDraggedItem(onto: folder.id)

        XCTAssertTrue(result, "Stacking onto existing folder should succeed")

        // appA should no longer be a top-level item
        XCTAssertFalse(
            viewModel.items.contains(where: { $0.id == appA.id && $0.asApp != nil }),
            "Dragged app should not remain at top level"
        )

        guard let updatedFolder = viewModel.folder(by: folder.id) else {
            XCTFail("The target folder should still exist")
            return
        }
        XCTAssertEqual(updatedFolder.apps.count, 3)
        XCTAssertTrue(updatedFolder.apps.contains(where: { $0.id == appA.id }))
        XCTAssertTrue(updatedFolder.apps.contains(where: { $0.id == appB.id }))
        XCTAssertTrue(updatedFolder.apps.contains(where: { $0.id == appC.id }))
    }

    /// Verifies that `beginDrag` records an undo snapshot so the entire drag
    /// operation can be reversed with a single undo.
    func testBeginDragRecordsUndoSnapshot() throws {
        let appA = makeAppIcon(name: "AppA", bundleIdentifier: "com.test.a")
        let appB = makeAppIcon(name: "AppB", bundleIdentifier: "com.test.b")
        let appC = makeAppIcon(name: "AppC", bundleIdentifier: "com.test.c")

        let viewModel = makeViewModel(initialItems: [
            .app(appA),
            .app(appB),
            .app(appC),
        ])

        XCTAssertFalse(
            viewModel.undoManager.canUndo,
            "No undo should be available before any mutation"
        )

        // Begin a drag — this should record a snapshot
        viewModel.beginDrag(for: appA.id)

        XCTAssertTrue(
            viewModel.undoManager.canUndo,
            "Undo should be available after beginDrag records a snapshot"
        )

        // Perform a stacking operation to mutate the layout
        let stacked = viewModel.stackDraggedItem(onto: appB.id)
        XCTAssertTrue(stacked)

        viewModel.endDrag(commit: true)

        // There should now be a folder and appC at top level
        let folderCount = viewModel.items.filter { $0.isFolder }.count
        XCTAssertEqual(folderCount, 1)

        // Undo should restore the original three top-level apps
        viewModel.undo()

        XCTAssertEqual(viewModel.items.count, 3)
        XCTAssertTrue(viewModel.items.contains(where: { $0.id == appA.id && $0.asApp != nil }))
        XCTAssertTrue(viewModel.items.contains(where: { $0.id == appB.id && $0.asApp != nil }))
        XCTAssertTrue(viewModel.items.contains(where: { $0.id == appC.id && $0.asApp != nil }))
        XCTAssertFalse(
            viewModel.items.contains(where: { $0.isFolder }),
            "After undo, no folders should exist"
        )
    }

    // MARK: - Helpers

    /// Creates a `LaunchyViewModel` seeded with the given items, using
    /// test-scoped persistence so tests are isolated from each other.
    private func makeViewModel(initialItems: [LaunchyItem]) -> LaunchyViewModel {
        dataStore.save(initialItems)
        let settingsStore = GridSettingsStore(defaults: userDefaults)
        return LaunchyViewModel(
            dataStore: dataStore,
            settingsStore: settingsStore,
            initialItems: initialItems
        )
    }

    /// Creates an `AppIcon` with the given name and bundle identifier,
    /// pointing at a synthetic `/Applications/<name>.app` path.
    private func makeAppIcon(name: String, bundleIdentifier: String) -> AppIcon {
        AppIcon(
            name: name,
            bundleIdentifier: bundleIdentifier,
            bundleURL: URL(fileURLWithPath: "/Applications/\(name).app")
        )
    }
}

// MARK: - StubFileManager

/// A `FileManager` subclass that redirects Application Support queries to a
/// temporary directory and blocks real `/Applications` paths so tests never
/// touch the host system.
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
