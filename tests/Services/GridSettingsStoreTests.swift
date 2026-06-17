import XCTest

@testable import Launchy

final class GridSettingsStoreTests: XCTestCase {
    @MainActor
    func testUpdateClampsValuesAndPersists() {
        let suiteName = "GridSettingsStoreTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create UserDefaults for testing")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = GridSettingsStore(defaults: defaults)
        store.update(
            columns: 1,
            rows: 20,
            folderColumns: 1,
            folderRows: 20,
            iconScale: 2.5,
            scrollSensitivity: 5.0,
            useFullScreenLayout: false
        )

        let settings = store.settings
        XCTAssertEqual(settings.columns, 3)
        XCTAssertEqual(settings.rows, 10)
        XCTAssertEqual(settings.folderColumns, 2)
        XCTAssertEqual(settings.folderRows, 8)
        XCTAssertEqual(settings.iconScale, 1.5, accuracy: 0.0001)
        XCTAssertEqual(settings.scrollSensitivity, 2.0, accuracy: 0.0001)
        XCTAssertFalse(settings.useFullScreenLayout)

        let reloadedStore = GridSettingsStore(defaults: defaults)
        XCTAssertEqual(reloadedStore.settings, settings)
    }
}
