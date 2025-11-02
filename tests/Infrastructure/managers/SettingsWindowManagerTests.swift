import SwiftUI
import XCTest

@testable import Launchy

@MainActor
final class SettingsWindowManagerTests: XCTestCase {
  override func setUp() {
    super.setUp()
    if NSApp == nil {
      _ = NSApplication.shared
    }
  }

  override func tearDown() {
    for window in NSApp.windows where window.title == "Settings" {
      window.close()
    }
    super.tearDown()
  }

  func testShowDisplaysSettingsWindowWhenProviderAvailable() {
    let manager = SettingsWindowManager.shared
    manager.settingsProvider = { AppSettings() }

    manager.show()
    RunLoop.current.run(until: Date().addingTimeInterval(0.1))

    XCTAssertTrue(manager.isShowing)

    if let window = NSApp.windows.first(where: { $0.title == "Settings" }) {
      manager.windowWillClose(Notification(name: NSWindow.willCloseNotification, object: window))
    }
  }
}
