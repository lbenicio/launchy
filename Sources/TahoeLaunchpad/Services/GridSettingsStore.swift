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
    private let settingsKey = "com.tahoe.launchpad.grid-settings"

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
        columns: Int? = nil, rows: Int? = nil, folderColumns: Int? = nil, folderRows: Int? = nil,
        iconScale: Double? = nil
    ) {
        var next = settings
        if let columns { next.columns = max(3, min(columns, 10)) }
        if let rows { next.rows = max(3, min(rows, 10)) }
        if let folderColumns { next.folderColumns = max(2, min(folderColumns, 8)) }
        if let folderRows { next.folderRows = max(2, min(folderRows, 8)) }
        if let iconScale { next.iconScale = min(max(iconScale, 0.7), 1.5) }
        settings = next
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: settingsKey)
    }
}
