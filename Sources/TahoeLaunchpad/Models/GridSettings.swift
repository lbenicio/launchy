import Foundation

struct GridSettings: Codable, Equatable {
    var columns: Int
    var rows: Int
    var folderColumns: Int
    var folderRows: Int
    var iconScale: Double
    var scrollSensitivity: Double
    var useFullScreenLayout: Bool

    static let defaults = GridSettings(
        columns: 7,
        rows: 5,
        folderColumns: 4,
        folderRows: 3,
        iconScale: 1.0,
        scrollSensitivity: 1.0,
        useFullScreenLayout: true
    )

    init(
        columns: Int,
        rows: Int,
        folderColumns: Int,
        folderRows: Int,
        iconScale: Double,
        scrollSensitivity: Double,
        useFullScreenLayout: Bool
    ) {
        self.columns = columns
        self.rows = rows
        self.folderColumns = folderColumns
        self.folderRows = folderRows
        self.iconScale = iconScale
        self.scrollSensitivity = scrollSensitivity
        self.useFullScreenLayout = useFullScreenLayout
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = GridSettings.defaults

        columns = try container.decodeIfPresent(Int.self, forKey: .columns) ?? defaults.columns
        rows = try container.decodeIfPresent(Int.self, forKey: .rows) ?? defaults.rows
        folderColumns =
            try container.decodeIfPresent(Int.self, forKey: .folderColumns)
            ?? defaults.folderColumns
        folderRows =
            try container.decodeIfPresent(Int.self, forKey: .folderRows) ?? defaults.folderRows
        iconScale =
            try container.decodeIfPresent(Double.self, forKey: .iconScale) ?? defaults.iconScale
        scrollSensitivity =
            try container.decodeIfPresent(Double.self, forKey: .scrollSensitivity)
            ?? defaults.scrollSensitivity
        useFullScreenLayout =
            try container.decodeIfPresent(Bool.self, forKey: .useFullScreenLayout)
            ?? defaults.useFullScreenLayout
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(columns, forKey: .columns)
        try container.encode(rows, forKey: .rows)
        try container.encode(folderColumns, forKey: .folderColumns)
        try container.encode(folderRows, forKey: .folderRows)
        try container.encode(iconScale, forKey: .iconScale)
        try container.encode(scrollSensitivity, forKey: .scrollSensitivity)
        try container.encode(useFullScreenLayout, forKey: .useFullScreenLayout)
    }

    var pageCapacity: Int {
        max(1, columns * rows)
    }

    var folderCapacity: Int {
        max(1, folderColumns * folderRows)
    }

    private enum CodingKeys: String, CodingKey {
        case columns
        case rows
        case folderColumns
        case folderRows
        case iconScale
        case scrollSensitivity
        case useFullScreenLayout
    }
}
