import XCTest

@testable import Launchy

/// Tests for `LaunchyApp` initialization and basic functionality.
@MainActor
final class LaunchyAppTests: XCTestCase {
    private var settingsStore: GridSettingsStore!
    private var viewModel: LaunchyViewModel!

    override func setUp() async throws {
        settingsStore = GridSettingsStore()
        let dataStore = LaunchyDataStore()
        viewModel = LaunchyViewModel(dataStore: dataStore, settingsStore: settingsStore)
    }

    override func tearDown() async throws {
        settingsStore = nil
        viewModel = nil
    }

    // MARK: - Initialization Tests

    func testSettingsStoreInitialization() throws {
        XCTAssertNotNil(settingsStore, "Settings store should be initialized")
        XCTAssertNotNil(settingsStore.settings, "Settings should be loaded")
    }

    func testViewModelInitialization() throws {
        XCTAssertNotNil(viewModel, "ViewModel should be initialized")
        XCTAssertNotNil(viewModel.items, "Items array should exist")
        XCTAssertFalse(viewModel.isEditing, "Should not be in editing mode initially")
        XCTAssertNil(viewModel.presentedFolderID, "No folder should be presented initially")
    }

    // MARK: - Settings Tests

    func testDefaultSettingsValues() throws {
        let settings = settingsStore.settings
        XCTAssertGreaterThan(settings.columns, 0, "Columns should be positive")
        XCTAssertGreaterThan(settings.rows, 0, "Rows should be positive")
        XCTAssertGreaterThan(settings.iconScale, 0, "Icon scale should be positive")
    }

    // MARK: - AppCoordinator Tests

    func testAppCoordinatorSingleton() throws {
        let coordinator1 = AppCoordinator.shared
        let coordinator2 = AppCoordinator.shared
        XCTAssertTrue(coordinator1 === coordinator2, "AppCoordinator should be a singleton")
    }

    // MARK: - Menu Commands Tests

    func testToggleSettingsEvent() throws {
        let expectation = XCTestExpectation(description: "Toggle settings event received")
        let cancellable = AppCoordinator.shared.events
            .filter { $0 == .toggleSettings }
            .sink { _ in
                expectation.fulfill()
            }
        
        AppCoordinator.shared.send(.toggleSettings)
        
        wait(for: [expectation], timeout: 1.0)
        cancellable.cancel()
    }

    // MARK: - App Events Tests

    func testLauncherDidReappearEvent() throws {
        let expectation = XCTestExpectation(description: "Launcher reappear event received")
        let cancellable = AppCoordinator.shared.events
            .filter { $0 == .launcherDidReappear }
            .sink { _ in
                expectation.fulfill()
            }
        
        AppCoordinator.shared.send(.launcherDidReappear)
        
        wait(for: [expectation], timeout: 1.0)
        cancellable.cancel()
    }

    func testDismissLauncherEvent() throws {
        let expectation = XCTestExpectation(description: "Dismiss launcher event received")
        let cancellable = AppCoordinator.shared.events
            .filter { $0 == .dismissLauncher }
            .sink { _ in
                expectation.fulfill()
            }
        
        AppCoordinator.shared.send(.dismissLauncher)
        
        wait(for: [expectation], timeout: 1.0)
        cancellable.cancel()
    }
}
