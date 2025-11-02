import SwiftUI
import XCTest

@testable import Launchy

@MainActor
final class WindowConfiguratorTests: XCTestCase {
  func testTransparentWindowConfiguratorCoordinatorStartsUnconfigured() {
    let configurator = TransparentWindowConfigurator()
    let coordinator = configurator.makeCoordinator()
    XCTAssertNil(coordinator.window)
    XCTAssertFalse(coordinator.didConfigureStyle)
  }

  func testAuxiliaryWindowConfiguratorAppliesAuxiliaryLevel() {
    if NSApp == nil {
      _ = NSApplication.shared
    }

    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
      styleMask: [.titled, .closable],
      backing: .buffered,
      defer: false
    )
    let hostingView = NSHostingView(rootView: AuxiliaryWindowConfigurator())
    window.contentView = hostingView
    window.makeKeyAndOrderFront(nil)

    RunLoop.current.run(until: Date().addingTimeInterval(0.1))

    XCTAssertEqual(window.level, .launchyAuxiliary)
    window.close()
  }

  func testWindowLevelsMatchDefinitions() {
    XCTAssertEqual(NSWindow.Level.launchyPrimary, .screenSaver)
    XCTAssertEqual(
      NSWindow.Level.launchyAuxiliary.rawValue,
      NSWindow.Level.screenSaver.rawValue + 1
    )
  }
}
