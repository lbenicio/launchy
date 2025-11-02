import SwiftUI
import XCTest

@testable import Launchy

@MainActor
final class FolderOverlayTests: XCTestCase {
  override func setUp() {
    super.setUp()
    if NSApp == nil {
      _ = NSApplication.shared
    }
  }

  func testFolderOverlayHostsWithEnvironment() {
    let folder = FolderItem(
      id: "folder-1",
      name: "Work",
      apps: [
        AppItem(
          id: "app-1",
          displayName: "Notes",
          bundleIdentifier: "com.example.notes",
          bundleURL: URL(fileURLWithPath: "/Applications/Notes.app")
        )
      ]
    )
    let anchor = CGRect(x: 40, y: 40, width: 200, height: 200)
    let store = AppCatalogStore()
    store.presentedFolder = folder
    let settings = AppSettings()

    let overlay = FolderOverlay(
      folder: folder,
      anchor: anchor,
      containerSize: CGSize(width: 800, height: 600),
      tileFrames: [:]
    ) { _ in }
    .environmentObject(store)
    .environmentObject(settings)

    let controller = NSHostingController(rootView: overlay)
    XCTAssertNotNil(controller.view)
    controller.view.layoutSubtreeIfNeeded()
  }
}
