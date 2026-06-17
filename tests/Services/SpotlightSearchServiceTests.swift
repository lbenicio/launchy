import XCTest

@testable import Launchy

@MainActor
final class SpotlightSearchServiceTests: XCTestCase {
    private var spotlightService: SpotlightSearchService!

    override func setUp() async throws {
        spotlightService = SpotlightSearchService.shared
    }

    override func tearDown() async throws {
        spotlightService = nil
    }

    func testSearchReturnsEmptyResultsForEmptyQuery() async throws {
        let results = await spotlightService.search("")
        XCTAssertTrue(results.isEmpty, "Empty query should return no results")
    }

    func testSearchReturnsEmptyResultsForWhitespaceQuery() async throws {
        let results = await spotlightService.search("   ")
        XCTAssertTrue(results.isEmpty, "Whitespace query should return no results")
    }

    func testSearchWithValidQuery() async throws {
        // Note: This test uses the simplified implementation that returns empty results
        // In a full implementation, this would test actual Spotlight integration
        let results = await spotlightService.search("test")
        XCTAssertTrue(results.isEmpty, "Simplified implementation should return empty results")
    }

    func testSearchPerformance() async throws {
        measure {
            Task {
                let _ = await spotlightService.search("performance test")
            }
        }
    }

    func testConcurrentSearches() async throws {
        let queries = ["test1", "test2", "test3", "test4", "test5"]

        // Run searches concurrently
        let tasks = queries.map { query in
            Task {
                await spotlightService.search(query)
            }
        }

        // Wait for all to complete
        let results = await withTaskGroup(of: [SpotlightResult].self) { group in
            var allResults: [[SpotlightResult]] = []
            for task in tasks {
                group.addTask {
                    await task.value
                }
            }
            for await result in group {
                allResults.append(result)
            }
            return allResults
        }

        XCTAssertEqual(results.count, queries.count, "Should return results for all queries")

        // All results should be empty (simplified implementation)
        for result in results {
            XCTAssertTrue(
                result.isEmpty,
                "Each result should be empty in simplified implementation"
            )
        }
    }
}
