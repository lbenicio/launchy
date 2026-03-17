import SwiftUI
import Foundation

struct DashboardWidget: Identifiable, Codable, Equatable, Hashable, Sendable {
    let id: UUID
    let name: String
    let bundleIdentifier: String
    let widgetType: WidgetType
    let iconName: String
    let description: String
    
    enum WidgetType: String, Codable, CaseIterable {
        case weather = "com.apple.weather"
        case stocks = "com.apple.stocks"
        case calculator = "com.apple.calculator"
        case calendar = "com.apple.calendar"
        case clock = "com.apple.clock"
        case notes = "com.apple.notes"
        case reminders = "com.apple.reminders"
        case systemPreferences = "com.apple.systempreferences"
        
        var displayName: String {
            switch self {
            case .weather: return "Weather"
            case .stocks: return "Stocks"
            case .calculator: return "Calculator"
            case .calendar: return "Calendar"
            case .clock: return "Clock"
            case .notes: return "Notes"
            case .reminders: return "Reminders"
            case .systemPreferences: return "System Preferences"
            }
        }
        
        var systemIconName: String {
            switch self {
            case .weather: return "cloud.sun"
            case .stocks: return "chart.line.uptrend.xyaxis"
            case .calculator: return "calculator"
            case .calendar: return "calendar"
            case .clock: return "clock"
            case .notes: return "note.text"
            case .reminders: return "checklist"
            case .systemPreferences: return "gear"
            }
        }
        
        var defaultDescription: String {
            switch self {
            case .weather: return "View weather information and forecasts"
            case .stocks: return "Track stock prices and market data"
            case .calculator: return "Perform calculations"
            case .calendar: return "View and manage calendar events"
            case .clock: return "View current time and set alarms"
            case .notes: return "Create and view notes"
            case .reminders: return "Manage reminders and tasks"
            case .systemPreferences: return "Access system settings"
            }
        }
    }
    
    init(id: UUID = UUID(), type: WidgetType) {
        self.id = id
        self.name = type.displayName
        self.bundleIdentifier = type.rawValue
        self.widgetType = type
        self.iconName = type.systemIconName
        self.description = type.defaultDescription
    }
    
    init(id: UUID = UUID(), name: String, bundleIdentifier: String, widgetType: WidgetType, iconName: String, description: String) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.widgetType = widgetType
        self.iconName = iconName
        self.description = description
    }
}

/// Provides access to Dashboard widgets that were available in older macOS versions
@MainActor
final class DashboardWidgetProvider: ObservableObject {
    static let shared = DashboardWidgetProvider()
    
    @Published var availableWidgets: [DashboardWidget] = []
    @Published var enabledWidgets: [DashboardWidget] = []
    
    private init() {
        loadAvailableWidgets()
        loadEnabledWidgets()
    }
    
    private func loadAvailableWidgets() {
        availableWidgets = DashboardWidget.WidgetType.allCases.map { DashboardWidget(type: $0) }
    }
    
    private func loadEnabledWidgets() {
        // For now, enable all available widgets
        // In a real implementation, this would be loaded from user preferences
        enabledWidgets = availableWidgets
    }
    
    func launchWidget(_ widget: DashboardWidget) {
        #if os(macOS)
        // Try to launch the corresponding app or open Dashboard
        let workspace = NSWorkspace.shared
        
        // First try to launch by bundle identifier
        if let url = workspace.urlForApplication(withBundleIdentifier: widget.bundleIdentifier) {
            workspace.open(url)
        } else {
            // Fallback: try to open the app by name
            workspace.open(URL(fileURLWithPath: "/Applications/\(widget.name).app"))
        }
        #endif
    }
    
    func toggleWidget(_ widget: DashboardWidget) {
        if enabledWidgets.contains(where: { $0.id == widget.id }) {
            enabledWidgets.removeAll { $0.id == widget.id }
        } else {
            enabledWidgets.append(widget)
        }
        saveEnabledWidgets()
    }
    
    private func saveEnabledWidgets() {
        // In a real implementation, this would save to UserDefaults or a preferences file
        // For now, we'll just keep it in memory
    }
}

// MARK: - LaunchyItem Extension for Widgets

extension LaunchyItem {
    static func widget(_ widget: DashboardWidget) -> LaunchyItem {
        return .widget(widget)
    }
    
    var asWidget: DashboardWidget? {
        if case .widget(let widget) = self { return widget }
        return nil
    }
    
    var isWidget: Bool {
        if case .widget = self { return true }
        return false
    }
}
