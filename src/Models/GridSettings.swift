import CoreGraphics
import Foundation

enum BackgroundMode: String, Codable, Sendable, CaseIterable {
    case wallpaperBlur
    case solidColor
    case gradient
}

struct GridSettings: Codable, Equatable, Sendable {
    var columns: Int
    var rows: Int
    var folderColumns: Int
    var folderRows: Int
    var iconScale: Double
    var scrollSensitivity: Double
    var useFullScreenLayout: Bool
    var lastWindowedWidth: Double?
    var lastWindowedHeight: Double?
    var lastWindowedPage: Int?
    var backgroundMode: BackgroundMode
    var solidColorHex: String?
    var gradientStartHex: String?
    var gradientEndHex: String?
    var blurIntensity: Double
    var iCloudSyncEnabled: Bool

    static let defaults = GridSettings(
        columns: 7,
        rows: 5,
        folderColumns: 4,
        folderRows: 3,
        iconScale: 1.0,
        scrollSensitivity: 1.0,
        useFullScreenLayout: true,
        lastWindowedWidth: nil,
        lastWindowedHeight: nil,
        lastWindowedPage: nil,
        backgroundMode: .wallpaperBlur,
        solidColorHex: nil,
        gradientStartHex: nil,
        gradientEndHex: nil,
        blurIntensity: 0.14,
        iCloudSyncEnabled: false
    )

    init(
        columns: Int,
        rows: Int,
        folderColumns: Int,
        folderRows: Int,
        iconScale: Double,
        scrollSensitivity: Double,
        useFullScreenLayout: Bool,
        lastWindowedWidth: Double? = nil,
        lastWindowedHeight: Double? = nil,
        lastWindowedPage: Int? = nil,
        backgroundMode: BackgroundMode = .wallpaperBlur,
        solidColorHex: String? = nil,
        gradientStartHex: String? = nil,
        gradientEndHex: String? = nil,
        blurIntensity: Double = 0.14,
        iCloudSyncEnabled: Bool = false
    ) {
        self.columns = columns
        self.rows = rows
        self.folderColumns = folderColumns
        self.folderRows = folderRows
        self.iconScale = iconScale
        self.scrollSensitivity = scrollSensitivity
        self.useFullScreenLayout = useFullScreenLayout
        self.lastWindowedWidth = lastWindowedWidth
        self.lastWindowedHeight = lastWindowedHeight
        self.lastWindowedPage = lastWindowedPage
        self.backgroundMode = backgroundMode
        self.solidColorHex = solidColorHex
        self.gradientStartHex = gradientStartHex
        self.gradientEndHex = gradientEndHex
        self.blurIntensity = blurIntensity
        self.iCloudSyncEnabled = iCloudSyncEnabled
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
        lastWindowedWidth = try container.decodeIfPresent(Double.self, forKey: .lastWindowedWidth)
        lastWindowedHeight =
            try container.decodeIfPresent(Double.self, forKey: .lastWindowedHeight)
        lastWindowedPage = try container.decodeIfPresent(Int.self, forKey: .lastWindowedPage)
        backgroundMode =
            try container.decodeIfPresent(BackgroundMode.self, forKey: .backgroundMode)
            ?? defaults.backgroundMode
        solidColorHex = try container.decodeIfPresent(String.self, forKey: .solidColorHex)
        gradientStartHex = try container.decodeIfPresent(String.self, forKey: .gradientStartHex)
        gradientEndHex = try container.decodeIfPresent(String.self, forKey: .gradientEndHex)
        blurIntensity =
            try container.decodeIfPresent(Double.self, forKey: .blurIntensity)
            ?? defaults.blurIntensity
        iCloudSyncEnabled =
            try container.decodeIfPresent(Bool.self, forKey: .iCloudSyncEnabled)
            ?? defaults.iCloudSyncEnabled
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
        try container.encodeIfPresent(lastWindowedWidth, forKey: .lastWindowedWidth)
        try container.encodeIfPresent(lastWindowedHeight, forKey: .lastWindowedHeight)
        try container.encodeIfPresent(lastWindowedPage, forKey: .lastWindowedPage)
        try container.encode(backgroundMode, forKey: .backgroundMode)
        try container.encodeIfPresent(solidColorHex, forKey: .solidColorHex)
        try container.encodeIfPresent(gradientStartHex, forKey: .gradientStartHex)
        try container.encodeIfPresent(gradientEndHex, forKey: .gradientEndHex)
        try container.encode(blurIntensity, forKey: .blurIntensity)
        try container.encode(iCloudSyncEnabled, forKey: .iCloudSyncEnabled)
    }

    var pageCapacity: Int {
        max(1, columns * rows)
    }

    var windowedSize: CGSize? {
        guard let width = lastWindowedWidth, let height = lastWindowedHeight else { return nil }
        return CGSize(width: width, height: height)
    }

    private enum CodingKeys: String, CodingKey {
        case columns
        case rows
        case folderColumns
        case folderRows
        case iconScale
        case scrollSensitivity
        case useFullScreenLayout
        case lastWindowedWidth
        case lastWindowedHeight
        case lastWindowedPage
        case backgroundMode
        case solidColorHex
        case gradientStartHex
        case gradientEndHex
        case blurIntensity
        case iCloudSyncEnabled
    }
}
