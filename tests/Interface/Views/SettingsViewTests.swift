import SwiftUI
import XCTest

@testable import Launchy

@MainActor
final class SettingsViewTests: XCTestCase {
  override func setUp() {
    super.setUp()
    if NSApp == nil {
      _ = NSApplication.shared
    }
  }

  func testSettingsViewHostsWithEnvironment() {
    let settings = AppSettings()
    let view = SettingsView().environmentObject(settings)
    let controller = NSHostingController(rootView: view)

    XCTAssertNotNil(controller.view)
    controller.view.layoutSubtreeIfNeeded()
  }
}
