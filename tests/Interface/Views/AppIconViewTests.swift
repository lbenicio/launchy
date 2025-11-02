import SwiftUI
import XCTest

@testable import Launchy

@MainActor
final class AppIconViewTests: XCTestCase {
  override func setUp() {
    super.setUp()
    if NSApp == nil {
      _ = NSApplication.shared
    }
  }

  func testAppIconViewCanBeHosted() {
    let app = AppItem(
      id: "app-1",
      displayName: "Preview",
      bundleIdentifier: "com.apple.Preview",
      bundleURL: URL(fileURLWithPath: "/Applications/Preview.app")
    )
    let store = AppCatalogStore()

    let view = AppIconView(app: app).environmentObject(store)
    let controller = NSHostingController(rootView: view)
    XCTAssertNotNil(controller.view)
    controller.view.layoutSubtreeIfNeeded()
  }

  func testFolderIconViewCanBeHosted() {
    let folder = FolderItem(id: "folder-1", name: "Work", apps: [])
    let store = AppCatalogStore()
    let view = FolderIconView(folder: folder).environmentObject(store)
    let controller = NSHostingController(rootView: view)
    XCTAssertNotNil(controller.view)
    controller.view.layoutSubtreeIfNeeded()
  }
}
