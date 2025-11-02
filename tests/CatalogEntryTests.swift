import XCTest

@testable import Launchy

final class CatalogEntryTests: XCTestCase {
    func testAppEntryProvidesMatchingIdAndAccessors() {
        let app = AppItem(
            id: "calculator",
            displayName: "Calculator",
            bundleIdentifier: "com.apple.calculator",
            bundleURL: URL(fileURLWithPath: "/Applications/Calculator.app")
        )
        let entry = CatalogEntry.app(app)

        XCTAssertEqual(entry.id, "app-\(app.id)")
        XCTAssertEqual(entry.app, app)
        XCTAssertNil(entry.folder)
    }

    func testFolderEntryProvidesMatchingIdAndAccessors() {
        let app = AppItem(
            id: "notes",
            displayName: "Notes",
            bundleIdentifier: "com.apple.notes",
            bundleURL: URL(fileURLWithPath: "/Applications/Notes.app")
        )
        let folder = FolderItem(id: "favorites", name: "Favorites", apps: [app])
        let entry = CatalogEntry.folder(folder)

        XCTAssertEqual(entry.id, "folder-\(folder.id)")
        XCTAssertEqual(entry.folder, folder)
        XCTAssertNil(entry.app)
    }
}
