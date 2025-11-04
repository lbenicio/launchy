import AppKit
import XCTest

@testable import Launchy

@MainActor
final class IconStoreTests: XCTestCase {
  private var tempURL: URL!

  override func setUpWithError() throws {
    try super.setUpWithError()
    let base = FileManager.default.temporaryDirectory
    tempURL = base.appendingPathComponent(
      "IconStoreTests_\(UUID().uuidString).app", isDirectory: true)
    try FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true)
  }

  override func tearDownWithError() throws {
    if let tempURL {
      try? FileManager.default.removeItem(at: tempURL)
    }
    tempURL = nil
    try super.tearDownWithError()
  }

  func testIconCachingReturnsSameInstance() {
    let iconStore = IconStore.shared
    let firstIcon = iconStore.icon(for: tempURL)
    let secondIcon = iconStore.icon(for: tempURL)

    XCTAssertTrue(firstIcon === secondIcon)
    XCTAssertEqual(firstIcon.size.width, 128)
    XCTAssertEqual(firstIcon.size.height, 128)
  }
}
