import Foundation

struct GridSettings: Codable, Equatable {
    var columns: Int
    var rows: Int
    var folderColumns: Int
    var folderRows: Int
    var iconScale: Double

    static let defaults = GridSettings(
        columns: 7,
        rows: 5,
        folderColumns: 4,
        folderRows: 3,
        iconScale: 1.0
    )

    var pageCapacity: Int {
        max(1, columns * rows)
    }

    var folderCapacity: Int {
        max(1, folderColumns * folderRows)
    }
}
