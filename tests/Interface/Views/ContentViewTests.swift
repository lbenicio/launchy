import SwiftUI
import XCTest

@testable import Launchy

@MainActor
final class ContentViewTests: XCTestCase {
  override func setUp() {
    super.setUp()
    if NSApp == nil {
      _ = NSApplication.shared
    }
    KeyboardMonitor.shared.resetForTesting()
  }

  func testContentViewCanBeHostedWithDependencies() {
    let store = AppCatalogStore()
    let settings = AppSettings()
    let view = ContentView()
      .environmentObject(store)
      .environmentObject(settings)

    let controller = NSHostingController(rootView: view)
    XCTAssertNotNil(controller.view)
    controller.view.layoutSubtreeIfNeeded()
  }
}
