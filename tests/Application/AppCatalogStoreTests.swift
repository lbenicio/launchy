import XCTest

@testable import Launchy

@MainActor
final class AppCatalogStoreTests: XCTestCase {
  func testDismissPresentedFolderOrClearSearchWhileEditing() {
    let store = AppCatalogStore()
    store.isEditing = true
    store.query = "sample"
    let folder = FolderItem(id: "folder-1", name: "Folder", apps: [])
    store.presentedFolder = folder

    let handled = store.dismissPresentedFolderOrClearSearch()

    XCTAssertTrue(handled)
    XCTAssertFalse(store.isEditing)
    XCTAssertEqual(store.presentedFolder?.id, folder.id)
    XCTAssertEqual(store.query, "sample")
  }

  func testDismissPresentedFolderOrClearSearchClearsPresentedFolder() {
    let store = AppCatalogStore()
    store.presentedFolder = FolderItem(id: "folder-2", name: "Work", apps: [])

    let handled = store.dismissPresentedFolderOrClearSearch()

    XCTAssertTrue(handled)
    XCTAssertNil(store.presentedFolder)
  }

  func testBeginEditingClearsQueryAndFolderUnlessPreserved() {
    let store = AppCatalogStore()
    store.query = "Notes"
    store.presentedFolder = FolderItem(id: "folder-3", name: "Games", apps: [])

    store.beginEditing()
    XCTAssertTrue(store.isEditing)
    XCTAssertEqual(store.query, "")
    XCTAssertNil(store.presentedFolder)

    let folder = FolderItem(id: "folder-4", name: "Tools", apps: [])
    store.presentedFolder = folder
    store.beginEditing(preservingFolder: true)
    XCTAssertEqual(store.presentedFolder?.id, folder.id)
  }
}
