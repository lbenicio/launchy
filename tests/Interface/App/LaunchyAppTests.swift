import SwiftUI
import XCTest

@testable import Launchy

@MainActor
final class LaunchyAppTests: XCTestCase {
  override func setUp() {
    super.setUp()
    if NSApp == nil {
      _ = NSApplication.shared
    }
  }

  func testLifecycleDelegateAdjustsPresentationOptionsWhenBecomingActive() {
    let delegate = AppLifecycleDelegate()
    let originalOptions = NSApp.presentationOptions

    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
      styleMask: .borderless,
      backing: .buffered,
      defer: false
    )
    window.level = .launchyPrimary
    window.makeKeyAndOrderFront(nil)

    delegate.applicationDidBecomeActive(
      Notification(name: NSApplication.didBecomeActiveNotification))

    XCTAssertTrue(NSApp.presentationOptions.contains(.hideDock))
    XCTAssertTrue(NSApp.presentationOptions.contains(.hideMenuBar))

    delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
    XCTAssertEqual(NSApp.presentationOptions, originalOptions)
    window.close()
  }

  func testApplicationShouldHandleReopenReturnsFalse() {
    let delegate = AppLifecycleDelegate()
    let handled = delegate.applicationShouldHandleReopen(NSApp, hasVisibleWindows: false)
    XCTAssertFalse(handled)
  }
}
