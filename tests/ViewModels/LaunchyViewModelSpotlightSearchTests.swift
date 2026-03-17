import XCTest

@testable import Launchy

@MainActor
final class LaunchyViewModelSpotlightSearchTests: XCTestCase {
    private var viewModel: LaunchyViewModel!

    override func setUp() async throws {
        // Create a simple data store and settings store for testing
        let fileManager = FileManager.default
        let applicationsProvider = InstalledApplicationsProvider(fileManager: fileManager)
        let dataStore = LaunchyDataStore(
            fileManager: fileManager,
            applicationsProvider: applicationsProvider
        )
        let settingsStore = GridSettingsStore()

        viewModel = LaunchyViewModel(
            dataStore: dataStore,
            settingsStore: settingsStore
        )

        // Setup test data
        let testApps = [
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
        ]
        let testFolders = [
            LaunchyFolder(name: "Productivity", color: .blue, apps: testApps)
        ]
        let testWidgets = [
            DashboardWidget(type: .calculator)
        ]

        let testItems =
            testApps.map { LaunchyItem.app($0) } + testFolders.map { LaunchyItem.folder($0) }
            + testWidgets.map { LaunchyItem.widget($0) }

        viewModel.items = testItems
    }

    override func tearDown() async throws {
        viewModel = nil
    }

    // MARK: - Spotlight Search Tests

    func testSearchWithEmptyQuery() async throws {
        await viewModel.performSpotlightSearch(for: "")

        // Wait a moment for async operation
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertTrue(viewModel.spotlightResults.isEmpty, "Empty query should return no results")
        XCTAssertFalse(viewModel.isSearchingSpotlight, "Should not be searching after empty query")
    }

    func testSearchWithWhitespaceQuery() async throws {
        await viewModel.performSpotlightSearch(for: "   ")

        // Wait a moment for async operation
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertTrue(
            viewModel.spotlightResults.isEmpty,
            "Whitespace query should return no results"
        )
        XCTAssertFalse(
            viewModel.isSearchingSpotlight,
            "Should not be searching after whitespace query"
        )
    }

    func testSearchWithValidQuery() async throws {
        await viewModel.performSpotlightSearch(for: "test")

        // Should start searching
        XCTAssertTrue(viewModel.isSearchingSpotlight, "Should be searching for valid query")

        // Wait a moment for async operation
        try await Task.sleep(nanoseconds: 100_000_000)

        // Since spotlight is simplified, results should be empty
        XCTAssertTrue(
            viewModel.spotlightResults.isEmpty,
            "Simplified spotlight should return empty results"
        )
        XCTAssertFalse(viewModel.isSearchingSpotlight, "Should not be searching after completion")
    }

    func testCancelSpotlightSearch() async throws {
        // Start a search
        await viewModel.performSpotlightSearch(for: "test")
        XCTAssertTrue(viewModel.isSearchingSpotlight, "Should be searching")

        // Cancel the search
        viewModel.cancelSpotlightSearch()

        XCTAssertFalse(viewModel.isSearchingSpotlight, "Should not be searching after cancel")
        XCTAssertTrue(viewModel.spotlightResults.isEmpty, "Results should be cleared after cancel")
    }

    func testSearchPerformance() async throws {
        measure {
            Task {
                await viewModel.performSpotlightSearch(for: "performance test")
                // Wait for completion
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
    }
}
