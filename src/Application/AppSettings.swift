import Combine
import Foundation

@MainActor
final class AppSettings: ObservableObject {
    @Published var gridColumns: Int {
        didSet { persist() }
    }

    @Published var gridRows: Int {
        didSet { persist() }
    }

    private let defaults: UserDefaults
    private let columnsKey = "settings.gridColumns"
    private let rowsKey = "settings.gridRows"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedColumns = defaults.integer(forKey: columnsKey)
        let storedRows = defaults.integer(forKey: rowsKey)
        gridColumns = (2...8).contains(storedColumns) ? storedColumns : 5
        gridRows = (2...6).contains(storedRows) ? storedRows : 3
    }

    private func persist() {
        defaults.set(gridColumns, forKey: columnsKey)
        defaults.set(gridRows, forKey: rowsKey)
    }
}
