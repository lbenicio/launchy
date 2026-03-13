import Combine
import Foundation

@MainActor
final class GridSettingsStore: ObservableObject {
    @Published var settings: GridSettings {
        didSet {
            persist()
        }
    }

    private let defaults: UserDefaults
    private let settingsKey = "dev.lbenicio.launchy.grid-settings"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: settingsKey),
            let stored = try? JSONDecoder().decode(GridSettings.self, from: data)
        {
            settings = stored
        } else {
            settings = .defaults
        }
    }

    func update(
        columns: Int? = nil,
        rows: Int? = nil,
        folderColumns: Int? = nil,
        folderRows: Int? = nil,
        iconScale: Double? = nil,
        scrollSensitivity: Double? = nil,
        useFullScreenLayout: Bool? = nil,
        windowedWidth: Double? = nil,
        windowedHeight: Double? = nil,
        lastWindowedPage: Int? = nil,
        backgroundMode: BackgroundMode? = nil,
        solidColorHex: String? = nil,
        clearSolidColor: Bool = false,
        gradientStartHex: String? = nil,
        clearGradientStart: Bool = false,
        gradientEndHex: String? = nil,
        clearGradientEnd: Bool = false,
        blurIntensity: Double? = nil,
        iCloudSyncEnabled: Bool? = nil,
        customSearchDirectories: [String]? = nil
    ) {
        var next = settings
        if let columns { next.columns = max(3, min(columns, 10)) }
        if let rows { next.rows = max(3, min(rows, 10)) }
        if let folderColumns { next.folderColumns = max(2, min(folderColumns, 8)) }
        if let folderRows { next.folderRows = max(2, min(folderRows, 8)) }
        if let iconScale { next.iconScale = min(max(iconScale, 0.7), 1.5) }
        if let scrollSensitivity {
            next.scrollSensitivity = min(max(scrollSensitivity, 0.2), 2.0)
        }
        if let useFullScreenLayout {
            next.useFullScreenLayout = useFullScreenLayout
        }
        if let windowedWidth, windowedWidth.isFinite {
            next.lastWindowedWidth = max(800, min(windowedWidth, 6000))
        }
        if let windowedHeight, windowedHeight.isFinite {
            next.lastWindowedHeight = max(600, min(windowedHeight, 4000))
        }
        if let lastWindowedPage {
            next.lastWindowedPage = max(0, lastWindowedPage)
        }
        if let backgroundMode { next.backgroundMode = backgroundMode }
        if clearSolidColor {
            next.solidColorHex = nil
        } else if let solidColorHex {
            next.solidColorHex = solidColorHex
        }
        if clearGradientStart {
            next.gradientStartHex = nil
        } else if let gradientStartHex {
            next.gradientStartHex = gradientStartHex
        }
        if clearGradientEnd {
            next.gradientEndHex = nil
        } else if let gradientEndHex {
            next.gradientEndHex = gradientEndHex
        }
        if let blurIntensity { next.blurIntensity = min(max(blurIntensity, 0.0), 1.0) }
        if let iCloudSyncEnabled { next.iCloudSyncEnabled = iCloudSyncEnabled }
        if let customSearchDirectories {
            next.customSearchDirectories = customSearchDirectories
        }
        settings = next
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: settingsKey)
    }
}
