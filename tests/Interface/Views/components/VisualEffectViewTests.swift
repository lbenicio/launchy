import AppKit
import SwiftUI
import XCTest

@testable import Launchy

@MainActor
final class VisualEffectViewTests: XCTestCase {
  func testVisualEffectViewConfiguresMaterialAndBlendingMode() {
    let view = VisualEffectView(material: .menu, blendingMode: .withinWindow)
    let hosting = NSHostingView(rootView: view)
    hosting.frame = NSRect(x: 0, y: 0, width: 10, height: 10)
    hosting.layoutSubtreeIfNeeded()

    guard let effectView = findEffectView(in: hosting) else {
      XCTFail("Expected to locate an NSVisualEffectView instance")
      return
    }

    XCTAssertEqual(effectView.material, .menu)
    XCTAssertEqual(effectView.blendingMode, .withinWindow)
  }

  private func findEffectView(in view: NSView) -> NSVisualEffectView? {
    if let effectView = view as? NSVisualEffectView {
      return effectView
    }
    for subview in view.subviews {
      if let result = findEffectView(in: subview) {
        return result
      }
    }
    return nil
  }
}
