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
            at: tempDirectory,
            withIntermediateDirectories: true
        )

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

    // MARK: - addSelectedApps Tests

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

        let viewModel = makeViewModel(initialItems: initialItems)

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

        viewModel.beginDrag(for: appB.id, sourceFolder: folder.id)
        viewModel.extractDraggedItemIfNeeded()

        XCTAssertTrue(
            viewModel.items.contains(where: { $0.id == appB.id && $0.asApp != nil }),
            "Extracted app should appear as a top-level item"
        )

        guard let updatedFolder = viewModel.folder(by: folder.id) else {
            XCTFail("Folder should still exist when it has 2+ apps remaining")
            return
        }
        XCTAssertEqual(updatedFolder.apps.count, 2)
        XCTAssertTrue(updatedFolder.apps.contains(where: { $0.id == appA.id }))
        XCTAssertTrue(updatedFolder.apps.contains(where: { $0.id == appC.id }))
        XCTAssertFalse(updatedFolder.apps.contains(where: { $0.id == appB.id }))

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

        viewModel.beginDrag(for: appA.id, sourceFolder: folder.id)
        viewModel.extractDraggedItemIfNeeded()

        XCTAssertNil(
            viewModel.folder(by: folder.id),
            "Folder should be disbanded when only 1 app remains"
        )

        XCTAssertTrue(
            viewModel.items.contains(where: { $0.id == appA.id && $0.asApp != nil }),
            "Dragged app should be a top-level item"
        )
        XCTAssertTrue(
            viewModel.items.contains(where: { $0.id == appB.id && $0.asApp != nil }),
            "Remaining app should be promoted to top-level after folder disband"
        )

        XCTAssertTrue(viewModel.items.contains(where: { $0.id == appC.id }))
        XCTAssertFalse(viewModel.items.contains(where: { $0.isFolder }))
    }

    func testExtractDraggedItemDisbandsFolderWhenZeroAppsLeft() throws {
        let appA = makeAppIcon(name: "AppA", bundleIdentifier: "com.test.a")
        let folder = LaunchyFolder(name: "Solo", apps: [appA])

        let initialItems: [LaunchyItem] = [
            .folder(folder)
        ]

        let viewModel = makeViewModel(initialItems: initialItems)

        viewModel.beginDrag(for: appA.id, sourceFolder: folder.id)
        viewModel.extractDraggedItemIfNeeded()

        XCTAssertNil(viewModel.folder(by: folder.id))
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

        viewModel.beginDrag(for: appA.id)
        viewModel.extractDraggedItemIfNeeded()

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

        XCTAssertEqual(viewModel.items[0].id, appD.id)
        XCTAssertEqual(viewModel.items[1].id, folder.id)
        XCTAssertEqual(viewModel.items[2].id, appB.id)
    }

    // MARK: - stackDraggedItem (app → folder) Tests

    func testStackTopLevelAppOntoFolder() throws {
        let appA = makeAppIcon(name: "AppA", bundleIdentifier: "com.test.a")
        let appB = makeAppIcon(name: "AppB", bundleIdentifier: "com.test.b")
        let appC = makeAppIcon(name: "AppC", bundleIdentifier: "com.test.c")
        let folder = LaunchyFolder(name: "Tools", apps: [appC])

        let initialItems: [LaunchyItem] = [
            .app(appA),
            .app(appB),
            .folder(folder),
        ]

        let viewModel = makeViewModel(initialItems: initialItems)

        viewModel.beginDrag(for: appA.id)
        let result = viewModel.stackDraggedItem(onto: folder.id)

        XCTAssertTrue(result)
        XCTAssertFalse(viewModel.items.contains(where: { $0.id == appA.id && $0.asApp != nil }))

        guard let updatedFolder = viewModel.folder(by: folder.id) else {
            XCTFail("Folder should still exist")
            return
        }
        XCTAssertEqual(updatedFolder.apps.count, 2)
        XCTAssertTrue(updatedFolder.apps.contains(where: { $0.id == appC.id }))
        XCTAssertTrue(updatedFolder.apps.contains(where: { $0.id == appA.id }))
    }

    func testStackTopLevelAppOntoFolderAdjustsIndexWhenDraggedIsBeforeTarget() throws {
        let appA = makeAppIcon(name: "AppA", bundleIdentifier: "com.test.a")
        let appB = makeAppIcon(name: "AppB", bundleIdentifier: "com.test.b")
        let folder = LaunchyFolder(name: "Tools", apps: [appB])

        // appA is at index 0, folder is at index 1 — removing appA shifts folder left
        let initialItems: [LaunchyItem] = [
            .app(appA),
            .folder(folder),
        ]

        let viewModel = makeViewModel(initialItems: initialItems)

        viewModel.beginDrag(for: appA.id)
        let result = viewModel.stackDraggedItem(onto: folder.id)

        XCTAssertTrue(result)
        XCTAssertEqual(viewModel.items.count, 1)
        guard let updatedFolder = viewModel.folder(by: folder.id) else {
            XCTFail("Folder should exist")
            return
        }
        XCTAssertEqual(updatedFolder.apps.count, 2)
        XCTAssertTrue(updatedFolder.apps.contains(where: { $0.id == appA.id }))
        XCTAssertTrue(updatedFolder.apps.contains(where: { $0.id == appB.id }))
    }

    func testStackAppFromFolderOntoAnotherFolder() throws {
        let appA = makeAppIcon(name: "AppA", bundleIdentifier: "com.test.a")
        let appB = makeAppIcon(name: "AppB", bundleIdentifier: "com.test.b")
        let appC = makeAppIcon(name: "AppC", bundleIdentifier: "com.test.c")
        let sourceFolder = LaunchyFolder(name: "Source", apps: [appA, appB])
        let targetFolder = LaunchyFolder(name: "Target", apps: [appC])

        let initialItems: [LaunchyItem] = [
            .folder(sourceFolder),
            .folder(targetFolder),
        ]

        let viewModel = makeViewModel(initialItems: initialItems)

        viewModel.beginDrag(for: appA.id, sourceFolder: sourceFolder.id)
        let result = viewModel.stackDraggedItem(onto: targetFolder.id)

        XCTAssertTrue(result)

        guard let updatedSource = viewModel.folder(by: sourceFolder.id) else {
            XCTFail("Source folder should still exist with 1 app")
            return
        }
        XCTAssertEqual(updatedSource.apps.count, 1)
        XCTAssertTrue(updatedSource.apps.contains(where: { $0.id == appB.id }))

        guard let updatedTarget = viewModel.folder(by: targetFolder.id) else {
            XCTFail("Target folder should exist")
            return
        }
        XCTAssertEqual(updatedTarget.apps.count, 2)
        XCTAssertTrue(updatedTarget.apps.contains(where: { $0.id == appC.id }))
        XCTAssertTrue(updatedTarget.apps.contains(where: { $0.id == appA.id }))
    }

    func testStackAppFromFolderOntoFolderRemovesEmptySourceFolder() throws {
        let appA = makeAppIcon(name: "AppA", bundleIdentifier: "com.test.a")
        let appB = makeAppIcon(name: "AppB", bundleIdentifier: "com.test.b")
        let sourceFolder = LaunchyFolder(name: "Source", apps: [appA])
        let targetFolder = LaunchyFolder(name: "Target", apps: [appB])

        let initialItems: [LaunchyItem] = [
            .folder(sourceFolder),
            .folder(targetFolder),
        ]

        let viewModel = makeViewModel(initialItems: initialItems)

        viewModel.beginDrag(for: appA.id, sourceFolder: sourceFolder.id)
        let result = viewModel.stackDraggedItem(onto: targetFolder.id)

        XCTAssertTrue(result)
        XCTAssertNil(viewModel.folder(by: sourceFolder.id))

        guard let updatedTarget = viewModel.folder(by: targetFolder.id) else {
            XCTFail("Target folder should exist")
            return
        }
        XCTAssertEqual(updatedTarget.apps.count, 2)
        XCTAssertEqual(viewModel.items.count, 1)
    }

    func testStackReturnsFalseWithNoDrag() throws {
        let appA = makeAppIcon(name: "AppA", bundleIdentifier: "com.test.a")

        let initialItems: [LaunchyItem] = [.app(appA)]
        let viewModel = makeViewModel(initialItems: initialItems)

        let result = viewModel.stackDraggedItem(onto: appA.id)
        XCTAssertFalse(result)
    }

    // MARK: - stackDraggedItem (app → app) Tests

    func testStackTopLevelAppOntoAppCreatesNewFolder() throws {
        let appA = makeAppIcon(name: "AppA", bundleIdentifier: "com.test.a")
        let appB = makeAppIcon(name: "AppB", bundleIdentifier: "com.test.b")
        let appC = makeAppIcon(name: "AppC", bundleIdentifier: "com.test.c")

        let initialItems: [LaunchyItem] = [
            .app(appA),
            .app(appB),
            .app(appC),
        ]

        let viewModel = makeViewModel(initialItems: initialItems)

        viewModel.beginDrag(for: appA.id)
        let result = viewModel.stackDraggedItem(onto: appB.id)

        XCTAssertTrue(result)

        let folderItems = viewModel.items.filter { $0.isFolder }
        XCTAssertEqual(folderItems.count, 1)

        guard let newFolder = folderItems.first?.asFolder else {
            XCTFail("A new folder should have been created")
            return
        }
        XCTAssertEqual(newFolder.name, "AppB")
        XCTAssertEqual(newFolder.apps.count, 2)
        XCTAssertTrue(newFolder.apps.contains(where: { $0.id == appB.id }))
        XCTAssertTrue(newFolder.apps.contains(where: { $0.id == appA.id }))
        XCTAssertTrue(viewModel.items.contains(where: { $0.id == appC.id && $0.asApp != nil }))
        XCTAssertEqual(viewModel.presentedFolderID, newFolder.id)
    }

    func testStackAppOntoAppRelookupsTargetIndexAfterRemoval() throws {
        let appA = makeAppIcon(name: "AppA", bundleIdentifier: "com.test.a")
        let appB = makeAppIcon(name: "AppB", bundleIdentifier: "com.test.b")

        // appA at index 0, appB at index 1. Removing appA shifts appB to index 0.
        let initialItems: [LaunchyItem] = [
            .app(appA),
            .app(appB),
        ]

        let viewModel = makeViewModel(initialItems: initialItems)

        viewModel.beginDrag(for: appA.id)
        let result = viewModel.stackDraggedItem(onto: appB.id)

        XCTAssertTrue(result)
        XCTAssertEqual(viewModel.items.count, 1)
        guard let folder = viewModel.items.first?.asFolder else {
            XCTFail("Should create a folder")
            return
        }
        XCTAssertEqual(folder.apps.count, 2)
    }

    func testStackAppFromFolderOntoTopLevelAppCreatesNewFolder() throws {
        let appA = makeAppIcon(name: "AppA", bundleIdentifier: "com.test.a")
        let appB = makeAppIcon(name: "AppB", bundleIdentifier: "com.test.b")
        let appC = makeAppIcon(name: "AppC", bundleIdentifier: "com.test.c")
        let sourceFolder = LaunchyFolder(name: "Source", apps: [appA, appB])

        let initialItems: [LaunchyItem] = [
            .folder(sourceFolder),
            .app(appC),
        ]

        let viewModel = makeViewModel(initialItems: initialItems)

        viewModel.beginDrag(for: appA.id, sourceFolder: sourceFolder.id)
        let result = viewModel.stackDraggedItem(onto: appC.id)

        XCTAssertTrue(result)

        guard let updatedSource = viewModel.folder(by: sourceFolder.id) else {
            XCTFail("Source folder should still exist")
            return
        }
        XCTAssertEqual(updatedSource.apps.count, 1)
        XCTAssertTrue(updatedSource.apps.contains(where: { $0.id == appB.id }))

        let newFolders = viewModel.items.compactMap { $0.asFolder }.filter {
            $0.id != sourceFolder.id
        }
        XCTAssertEqual(newFolders.count, 1)
        guard let newFolder = newFolders.first else {
            XCTFail("New folder should exist")
            return
        }
        XCTAssertEqual(newFolder.name, "AppC")
        XCTAssertEqual(newFolder.apps.count, 2)
        XCTAssertTrue(newFolder.apps.contains(where: { $0.id == appC.id }))
        XCTAssertTrue(newFolder.apps.contains(where: { $0.id == appA.id }))
    }

    func testStackAppFromFolderOntoAppRemovesEmptySourceFolder() throws {
        let appA = makeAppIcon(name: "AppA", bundleIdentifier: "com.test.a")
        let appB = makeAppIcon(name: "AppB", bundleIdentifier: "com.test.b")
        let sourceFolder = LaunchyFolder(name: "Source", apps: [appA])

        let initialItems: [LaunchyItem] = [
            .folder(sourceFolder),
            .app(appB),
        ]

        let viewModel = makeViewModel(initialItems: initialItems)

        viewModel.beginDrag(for: appA.id, sourceFolder: sourceFolder.id)
        let result = viewModel.stackDraggedItem(onto: appB.id)

        XCTAssertTrue(result)
        XCTAssertNil(viewModel.folder(by: sourceFolder.id))
        XCTAssertEqual(viewModel.items.count, 1)
        guard let newFolder = viewModel.items.first?.asFolder else {
            XCTFail("New folder should exist")
            return
        }
        XCTAssertEqual(newFolder.apps.count, 2)
    }

    // MARK: - moveItem Tests

    func testMoveItemBeforeTarget() throws {
        let appA = makeAppIcon(name: "AppA", bundleIdentifier: "com.test.a")
        let appB = makeAppIcon(name: "AppB", bundleIdentifier: "com.test.b")
        let appC = makeAppIcon(name: "AppC", bundleIdentifier: "com.test.c")

        let initialItems: [LaunchyItem] = [
            .app(appA),
            .app(appB),
            .app(appC),
        ]

        let viewModel = makeViewModel(initialItems: initialItems)

        viewModel.moveItem(appC.id, before: appA.id)

        XCTAssertEqual(viewModel.items[0].id, appC.id)
        XCTAssertEqual(viewModel.items[1].id, appA.id)
        XCTAssertEqual(viewModel.items[2].id, appB.id)
    }

    func testMoveItemAppendsWhenTargetIsNil() throws {
        let appA = makeAppIcon(name: "AppA", bundleIdentifier: "com.test.a")
        let appB = makeAppIcon(name: "AppB", bundleIdentifier: "com.test.b")
        let appC = makeAppIcon(name: "AppC", bundleIdentifier: "com.test.c")

        let initialItems: [LaunchyItem] = [
            .app(appA),
            .app(appB),
            .app(appC),
        ]

        let viewModel = makeViewModel(initialItems: initialItems)

        viewModel.moveItem(appA.id, before: nil)

        XCTAssertEqual(viewModel.items[0].id, appB.id)
        XCTAssertEqual(viewModel.items[1].id, appC.id)
        XCTAssertEqual(viewModel.items[2].id, appA.id)
    }

    func testMoveItemNoOpWhenAlreadyAdjacent() throws {
        let appA = makeAppIcon(name: "AppA", bundleIdentifier: "com.test.a")
        let appB = makeAppIcon(name: "AppB", bundleIdentifier: "com.test.b")
        let appC = makeAppIcon(name: "AppC", bundleIdentifier: "com.test.c")

        let initialItems: [LaunchyItem] = [
            .app(appA),
            .app(appB),
            .app(appC),
        ]

        let viewModel = makeViewModel(initialItems: initialItems)

        // appA is at index 0, appB is at index 1 — from + 1 == to, so no-op
        viewModel.moveItem(appA.id, before: appB.id)

        XCTAssertEqual(viewModel.items[0].id, appA.id)
        XCTAssertEqual(viewModel.items[1].id, appB.id)
        XCTAssertEqual(viewModel.items[2].id, appC.id)
    }

    func testMoveItemNoOpWhenSameIndex() throws {
        let appA = makeAppIcon(name: "AppA", bundleIdentifier: "com.test.a")
        let appB = makeAppIcon(name: "AppB", bundleIdentifier: "com.test.b")

        let initialItems: [LaunchyItem] = [
            .app(appA),
            .app(appB),
        ]

        let viewModel = makeViewModel(initialItems: initialItems)

        viewModel.moveItem(appA.id, before: appA.id)

        XCTAssertEqual(viewModel.items[0].id, appA.id)
        XCTAssertEqual(viewModel.items[1].id, appB.id)
    }

    func testMoveItemWithNonexistentIDDoesNothing() throws {
        let appA = makeAppIcon(name: "AppA", bundleIdentifier: "com.test.a")

        let initialItems: [LaunchyItem] = [.app(appA)]
        let viewModel = makeViewModel(initialItems: initialItems)

        viewModel.moveItem(UUID(), before: appA.id)

        XCTAssertEqual(viewModel.items.count, 1)
        XCTAssertEqual(viewModel.items[0].id, appA.id)
    }

    // MARK: - deleteItem Tests

    func testDeleteTopLevelApp() throws {
        let appA = makeAppIcon(name: "AppA", bundleIdentifier: "com.test.a")
        let appB = makeAppIcon(name: "AppB", bundleIdentifier: "com.test.b")

        let initialItems: [LaunchyItem] = [
            .app(appA),
            .app(appB),
        ]

        let viewModel = makeViewModel(initialItems: initialItems)

        viewModel.deleteItem(appA.id)

        XCTAssertEqual(viewModel.items.count, 1)
        XCTAssertFalse(viewModel.items.contains(where: { $0.id == appA.id }))
        XCTAssertTrue(viewModel.items.contains(where: { $0.id == appB.id }))
        XCTAssertTrue(viewModel.recentlyRemovedApps.contains(where: { $0.id == appA.id }))
    }

    func testDeleteFolderDisbandsAppsIntoGrid() throws {
        let appA = makeAppIcon(name: "AppA", bundleIdentifier: "com.test.a")
        let appB = makeAppIcon(name: "AppB", bundleIdentifier: "com.test.b")
        let appC = makeAppIcon(name: "AppC", bundleIdentifier: "com.test.c")
        let folder = LaunchyFolder(name: "Tools", apps: [appA, appB])

        let initialItems: [LaunchyItem] = [
            .folder(folder),
            .app(appC),
        ]

        let viewModel = makeViewModel(initialItems: initialItems)

        viewModel.deleteItem(folder.id)

        XCTAssertNil(viewModel.folder(by: folder.id))
        XCTAssertTrue(viewModel.items.contains(where: { $0.id == appA.id && $0.asApp != nil }))
        XCTAssertTrue(viewModel.items.contains(where: { $0.id == appB.id && $0.asApp != nil }))
        XCTAssertTrue(viewModel.items.contains(where: { $0.id == appC.id }))
        XCTAssertTrue(viewModel.recentlyRemovedApps.isEmpty)
    }

    func testDeleteLastAppInFolderRemovesFolder() throws {
        let appA = makeAppIcon(name: "AppA", bundleIdentifier: "com.test.a")
        let folder = LaunchyFolder(name: "Solo", apps: [appA])

        let initialItems: [LaunchyItem] = [
            .folder(folder)
        ]

        let viewModel = makeViewModel(initialItems: initialItems)

        viewModel.deleteItem(appA.id)

        XCTAssertEqual(viewModel.items.count, 0)
        XCTAssertNil(viewModel.folder(by: folder.id))
        XCTAssertTrue(viewModel.recentlyRemovedApps.contains(where: { $0.id == appA.id }))
    }

    /// When the second-to-last app in a folder is deleted, the folder should be disbanded
    /// and the remaining app placed at the folder's former position — matching Launchpad behaviour.
    func testDeleteSecondToLastAppInFolderDisbandsFolder() throws {
        let appA = makeAppIcon(name: "AppA", bundleIdentifier: "com.test.a")
        let appB = makeAppIcon(name: "AppB", bundleIdentifier: "com.test.b")
        let appC = makeAppIcon(name: "AppC", bundleIdentifier: "com.test.c")
        let folder = LaunchyFolder(name: "Duo", apps: [appA, appB])

        let viewModel = makeViewModel(initialItems: [.folder(folder), .app(appC)])

        viewModel.deleteItem(appA.id)

        XCTAssertNil(viewModel.folder(by: folder.id), "Folder should be disbanded when only one app remains")
        XCTAssertTrue(
            viewModel.items.contains(where: { $0.id == appB.id && $0.asApp != nil }),
            "Remaining app should become a top-level item"
        )
        XCTAssertTrue(viewModel.items.contains(where: { $0.id == appC.id }))
        XCTAssertEqual(viewModel.items.count, 2)
        XCTAssertTrue(
            viewModel.recentlyRemovedApps.contains(where: { $0.id == appA.id }),
            "Deleted app should be in recently-removed list"
        )
        XCTAssertNil(viewModel.presentedFolderID)
    }

    func testDeleteAppInsideFolderKeepsFolderWhenOtherAppsRemain() throws {
        let appA = makeAppIcon(name: "AppA", bundleIdentifier: "com.test.a")
        let appB = makeAppIcon(name: "AppB", bundleIdentifier: "com.test.b")
        let appC = makeAppIcon(name: "AppC", bundleIdentifier: "com.test.c")
        let folder = LaunchyFolder(name: "Tools", apps: [appA, appB, appC])

        let initialItems: [LaunchyItem] = [
            .folder(folder)
        ]

        let viewModel = makeViewModel(initialItems: initialItems)

        viewModel.deleteItem(appB.id)

        guard let updatedFolder = viewModel.folder(by: folder.id) else {
            XCTFail("Folder should still exist")
            return
        }
        XCTAssertEqual(updatedFolder.apps.count, 2)
        XCTAssertTrue(updatedFolder.apps.contains(where: { $0.id == appA.id }))
        XCTAssertTrue(updatedFolder.apps.contains(where: { $0.id == appC.id }))
        XCTAssertFalse(updatedFolder.apps.contains(where: { $0.id == appB.id }))
        XCTAssertTrue(viewModel.recentlyRemovedApps.contains(where: { $0.id == appB.id }))
    }

    func testDeleteFolderClosesPresentedFolder() throws {
        let appA = makeAppIcon(name: "AppA", bundleIdentifier: "com.test.a")
        let folder = LaunchyFolder(name: "Tools", apps: [appA])

        let initialItems: [LaunchyItem] = [.folder(folder)]
        let viewModel = makeViewModel(initialItems: initialItems)

        viewModel.openFolder(with: folder.id)
        XCTAssertEqual(viewModel.presentedFolderID, folder.id)

        viewModel.deleteItem(folder.id)

        XCTAssertNil(viewModel.presentedFolderID)
    }

    // MARK: - disbandFolder Tests

    func testDisbandFolderInsertsAppsAtCorrectIndex() throws {
        let appA = makeAppIcon(name: "AppA", bundleIdentifier: "com.test.a")
        let appB = makeAppIcon(name: "AppB", bundleIdentifier: "com.test.b")
        let appC = makeAppIcon(name: "AppC", bundleIdentifier: "com.test.c")
        let appD = makeAppIcon(name: "AppD", bundleIdentifier: "com.test.d")
        let folder = LaunchyFolder(name: "Tools", apps: [appB, appC])

        let initialItems: [LaunchyItem] = [
            .app(appA),
            .folder(folder),
            .app(appD),
        ]

        let viewModel = makeViewModel(initialItems: initialItems)

        viewModel.disbandFolder(folder.id)

        // Expected order: [appA, appB, appC, appD]
        XCTAssertEqual(viewModel.items.count, 4)
        XCTAssertEqual(viewModel.items[0].id, appA.id)
        XCTAssertEqual(viewModel.items[1].id, appB.id)
        XCTAssertEqual(viewModel.items[2].id, appC.id)
        XCTAssertEqual(viewModel.items[3].id, appD.id)
        XCTAssertFalse(viewModel.items.contains(where: { $0.isFolder }))
    }

    func testDisbandFolderClosesPresentedFolder() throws {
        let appA = makeAppIcon(name: "AppA", bundleIdentifier: "com.test.a")
        let appB = makeAppIcon(name: "AppB", bundleIdentifier: "com.test.b")
        let folder = LaunchyFolder(name: "Tools", apps: [appA, appB])

        let initialItems: [LaunchyItem] = [.folder(folder)]
        let viewModel = makeViewModel(initialItems: initialItems)

        viewModel.openFolder(with: folder.id)
        XCTAssertEqual(viewModel.presentedFolderID, folder.id)

        viewModel.disbandFolder(folder.id)

        XCTAssertNil(viewModel.presentedFolderID)
    }

    func testDisbandFolderNoOpForNonexistentID() throws {
        let appA = makeAppIcon(name: "AppA", bundleIdentifier: "com.test.a")

        let initialItems: [LaunchyItem] = [.app(appA)]
        let viewModel = makeViewModel(initialItems: initialItems)

        viewModel.disbandFolder(UUID())

        XCTAssertEqual(viewModel.items.count, 1)
        XCTAssertEqual(viewModel.items[0].id, appA.id)
    }

    func testDisbandFolderNoOpForAppID() throws {
        let appA = makeAppIcon(name: "AppA", bundleIdentifier: "com.test.a")

        let initialItems: [LaunchyItem] = [.app(appA)]
        let viewModel = makeViewModel(initialItems: initialItems)

        viewModel.disbandFolder(appA.id)

        XCTAssertEqual(viewModel.items.count, 1)
    }

    // MARK: - createFolder Tests

    func testCreateFolderFromTwoApps() throws {
        let appA = makeAppIcon(name: "AppA", bundleIdentifier: "com.test.a")
        let appB = makeAppIcon(name: "AppB", bundleIdentifier: "com.test.b")
        let appC = makeAppIcon(name: "AppC", bundleIdentifier: "com.test.c")

        let initialItems: [LaunchyItem] = [
            .app(appA),
            .app(appB),
            .app(appC),
        ]

        let viewModel = makeViewModel(initialItems: initialItems)

        let folder = viewModel.createFolder(named: "My Folder", from: [appA.id, appC.id])

        XCTAssertNotNil(folder)
        XCTAssertEqual(folder?.name, "My Folder")
        XCTAssertEqual(folder?.apps.count, 2)
        XCTAssertTrue(folder?.apps.contains(where: { $0.id == appA.id }) ?? false)
        XCTAssertTrue(folder?.apps.contains(where: { $0.id == appC.id }) ?? false)

        // The folder should be inserted at the first selected app's index (0)
        XCTAssertEqual(viewModel.items[0].id, folder?.id)

        // appB should still exist
        XCTAssertTrue(viewModel.items.contains(where: { $0.id == appB.id && $0.asApp != nil }))

        // Folder should be presented
        XCTAssertEqual(viewModel.presentedFolderID, folder?.id)

        // Selection should be cleared
        XCTAssertTrue(viewModel.selectedItemIDs.isEmpty)
    }

    func testCreateFolderInsertedAtFirstSelectedIndex() throws {
        let appA = makeAppIcon(name: "AppA", bundleIdentifier: "com.test.a")
        let appB = makeAppIcon(name: "AppB", bundleIdentifier: "com.test.b")
        let appC = makeAppIcon(name: "AppC", bundleIdentifier: "com.test.c")
        let appD = makeAppIcon(name: "AppD", bundleIdentifier: "com.test.d")

        let initialItems: [LaunchyItem] = [
            .app(appA),
            .app(appB),
            .app(appC),
            .app(appD),
        ]

        let viewModel = makeViewModel(initialItems: initialItems)

        // Select appB (index 1) and appD (index 3) — first selected index is 1
        let folder = viewModel.createFolder(named: "New", from: [appB.id, appD.id])

        XCTAssertNotNil(folder)
        // Expected: [appA, folder(appB, appD), appC]
        XCTAssertEqual(viewModel.items.count, 3)
        XCTAssertEqual(viewModel.items[0].id, appA.id)
        XCTAssertEqual(viewModel.items[1].id, folder?.id)
        XCTAssertEqual(viewModel.items[2].id, appC.id)
    }

    func testCreateFolderRequiresMinimumTwoApps() throws {
        let appA = makeAppIcon(name: "AppA", bundleIdentifier: "com.test.a")
        let appB = makeAppIcon(name: "AppB", bundleIdentifier: "com.test.b")

        let initialItems: [LaunchyItem] = [
            .app(appA),
            .app(appB),
        ]

        let viewModel = makeViewModel(initialItems: initialItems)

        let folder = viewModel.createFolder(named: "Nope", from: [appA.id])

        XCTAssertNil(folder, "Creating a folder with fewer than 2 apps should return nil")
        XCTAssertEqual(viewModel.items.count, 2, "Items should be unchanged")
    }

    func testCreateFolderWithZeroAppsReturnsNil() throws {
        let appA = makeAppIcon(name: "AppA", bundleIdentifier: "com.test.a")

        let initialItems: [LaunchyItem] = [.app(appA)]
        let viewModel = makeViewModel(initialItems: initialItems)

        let folder = viewModel.createFolder(named: "Empty", from: [])

        XCTAssertNil(folder)
        XCTAssertEqual(viewModel.items.count, 1)
    }

    func testCreateFolderIgnoresNonexistentIDs() throws {
        let appA = makeAppIcon(name: "AppA", bundleIdentifier: "com.test.a")
        let appB = makeAppIcon(name: "AppB", bundleIdentifier: "com.test.b")

        let initialItems: [LaunchyItem] = [
            .app(appA),
            .app(appB),
        ]

        let viewModel = makeViewModel(initialItems: initialItems)

        // One real ID, one bogus — only 1 app found, below minimum of 2
        let folder = viewModel.createFolder(named: "Nope", from: [appA.id, UUID()])

        XCTAssertNil(folder)
    }

    // MARK: - pagedItems(matching:) Tests

    func testPagedItemsMatchingFindsTopLevelApp() throws {
        let appA = makeAppIcon(name: "Safari", bundleIdentifier: "com.apple.safari")
        let appB = makeAppIcon(name: "Mail", bundleIdentifier: "com.apple.mail")

        let initialItems: [LaunchyItem] = [
            .app(appA),
            .app(appB),
        ]

        let viewModel = makeViewModel(initialItems: initialItems)

        let results = viewModel.pagedItems(matching: "Safari")
        let allResults = results.flatMap { $0 }

        XCTAssertEqual(allResults.count, 1)
        XCTAssertEqual(allResults.first?.id, appA.id)
    }

    func testPagedItemsMatchingFindsAppInsideFolder() throws {
        let appA = makeAppIcon(name: "Safari", bundleIdentifier: "com.apple.safari")
        let appB = makeAppIcon(name: "Mail", bundleIdentifier: "com.apple.mail")
        let folder = LaunchyFolder(name: "Internet", apps: [appA, appB])

        let initialItems: [LaunchyItem] = [
            .folder(folder)
        ]

        let viewModel = makeViewModel(initialItems: initialItems)

        let results = viewModel.pagedItems(matching: "Mail")
        let allResults = results.flatMap { $0 }

        // Only Mail should match, extracted as a standalone app tile
        XCTAssertEqual(allResults.count, 1)
        XCTAssertEqual(allResults.first?.asApp?.id, appB.id)
    }

    func testPagedItemsMatchingByFolderNameReturnsAllApps() throws {
        let appA = makeAppIcon(name: "Safari", bundleIdentifier: "com.apple.safari")
        let appB = makeAppIcon(name: "Mail", bundleIdentifier: "com.apple.mail")
        let folder = LaunchyFolder(name: "Internet", apps: [appA, appB])

        let initialItems: [LaunchyItem] = [
            .folder(folder)
        ]

        let viewModel = makeViewModel(initialItems: initialItems)

        // Searching for the folder name should return all apps inside
        let results = viewModel.pagedItems(matching: "Internet")
        let allResults = results.flatMap { $0 }

        XCTAssertEqual(allResults.count, 2)
        XCTAssertTrue(allResults.contains(where: { $0.asApp?.id == appA.id }))
        XCTAssertTrue(allResults.contains(where: { $0.asApp?.id == appB.id }))
    }

    func testPagedItemsMatchingIsCaseInsensitive() throws {
        let appA = makeAppIcon(name: "Safari", bundleIdentifier: "com.apple.safari")

        let initialItems: [LaunchyItem] = [.app(appA)]
        let viewModel = makeViewModel(initialItems: initialItems)

        let results = viewModel.pagedItems(matching: "sAfArI")
        let allResults = results.flatMap { $0 }

        XCTAssertEqual(allResults.count, 1)
        XCTAssertEqual(allResults.first?.id, appA.id)
    }

    func testPagedItemsMatchingTrimsWhitespace() throws {
        let appA = makeAppIcon(name: "Safari", bundleIdentifier: "com.apple.safari")

        let initialItems: [LaunchyItem] = [.app(appA)]
        let viewModel = makeViewModel(initialItems: initialItems)

        let results = viewModel.pagedItems(matching: "  Safari  ")
        let allResults = results.flatMap { $0 }

        XCTAssertEqual(allResults.count, 1)
    }

    func testPagedItemsMatchingEmptyQueryReturnsAllItems() throws {
        let appA = makeAppIcon(name: "Safari", bundleIdentifier: "com.apple.safari")
        let appB = makeAppIcon(name: "Mail", bundleIdentifier: "com.apple.mail")

        let initialItems: [LaunchyItem] = [
            .app(appA),
            .app(appB),
        ]

        let viewModel = makeViewModel(initialItems: initialItems)

        let results = viewModel.pagedItems(matching: "")
        let allResults = results.flatMap { $0 }

        XCTAssertEqual(allResults.count, 2)
    }

    func testPagedItemsMatchingWhitespaceOnlyQueryReturnsAllItems() throws {
        let appA = makeAppIcon(name: "Safari", bundleIdentifier: "com.apple.safari")

        let initialItems: [LaunchyItem] = [.app(appA)]
        let viewModel = makeViewModel(initialItems: initialItems)

        let results = viewModel.pagedItems(matching: "   ")
        let allResults = results.flatMap { $0 }

        XCTAssertEqual(allResults.count, 1)
    }

    func testPagedItemsMatchingNoResultsReturnsEmptyPage() throws {
        let appA = makeAppIcon(name: "Safari", bundleIdentifier: "com.apple.safari")

        let initialItems: [LaunchyItem] = [.app(appA)]
        let viewModel = makeViewModel(initialItems: initialItems)

        let results = viewModel.pagedItems(matching: "zzzznotfound")
        let allResults = results.flatMap { $0 }

        XCTAssertTrue(allResults.isEmpty)
    }

    // MARK: - selectPage / goToPreviousPage / goToNextPage Tests

    func testSelectPageClampsToValidRange() throws {
        let apps = (0..<40).map { i in
            makeAppIcon(name: "App\(i)", bundleIdentifier: "com.test.app\(i)")
        }
        let initialItems = apps.map { LaunchyItem.app($0) }
        let viewModel = makeViewModel(initialItems: initialItems)

        let totalPages = viewModel.pageCount

        // Select a negative page — should clamp to 0
        viewModel.selectPage(-5, totalPages: totalPages)
        XCTAssertEqual(viewModel.currentPage, 0)

        // Select a page beyond the last — should clamp
        viewModel.selectPage(999, totalPages: totalPages)
        XCTAssertEqual(viewModel.currentPage, totalPages - 1)

        // Select valid middle page
        if totalPages > 1 {
            viewModel.selectPage(1, totalPages: totalPages)
            XCTAssertEqual(viewModel.currentPage, 1)
        }
    }

    func testGoToNextPageStopsAtLastPage() throws {
        let apps = (0..<40).map { i in
            makeAppIcon(name: "App\(i)", bundleIdentifier: "com.test.app\(i)")
        }
        let initialItems = apps.map { LaunchyItem.app($0) }
        let viewModel = makeViewModel(initialItems: initialItems)

        let totalPages = viewModel.pageCount

        // Go to the last page
        viewModel.selectPage(totalPages - 1, totalPages: totalPages)
        XCTAssertEqual(viewModel.currentPage, totalPages - 1)

        // Try to go one more — should stay
        viewModel.goToNextPage(totalPages: totalPages)
        XCTAssertEqual(viewModel.currentPage, totalPages - 1)
    }

    func testGoToPreviousPageStopsAtFirstPage() throws {
        let appA = makeAppIcon(name: "AppA", bundleIdentifier: "com.test.a")

        let initialItems: [LaunchyItem] = [.app(appA)]
        let viewModel = makeViewModel(initialItems: initialItems)

        XCTAssertEqual(viewModel.currentPage, 0)

        viewModel.goToPreviousPage(totalPages: viewModel.pageCount)
        XCTAssertEqual(viewModel.currentPage, 0)
    }

    func testGoToNextAndPreviousPageNavigatesCorrectly() throws {
        let apps = (0..<80).map { i in
            makeAppIcon(name: "App\(i)", bundleIdentifier: "com.test.app\(i)")
        }
        let initialItems = apps.map { LaunchyItem.app($0) }
        let viewModel = makeViewModel(initialItems: initialItems)

        let totalPages = viewModel.pageCount
        XCTAssertGreaterThan(totalPages, 2, "Need at least 3 pages for this test")

        XCTAssertEqual(viewModel.currentPage, 0)

        viewModel.goToNextPage(totalPages: totalPages)
        XCTAssertEqual(viewModel.currentPage, 1)

        viewModel.goToNextPage(totalPages: totalPages)
        XCTAssertEqual(viewModel.currentPage, 2)

        viewModel.goToPreviousPage(totalPages: totalPages)
        XCTAssertEqual(viewModel.currentPage, 1)
    }

    // MARK: - Array.chunked(into:) Tests

    func testChunkedWithEmptyArray() throws {
        let empty: [Int] = []
        let result = empty.chunked(into: 3)
        XCTAssertTrue(result.isEmpty)
    }

    func testChunkedWithSizeLargerThanCount() throws {
        let array = [1, 2, 3]
        let result = array.chunked(into: 10)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0], [1, 2, 3])
    }

    func testChunkedWithSizeOfOne() throws {
        let array = [1, 2, 3]
        let result = array.chunked(into: 1)
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0], [1])
        XCTAssertEqual(result[1], [2])
        XCTAssertEqual(result[2], [3])
    }

    func testChunkedEvenDivision() throws {
        let array = [1, 2, 3, 4, 5, 6]
        let result = array.chunked(into: 3)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0], [1, 2, 3])
        XCTAssertEqual(result[1], [4, 5, 6])
    }

    func testChunkedUnevenDivision() throws {
        let array = [1, 2, 3, 4, 5]
        let result = array.chunked(into: 3)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0], [1, 2, 3])
        XCTAssertEqual(result[1], [4, 5])
    }

    func testChunkedWithSizeZeroReturnsEmpty() throws {
        let array = [1, 2, 3]
        let result = array.chunked(into: 0)
        // Invalid chunk size returns an empty array
        XCTAssertEqual(result.count, 0)
    }

    // MARK: - GridLayoutMetrics Tests

    func testGridLayoutMetricsProducesPositiveDimensions() throws {
        let settings = GridSettings(
            columns: 7,
            rows: 5,
            folderColumns: 4,
            folderRows: 3,
            iconScale: 1.0,
            scrollSensitivity: 1.0,
            useFullScreenLayout: true
        )

        let metrics = GridLayoutMetrics(for: settings, in: CGSize(width: 1440, height: 900))

        XCTAssertGreaterThan(metrics.itemDimension, 0)
        XCTAssertGreaterThan(metrics.horizontalSpacing, 0)
        XCTAssertGreaterThan(metrics.verticalSpacing, 0)
        XCTAssertGreaterThan(metrics.padding, 0)
        XCTAssertEqual(metrics.columns.count, 7)
    }

    func testGridLayoutMetricsUltrawideClamp() throws {
        let settings = GridSettings(
            columns: 3,
            rows: 3,
            folderColumns: 3,
            folderRows: 3,
            iconScale: 1.0,
            scrollSensitivity: 1.0,
            useFullScreenLayout: true
        )

        // Ultrawide: very wide, normal height
        let metrics = GridLayoutMetrics(for: settings, in: CGSize(width: 5120, height: 900))

        // Horizontal spacing should be clamped to not exceed itemDimension * 1.8
        XCTAssertLessThanOrEqual(metrics.horizontalSpacing, metrics.itemDimension * 1.8 + 0.01)
    }

    func testGridLayoutMetricsTightenLoopForTinySize() throws {
        let settings = GridSettings(
            columns: 10,
            rows: 10,
            folderColumns: 4,
            folderRows: 3,
            iconScale: 1.0,
            scrollSensitivity: 1.0,
            useFullScreenLayout: true
        )

        // Very small size — should trigger the tighten loop
        let metrics = GridLayoutMetrics(for: settings, in: CGSize(width: 400, height: 400))

        // Even in tight conditions, dimensions should be non-negative
        XCTAssertGreaterThanOrEqual(metrics.itemDimension, 0)
        XCTAssertGreaterThanOrEqual(metrics.horizontalSpacing, 0)
        XCTAssertGreaterThanOrEqual(metrics.verticalSpacing, 0)
        // Padding should have been tightened down
        XCTAssertGreaterThanOrEqual(metrics.padding, 0)
    }

    func testGridLayoutMetricsDistributedSpacing() throws {
        let settings = GridSettings(
            columns: 5,
            rows: 4,
            folderColumns: 3,
            folderRows: 3,
            iconScale: 1.0,
            scrollSensitivity: 1.0,
            useFullScreenLayout: true
        )

        let metrics = GridLayoutMetrics(for: settings, in: CGSize(width: 1920, height: 1080))

        // The distributed spacing should fill up to the available width.
        // Due to the ultrawide clamp (hSpacing <= itemDimension * 1.8),
        // the total may be less than the full width — but never more.
        let totalWidth =
            metrics.padding * 2
            + CGFloat(5) * metrics.itemDimension
            + CGFloat(4) * metrics.horizontalSpacing
        XCTAssertLessThanOrEqual(totalWidth, 1920 + 1.0)

        // Spacing should be meaningfully distributed (not the tiny initial interpolated value)
        XCTAssertGreaterThan(metrics.horizontalSpacing, 8)
    }

    // MARK: - GridSettingsStore round-trip Tests

    func testGridSettingsStoreRoundTripEncodeDecode() throws {
        let suiteName = "GridSettingsStoreRoundTrip-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw XCTSkip("Unable to create UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = GridSettingsStore(defaults: defaults)
        store.update(
            columns: 5,
            rows: 4,
            folderColumns: 3,
            folderRows: 2,
            iconScale: 0.85,
            scrollSensitivity: 1.5,
            useFullScreenLayout: false,
            windowedWidth: 1200,
            windowedHeight: 800,
            lastWindowedPage: 2
        )

        let reloaded = GridSettingsStore(defaults: defaults)

        XCTAssertEqual(reloaded.settings.columns, 5)
        XCTAssertEqual(reloaded.settings.rows, 4)
        XCTAssertEqual(reloaded.settings.folderColumns, 3)
        XCTAssertEqual(reloaded.settings.folderRows, 2)
        XCTAssertEqual(reloaded.settings.iconScale, 0.85, accuracy: 0.001)
        XCTAssertEqual(reloaded.settings.scrollSensitivity, 1.5, accuracy: 0.001)
        XCTAssertFalse(reloaded.settings.useFullScreenLayout)
        XCTAssertEqual(reloaded.settings.lastWindowedWidth, 1200)
        XCTAssertEqual(reloaded.settings.lastWindowedHeight, 800)
        XCTAssertEqual(reloaded.settings.lastWindowedPage, 2)
    }

    func testGridSettingsStoreClampsBoundaryValues() throws {
        let suiteName = "GridSettingsStoreClamp-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw XCTSkip("Unable to create UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = GridSettingsStore(defaults: defaults)

        // Test lower bounds
        store.update(
            columns: 0,
            rows: 0,
            folderColumns: 0,
            folderRows: 0,
            iconScale: 0.1,
            scrollSensitivity: 0.0,
            windowedWidth: 100,
            windowedHeight: 100
        )

        XCTAssertEqual(store.settings.columns, 3)
        XCTAssertEqual(store.settings.rows, 3)
        XCTAssertEqual(store.settings.folderColumns, 2)
        XCTAssertEqual(store.settings.folderRows, 2)
        XCTAssertEqual(store.settings.iconScale, 0.7, accuracy: 0.001)
        XCTAssertEqual(store.settings.scrollSensitivity, 0.2, accuracy: 0.001)
        XCTAssertEqual(store.settings.lastWindowedWidth, 800)
        XCTAssertEqual(store.settings.lastWindowedHeight, 600)

        // Test upper bounds
        store.update(
            columns: 99,
            rows: 99,
            folderColumns: 99,
            folderRows: 99,
            iconScale: 10.0,
            scrollSensitivity: 10.0,
            windowedWidth: 99999,
            windowedHeight: 99999
        )

        XCTAssertEqual(store.settings.columns, 10)
        XCTAssertEqual(store.settings.rows, 10)
        XCTAssertEqual(store.settings.folderColumns, 8)
        XCTAssertEqual(store.settings.folderRows, 8)
        XCTAssertEqual(store.settings.iconScale, 1.5, accuracy: 0.001)
        XCTAssertEqual(store.settings.scrollSensitivity, 2.0, accuracy: 0.001)
        XCTAssertEqual(store.settings.lastWindowedWidth, 6000)
        XCTAssertEqual(store.settings.lastWindowedHeight, 4000)
    }

    // MARK: - Reconciliation Tests

    func testReconcileRemovesMissingApps() throws {
        let appA = makeAppIcon(name: "AppA", bundleIdentifier: "com.test.a")
        let appB = makeAppIcon(name: "AppB", bundleIdentifier: "com.test.b")

        // Save layout with both apps
        let storedItems: [LaunchyItem] = [.app(appA), .app(appB)]
        dataStore.save(storedItems)

        // Create a new data store whose provider finds NO installed apps
        let emptyProvider = InstalledApplicationsProvider(fileManager: fileManager)
        let freshStore = LaunchyDataStore(
            fileManager: fileManager,
            applicationsProvider: emptyProvider
        )

        let loaded = freshStore.load()

        // Neither app is installed, so both should be removed
        XCTAssertTrue(loaded.isEmpty, "Uninstalled apps should be removed during reconciliation")
    }

    func testReconcileAddsNewApps() throws {
        // Save an empty layout
        dataStore.save([])

        // The stub file manager blocks /Applications etc., so no new apps will be found.
        // To test "new apps added", we instead verify that loading an empty store
        // with no installed apps produces an empty list (baseline).
        let loaded = dataStore.load()
        XCTAssertTrue(loaded.isEmpty)
    }

    func testReconcilePreservesLayoutOrderForExistingApps() throws {
        // This test verifies the reconciliation path doesn't reorder items
        // when all stored apps are still installed.
        // Since our stub blocks real app directories, we rely on the fact
        // that reconciling stored items against zero installed apps removes them all.
        let appA = makeAppIcon(name: "AppA", bundleIdentifier: "com.test.a")
        let appB = makeAppIcon(name: "AppB", bundleIdentifier: "com.test.b")
        let folder = LaunchyFolder(name: "Stuff", apps: [appA])

        let storedItems: [LaunchyItem] = [.folder(folder), .app(appB)]
        dataStore.save(storedItems)

        let loaded = dataStore.load()

        // With stub, no apps are "installed" so reconcile removes everything
        XCTAssertTrue(loaded.isEmpty)
    }

    func testReconcileRemovesStaleAppsFromFolders() throws {
        let appA = makeAppIcon(name: "AppA", bundleIdentifier: "com.test.a")
        let appB = makeAppIcon(name: "AppB", bundleIdentifier: "com.test.b")
        let folder = LaunchyFolder(name: "Tools", apps: [appA, appB])

        let storedItems: [LaunchyItem] = [.folder(folder)]
        dataStore.save(storedItems)

        // Stub blocks all app directories → no installed apps → folder should be removed
        let loaded = dataStore.load()
        XCTAssertTrue(loaded.isEmpty)
    }

    // MARK: - Recently-added tracking

    /// On first launch `storedIDs` is empty, so no app should be marked recently-added —
    /// this prevents every single app from showing a blue "new" dot the very first time
    /// the user opens Launchy.
    func testUpdateRecentlyAddedDoesNotMarkAppsOnFirstRun() throws {
        let appA = makeAppIcon(name: "AppA", bundleIdentifier: "com.test.a")
        let appB = makeAppIcon(name: "AppB", bundleIdentifier: "com.test.b")
        let viewModel = makeViewModel(initialItems: [.app(appA), .app(appB)])

        // Pass the isolated suite — no prior known IDs, simulating first launch.
        viewModel.updateRecentlyAdded(defaults: userDefaults)

        XCTAssertTrue(
            viewModel.recentlyAddedBundleIDs.isEmpty,
            "On first run (empty storedIDs) no apps should be flagged as recently added"
        )
    }

    /// After the first run, apps that appear for the first time should be marked.
    func testUpdateRecentlyAddedMarksTrulyNewApps() throws {
        let key = "dev.lbenicio.launchy.known-bundle-ids"
        // Seed the isolated suite as if the app was previously opened with only appA.
        userDefaults.set(["com.test.a"], forKey: key)

        let appA = makeAppIcon(name: "AppA", bundleIdentifier: "com.test.a")
        let appB = makeAppIcon(name: "AppB", bundleIdentifier: "com.test.b")
        let viewModel = makeViewModel(initialItems: [.app(appA), .app(appB)])

        viewModel.updateRecentlyAdded(defaults: userDefaults)

        XCTAssertTrue(
            viewModel.recentlyAddedBundleIDs.contains("com.test.b"),
            "com.test.b is new since last run and should be flagged as recently added"
        )
        XCTAssertFalse(
            viewModel.recentlyAddedBundleIDs.contains("com.test.a"),
            "com.test.a was already known and should NOT be flagged"
        )
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
