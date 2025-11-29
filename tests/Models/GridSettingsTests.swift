import XCTest

@testable import Launchy

final class GridSettingsTests: XCTestCase {
    func testPageAndFolderCapacityReflectLayout() {
        let settings = GridSettings(
            columns: 6,
            rows: 4,
            folderColumns: 3,
            folderRows: 2,
            iconScale: 1.0,
            scrollSensitivity: 1.0,
            useFullScreenLayout: true
        )

        XCTAssertEqual(settings.pageCapacity, 24)
        XCTAssertEqual(settings.folderCapacity, 6)
    }

    func testDecodingFallsBackToDefaultsWhenValuesMissing() throws {
        let partialJSON = """
            { "columns": 8 }
            """.data(using: .utf8) ?? Data()
        let decoded = try JSONDecoder().decode(GridSettings.self, from: partialJSON)

        XCTAssertEqual(decoded.columns, 8)
        XCTAssertEqual(decoded.rows, GridSettings.defaults.rows)
        XCTAssertEqual(decoded.folderColumns, GridSettings.defaults.folderColumns)
        XCTAssertEqual(decoded.folderRows, GridSettings.defaults.folderRows)
        XCTAssertEqual(decoded.iconScale, GridSettings.defaults.iconScale)
        XCTAssertEqual(decoded.scrollSensitivity, GridSettings.defaults.scrollSensitivity)
        XCTAssertEqual(decoded.useFullScreenLayout, GridSettings.defaults.useFullScreenLayout)
    }
}
