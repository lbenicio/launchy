import XCTest

@testable import Launchy

final class ModelsTests: XCTestCase {
  func testAppItemMatchesQueryIgnoringCase() {
    let app = AppItem(
      id: "id",
      displayName: "Terminal",
      bundleIdentifier: "com.apple.Terminal",
      bundleURL: URL(fileURLWithPath: "/Applications/Utilities/Terminal.app")
    )

    XCTAssertTrue(app.matches("terminal"))
    XCTAssertTrue(app.matches("COM.APPLE"))
    XCTAssertFalse(app.matches("Safari"))
  }

  func testCatalogEntryProvidesStableIdentifiers() {
    let app = AppItem(
      id: "app-1",
      displayName: "Safari",
      bundleIdentifier: "com.apple.Safari",
      bundleURL: URL(fileURLWithPath: "/Applications/Safari.app")
    )
    var folder = FolderItem(id: "folder-1", name: "Work", apps: [app])
    folder.apps.append(app)

    let appEntry = CatalogEntry.app(app)
    let folderEntry = CatalogEntry.folder(folder)

    XCTAssertEqual(appEntry.id, "app-\(app.id)")
    XCTAssertEqual(folderEntry.id, "folder-\(folder.id)")
    XCTAssertEqual(appEntry.app?.id, app.id)
    XCTAssertEqual(folderEntry.folder?.id, folder.id)
  }
}
