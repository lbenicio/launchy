import XCTest

@testable import Launchy

@MainActor
final class SearchIndexTests: XCTestCase {
    private var searchIndex: SearchIndex!
    private var testApps: [AppIcon]!
    private var testFolders: [LaunchyFolder]!
    private var testWidgets: [DashboardWidget]!
    private var testItems: [LaunchyItem]!

    override func setUp() async throws {
        searchIndex = SearchIndex()

        // Create test data
        testApps = [
            AppIcon(
                name: "Safari",
                bundleIdentifier: "com.apple.safari",
                bundleURL: URL(fileURLWithPath: "/Applications/Safari.app")
            ),
            AppIcon(
                name: "Mail",
                bundleIdentifier: "com.apple.mail",
                bundleURL: URL(fileURLWithPath: "/Applications/Mail.app")
            ),
            AppIcon(
                name: "Calendar",
                bundleIdentifier: "com.apple.calendar",
                bundleURL: URL(fileURLWithPath: "/Applications/Calendar.app")
            ),
            AppIcon(
                name: "Notes",
                bundleIdentifier: "com.apple.notes",
                bundleURL: URL(fileURLWithPath: "/Applications/Notes.app")
            ),
        ]

        testFolders = [
            LaunchyFolder(name: "Productivity", color: .blue, apps: Array(testApps.prefix(2))),
            LaunchyFolder(name: "Utilities", color: .green, apps: Array(testApps.suffix(2))),
        ]

        testWidgets = [
            DashboardWidget(type: .weather),
            DashboardWidget(type: .calculator),
            DashboardWidget(type: .notes),
        ]

        // Create LaunchyItems
        testItems =
            testApps.map { LaunchyItem.app($0) } + testFolders.map { LaunchyItem.folder($0) }
            + testWidgets.map { LaunchyItem.widget($0) }

        // Build the index
        searchIndex.rebuild(from: testItems)
    }

    override func tearDown() async throws {
        searchIndex = nil
        testApps = nil
        testFolders = nil
        testWidgets = nil
        testItems = nil
    }

    // MARK: - Search Tests

    func testSearchByAppName() async throws {
        let results = searchIndex.search(query: "Safari")
        XCTAssertEqual(results.count, 1, "Should find Safari app")
        if case .app(let app) = results.first {
            XCTAssertEqual(app.name, "Safari")
        } else {
            XCTFail("Expected app result")
        }
    }

    func testSearchByFolderName() async throws {
        let results = searchIndex.search(query: "Productivity")
        XCTAssertEqual(results.count, 1, "Should find Productivity folder")
        if case .folder(let folder) = results.first {
            XCTAssertEqual(folder.name, "Productivity")
        } else {
            XCTFail("Expected folder result")
        }
    }

    func testSearchByWidgetName() async throws {
        let results = searchIndex.search(query: "Weather")
        XCTAssertEqual(results.count, 1, "Should find Weather widget")
        if case .widget(let widget) = results.first {
            XCTAssertEqual(widget.widgetType, .weather)
        } else {
            XCTFail("Expected widget result")
        }
    }

    func testSearchByPartialName() async throws {
        let results = searchIndex.search(query: "Cal")
        XCTAssertTrue(results.count >= 1, "Should find Calendar app")

        let calendarResults = results.filter { item in
            if case .app(let app) = item {
                return app.name.contains("Cal")
            }
            return false
        }
        XCTAssertFalse(calendarResults.isEmpty, "Should find Calendar in results")
    }

    func testSearchByBundleIdentifier() async throws {
        let results = searchIndex.search(query: "com.apple.safari")
        XCTAssertEqual(results.count, 1, "Should find Safari by bundle identifier")
    }

    func testSearchCaseInsensitive() async throws {
        let results1 = searchIndex.search(query: "safari")
        let results2 = searchIndex.search(query: "SAFARI")
        let results3 = searchIndex.search(query: "Safari")

        XCTAssertEqual(results1.count, results2.count, "Case should not matter")
        XCTAssertEqual(results2.count, results3.count, "Case should not matter")
    }

    func testSearchEmptyQuery() async throws {
        let results = searchIndex.search(query: "")
        XCTAssertTrue(results.isEmpty, "Empty query should return no results")
    }

    func testSearchNoMatches() async throws {
        let results = searchIndex.search(query: "NonExistentApp")
        XCTAssertTrue(results.isEmpty, "Non-existent app should return no results")
    }

    // MARK: - Index Management Tests

    func testRebuildIndex() async throws {
        // Create new items
        let newApps = [
            AppIcon(
                name: "NewApp",
                bundleIdentifier: "com.test.newapp",
                bundleURL: URL(fileURLWithPath: "/Applications/NewApp.app")
            )
        ]
        let newItems = newApps.map { LaunchyItem.app($0) }

        // Rebuild index with new items
        searchIndex.rebuild(from: newItems)

        // Search for new app
        let results = searchIndex.search(query: "NewApp")
        XCTAssertEqual(results.count, 1, "Should find newly added app")
    }

    func testRemoveItem() async throws {
        guard let safariApp = testApps.first(where: { $0.name == "Safari" }) else {
            XCTFail("Safari app not found")
            return
        }

        searchIndex.removeItem(safariApp.id)

        let results = searchIndex.search(query: "Safari")
        XCTAssertTrue(results.isEmpty, "Should not find removed app")
    }

    func testRemoveNonExistentItem() async throws {
        let nonExistentID = UUID()
        // Should not crash
        searchIndex.removeItem(nonExistentID)

        // Search should still work
        let results = searchIndex.search(query: "Safari")
        XCTAssertEqual(results.count, 1, "Should still find Safari")
    }

    // MARK: - Performance Tests

    func testSearchPerformance() async throws {
        measure {
            Task { @MainActor in
                let queries = [
                    "Safari", "Mail", "Calendar", "Notes", "Productivity", "Utilities", "Weather",
                    "Calculator",
                ]
                for query in queries {
                    _ = searchIndex.search(query: query)
                }
            }
        }
    }

    func testIndexRebuildPerformance() async throws {
        measure {
            Task { @MainActor in
                searchIndex.rebuild(from: testItems)
            }
        }
    }

    // MARK: - Edge Cases

    func testSearchWithSpecialCharacters() async throws {
        let results = searchIndex.search(query: "Safari@#$")
        XCTAssertTrue(results.isEmpty, "Special characters should return no results")
    }

    func testSearchWithNumbers() async throws {
        let results = searchIndex.search(query: "123")
        XCTAssertTrue(results.isEmpty, "Numbers should return no results for this test data")
    }
}
