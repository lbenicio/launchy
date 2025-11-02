import Combine
import Foundation

@MainActor
final class AppSettings: ObservableObject {
  static let scrollThresholdRange: ClosedRange<Double> = 1...120
  static let defaultScrollThreshold: Double = 1

    @Published var gridColumns: Int {
        didSet { persist() }
    }

    @Published var gridRows: Int {
        didSet { persist() }
    }

  @Published var scrollThreshold: Double {
    didSet {
      let clamped = AppSettings.clampScrollThreshold(scrollThreshold)
      if scrollThreshold != clamped {
        scrollThreshold = clamped
        return
      }
      persist()
    }
  }

    private let defaults: UserDefaults
    private let columnsKey = "settings.gridColumns"
    private let rowsKey = "settings.gridRows"
  private let scrollThresholdKey = "settings.scrollThreshold"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedColumns = defaults.integer(forKey: columnsKey)
        let storedRows = defaults.integer(forKey: rowsKey)
    let storedThreshold = defaults.object(forKey: scrollThresholdKey) as? Double
        gridColumns = (2...8).contains(storedColumns) ? storedColumns : 5
        gridRows = (2...6).contains(storedRows) ? storedRows : 3
    if let storedThreshold {
      scrollThreshold = AppSettings.clampScrollThreshold(storedThreshold)
    } else {
      scrollThreshold = AppSettings.defaultScrollThreshold
    }
    }

    private func persist() {
        defaults.set(gridColumns, forKey: columnsKey)
        defaults.set(gridRows, forKey: rowsKey)
    defaults.set(scrollThreshold, forKey: scrollThresholdKey)
  }

  private static func clampScrollThreshold(_ value: Double) -> Double {
    min(max(value, scrollThresholdRange.lowerBound), scrollThresholdRange.upperBound)
    }
}
