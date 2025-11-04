import XCTest

@testable import Launchy

@MainActor
final class AccessibilityPermissionTests: XCTestCase {
  override func setUp() async throws {
    try await super.setUp()
    AccessibilityPermission.resetPromptStateForTesting()
  }

  func testRequestMarksPromptAsHandledInTests() {
    XCTAssertFalse(AccessibilityPermission.hasPromptedForTesting)
    AccessibilityPermission.requestIfNeeded()
    let firstResult = AccessibilityPermission.hasPromptedForTesting
    AccessibilityPermission.requestIfNeeded()
    XCTAssertEqual(firstResult, AccessibilityPermission.hasPromptedForTesting)
  }
}
