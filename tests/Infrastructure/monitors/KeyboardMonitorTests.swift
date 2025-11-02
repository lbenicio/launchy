import XCTest

@testable import Launchy

@MainActor
final class KeyboardMonitorTests: XCTestCase {
  override func setUp() {
    super.setUp()
    if NSApp == nil {
      _ = NSApplication.shared
    }
    KeyboardMonitor.shared.resetForTesting()
  }

  override func tearDown() {
    KeyboardMonitor.shared.resetForTesting()
    super.tearDown()
  }

  func testConfigureInstallsMonitorsOnce() {
    let monitor = KeyboardMonitor.shared
    monitor.configure(with: AppCatalogStore())
    XCTAssertTrue(monitor.isConfiguredForTesting)

    monitor.configure(with: AppCatalogStore())
    XCTAssertTrue(monitor.isConfiguredForTesting)

    monitor.teardown()
    XCTAssertFalse(monitor.isConfiguredForTesting)
  }
}
