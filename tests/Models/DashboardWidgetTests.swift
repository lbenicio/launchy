import XCTest

@testable import Launchy

@MainActor
final class DashboardWidgetTests: XCTestCase {

    // MARK: - Widget Creation Tests

    func testWidgetCreation() {
        let widget = DashboardWidget(type: .weather)

        XCTAssertEqual(widget.widgetType, .weather)
        XCTAssertEqual(widget.name, "Weather")
        XCTAssertEqual(widget.bundleIdentifier, "com.apple.weather")
        XCTAssertEqual(widget.iconName, "cloud.sun")
    }

    func testAllWidgetTypes() {
        let allTypes = DashboardWidget.WidgetType.allCases

        XCTAssertEqual(allTypes.count, 8, "Should have 8 widget types")

        let expectedTypes: [DashboardWidget.WidgetType] = [
            .weather, .stocks, .calculator, .calendar,
            .clock, .notes, .reminders, .systemPreferences,
        ]

        XCTAssertEqual(allTypes, expectedTypes, "Should have all expected widget types")
    }

    func testWidgetProperties() {
        let testCases: [(DashboardWidget.WidgetType, String, String, String)] = [
            (.weather, "Weather", "com.apple.weather", "cloud.sun"),
            (.stocks, "Stocks", "com.apple.stocks", "chart.line.uptrend.xyaxis"),
            (.calculator, "Calculator", "com.apple.calculator", "calculator"),
            (.calendar, "Calendar", "com.apple.calendar", "calendar"),
            (.clock, "Clock", "com.apple.clock", "clock"),
            (.notes, "Notes", "com.apple.notes", "note.text"),
            (.reminders, "Reminders", "com.apple.reminders", "checklist"),
            (.systemPreferences, "System Preferences", "com.apple.systempreferences", "gear"),
        ]

        for (type, expectedName, expectedBundleID, expectedIcon) in testCases {
            let widget = DashboardWidget(type: type)

            XCTAssertEqual(widget.widgetType, type, "Widget type should match")
            XCTAssertEqual(widget.name, expectedName, "Widget name should match for \(type)")
            XCTAssertEqual(
                widget.bundleIdentifier,
                expectedBundleID,
                "Bundle identifier should match for \(type)"
            )
            XCTAssertEqual(widget.iconName, expectedIcon, "Icon name should match for \(type)")
        }
    }

    // MARK: - Widget Provider Tests

    func testDashboardWidgetProvider() {
        let provider = DashboardWidgetProvider.shared

        // Test available widgets
        let availableWidgets = provider.availableWidgets
        XCTAssertEqual(availableWidgets.count, 8, "Should have 8 available widgets")

        // Test that all widget types are represented
        let widgetTypes = availableWidgets.map { $0.widgetType }
        let allTypes = Set(DashboardWidget.WidgetType.allCases)
        let availableTypes = Set(widgetTypes)

        XCTAssertEqual(allTypes, availableTypes, "All widget types should be available")
    }

    func testEnabledWidgets() {
        let provider = DashboardWidgetProvider.shared

        // Initially, all widgets should be enabled (based on current implementation)
        XCTAssertEqual(provider.enabledWidgets.count, 8, "Initially all widgets should be enabled")

        // Toggle a widget to disable it
        let weatherWidget = provider.availableWidgets.first { $0.widgetType == .weather }!
        provider.toggleWidget(weatherWidget)

        XCTAssertEqual(provider.enabledWidgets.count, 7, "Should have 7 enabled widgets")
        XCTAssertFalse(
            provider.enabledWidgets.contains(where: { $0.widgetType == .weather }),
            "Weather widget should be disabled"
        )

        // Toggle it back to enable
        provider.toggleWidget(weatherWidget)

        XCTAssertEqual(provider.enabledWidgets.count, 8, "Should have 8 enabled widgets again")
        XCTAssertTrue(
            provider.enabledWidgets.contains(where: { $0.widgetType == .weather }),
            "Weather widget should be enabled"
        )
    }

    func testIsWidgetEnabled() {
        let provider = DashboardWidgetProvider.shared
        let weatherWidget = provider.availableWidgets.first { $0.widgetType == .weather }!

        // Initially should be enabled
        XCTAssertTrue(
            provider.enabledWidgets.contains(where: { $0.id == weatherWidget.id }),
            "Widget should initially be enabled"
        )

        // Disable widget
        provider.toggleWidget(weatherWidget)
        XCTAssertFalse(
            provider.enabledWidgets.contains(where: { $0.id == weatherWidget.id }),
            "Widget should be disabled"
        )

        // Enable widget
        provider.toggleWidget(weatherWidget)
        XCTAssertTrue(
            provider.enabledWidgets.contains(where: { $0.id == weatherWidget.id }),
            "Widget should be enabled again"
        )
    }

    // MARK: - Widget Launch Tests

    func testWidgetLaunch() {
        let provider = DashboardWidgetProvider.shared
        let calculatorWidget = provider.availableWidgets.first { $0.widgetType == .calculator }!

        // This test verifies that the launch method exists and doesn't crash
        // In a real test environment, we would mock the workspace
        XCTAssertNoThrow(
            provider.launchWidget(calculatorWidget),
            "Widget launch should not throw an exception"
        )
    }

    // MARK: - Widget Equality Tests

    func testWidgetEquality() {
        let widget1 = DashboardWidget(type: .weather)
        let widget2 = DashboardWidget(type: .weather)
        let widget3 = DashboardWidget(type: .calculator)

        // Widgets of same type should be equal in terms of type, but not necessarily equal objects
        // since they have different UUIDs
        XCTAssertEqual(
            widget1.widgetType,
            widget2.widgetType,
            "Widgets of same type should have same type"
        )
        XCTAssertNotEqual(
            widget1.widgetType,
            widget3.widgetType,
            "Widgets of different types should not be equal"
        )
    }

    func testWidgetHashability() {
        let widget1 = DashboardWidget(type: .weather)
        let widget2 = DashboardWidget(type: .weather)
        let widget3 = DashboardWidget(type: .calculator)

        // Hash values should be different because each widget has a unique UUID
        // This is expected behavior for Identifiable objects
        XCTAssertNotEqual(
            widget1.hashValue,
            widget2.hashValue,
            "Widgets should have different hashes due to unique UUIDs"
        )
        XCTAssertNotEqual(
            widget1.hashValue,
            widget3.hashValue,
            "Widgets of different types should have different hashes"
        )

        // But widgets of same type should be equal when compared by type
        XCTAssertEqual(widget1.widgetType, widget2.widgetType)
    }

    // MARK: - Widget Coding Tests

    func testWidgetCodable() throws {
        let originalWidget = DashboardWidget(type: .weather)

        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalWidget)

        // Decode
        let decoder = JSONDecoder()
        let decodedWidget = try decoder.decode(DashboardWidget.self, from: data)

        XCTAssertEqual(
            originalWidget.widgetType,
            decodedWidget.widgetType,
            "Widget type should be preserved"
        )
        XCTAssertEqual(originalWidget.name, decodedWidget.name, "Widget name should be preserved")
        XCTAssertEqual(
            originalWidget.bundleIdentifier,
            decodedWidget.bundleIdentifier,
            "Bundle identifier should be preserved"
        )
        XCTAssertEqual(
            originalWidget.iconName,
            decodedWidget.iconName,
            "Icon name should be preserved"
        )
    }

    // MARK: - Edge Cases

    func testWidgetProviderSingleton() {
        let provider1 = DashboardWidgetProvider.shared
        let provider2 = DashboardWidgetProvider.shared

        XCTAssertTrue(provider1 === provider2, "DashboardWidgetProvider should be a singleton")
    }

    func testToggleDuplicateWidget() {
        let provider = DashboardWidgetProvider.shared
        let weatherWidget = provider.availableWidgets.first { $0.widgetType == .weather }!
        let weatherWidget2 = provider.availableWidgets.first { $0.widgetType == .weather }!

        // Both widgets should have the same ID since they're the same type
        XCTAssertEqual(weatherWidget.id, weatherWidget2.id, "Same widget types should have same ID")

        // Toggle first widget
        provider.toggleWidget(weatherWidget)
        XCTAssertEqual(provider.enabledWidgets.count, 7, "Should have 7 enabled widgets")

        // Toggle second widget (same type)
        provider.toggleWidget(weatherWidget2)
        XCTAssertEqual(provider.enabledWidgets.count, 8, "Should have 8 enabled widgets again")
    }

    func testToggleNonExistentWidget() {
        let provider = DashboardWidgetProvider.shared
        let customWidget = DashboardWidget(
            id: UUID(),
            name: "Custom Widget",
            bundleIdentifier: "com.custom.widget",
            widgetType: .calculator,
            iconName: "star",
            description: "A custom widget"
        )

        // Toggle custom widget (not in available widgets)
        provider.toggleWidget(customWidget)

        // Should be added to enabled widgets
        XCTAssertTrue(
            provider.enabledWidgets.contains(where: { $0.id == customWidget.id }),
            "Custom widget should be added"
        )

        // Toggle again to remove
        provider.toggleWidget(customWidget)

        // Should be removed
        XCTAssertFalse(
            provider.enabledWidgets.contains(where: { $0.id == customWidget.id }),
            "Custom widget should be removed"
        )
    }
}
