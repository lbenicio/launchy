import XCTest

@testable import Launchy

final class AppItemTests: XCTestCase {
    func testMatchesFindsDisplayNameIgnoringCase() {
        let item = AppItem(
            id: "launchy",
            displayName: "Launchy",
            bundleIdentifier: "com.example.launchy",
            bundleURL: URL(fileURLWithPath: "/Applications/Launchy.app")
        )

        XCTAssertTrue(item.matches("launch"))
        XCTAssertTrue(item.matches("UNCHY"))
    }

    func testMatchesReturnsFalseWhenQueryIsAbsent() {
        let item = AppItem(
            id: "launchy",
            displayName: "Launchy",
            bundleIdentifier: "com.example.launchy",
            bundleURL: URL(fileURLWithPath: "/Applications/Launchy.app")
        )

        XCTAssertFalse(item.matches("spotlight"))
    }
}
