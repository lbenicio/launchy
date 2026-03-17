import XCTest

@testable import Launchy

final class GridSettingsTests: XCTestCase {

    // MARK: - Default Settings Tests

    func testDefaultSettings() {
        let defaults = GridSettings.defaults

        XCTAssertEqual(defaults.columns, 7, "Default columns should be 7")
        XCTAssertEqual(defaults.rows, 5, "Default rows should be 5")
        XCTAssertEqual(defaults.folderColumns, 4, "Default folder columns should be 4")
        XCTAssertEqual(defaults.folderRows, 3, "Default folder rows should be 3")
        XCTAssertEqual(defaults.iconScale, 1.0, "Default icon scale should be 1.0")
        XCTAssertEqual(defaults.scrollSensitivity, 1.0, "Default scroll sensitivity should be 1.0")
        XCTAssertTrue(defaults.useFullScreenLayout, "Default should use full screen layout")
        XCTAssertEqual(
            defaults.backgroundMode,
            .wallpaperBlur,
            "Default background should be wallpaper blur"
        )
        XCTAssertEqual(defaults.blurIntensity, 0.14, "Default blur intensity should be 0.14")
        XCTAssertFalse(defaults.iCloudSyncEnabled, "iCloud sync should be disabled by default")
        XCTAssertEqual(defaults.hotkeyKeyCode, 118, "Default hotkey should be F4 (keyCode 118)")

        // Test new customization options
        XCTAssertEqual(
            defaults.pageTransitionDuration,
            0.3,
            "Default page transition duration should be 0.3"
        )
        XCTAssertEqual(
            defaults.folderAnimationDuration,
            0.25,
            "Default folder animation duration should be 0.25"
        )
        XCTAssertTrue(defaults.showAppBadges, "App badges should be shown by default")
        XCTAssertTrue(
            defaults.showRecentlyAddedIndicator,
            "Recently added indicator should be shown by default"
        )
        XCTAssertTrue(
            defaults.animateAppLaunch,
            "App launch animation should be enabled by default"
        )
        XCTAssertTrue(defaults.showSearchBar, "Search bar should be shown by default")
        XCTAssertTrue(
            defaults.enableSpotlightSearch,
            "Spotlight search should be enabled by default"
        )
        XCTAssertFalse(
            defaults.showDashboardWidgets,
            "Dashboard widgets should be hidden by default"
        )
        XCTAssertEqual(defaults.iconSpacing, 8.0, "Default icon spacing should be 8.0")
        XCTAssertEqual(defaults.appNameFontSize, 12.0, "Default app name font size should be 12.0")
        XCTAssertTrue(defaults.showAppNames, "App names should be shown by default")
        XCTAssertEqual(defaults.theme, .system, "Default theme should be system")
        XCTAssertEqual(
            defaults.headerControlsAutoHideDelay,
            3.0,
            "Default header auto-hide delay should be 3.0"
        )
        XCTAssertFalse(defaults.enableSoundEffects, "Sound effects should be disabled by default")
        XCTAssertEqual(
            defaults.soundEffectsVolume,
            0.5,
            "Default sound effects volume should be 0.5"
        )
    }

    func testPageCapacityReflectsLayout() {
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

        // Test new customization options with defaults
        XCTAssertEqual(decoded.pageTransitionDuration, GridSettings.defaults.pageTransitionDuration)
        XCTAssertEqual(decoded.showAppBadges, GridSettings.defaults.showAppBadges)
        XCTAssertEqual(decoded.theme, GridSettings.defaults.theme)
        XCTAssertEqual(decoded.enableSoundEffects, GridSettings.defaults.enableSoundEffects)
    }

    // MARK: - New Customization Options Tests

    func testCustomInitializationWithNewOptions() {
        let customSettings = GridSettings(
            columns: 6,
            rows: 4,
            folderColumns: 3,
            folderRows: 2,
            iconScale: 0.8,
            scrollSensitivity: 1.2,
            useFullScreenLayout: false,
            backgroundMode: .solidColor,
            solidColorHex: "#FF0000",
            blurIntensity: 0.2,
            iCloudSyncEnabled: true,
            customSearchDirectories: ["/Custom/Apps"],
            hotkeyKeyCode: 115,
            pageTransitionDuration: 0.5,
            folderAnimationDuration: 0.3,
            showAppBadges: false,
            showRecentlyAddedIndicator: false,
            animateAppLaunch: false,
            showSearchBar: false,
            enableSpotlightSearch: false,
            showDashboardWidgets: true,
            iconSpacing: 10.0,
            appNameFontSize: 14.0,
            showAppNames: false,
            theme: .dark,
            headerControlsAutoHideDelay: 5.0,
            enableSoundEffects: true,
            soundEffectsVolume: 0.8
        )

        XCTAssertEqual(customSettings.pageTransitionDuration, 0.5)
        XCTAssertFalse(customSettings.showAppBadges)
        XCTAssertTrue(customSettings.showDashboardWidgets)
        XCTAssertEqual(customSettings.theme, .dark)
        XCTAssertTrue(customSettings.enableSoundEffects)
        XCTAssertEqual(customSettings.soundEffectsVolume, 0.8)
    }

    // MARK: - Codable Tests for New Options

    func testNewOptionsCodable() throws {
        let originalSettings = GridSettings.defaults

        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalSettings)

        // Decode
        let decoder = JSONDecoder()
        let decodedSettings = try decoder.decode(GridSettings.self, from: data)

        // Test new customization options
        XCTAssertEqual(
            decodedSettings.pageTransitionDuration,
            originalSettings.pageTransitionDuration
        )
        XCTAssertEqual(
            decodedSettings.folderAnimationDuration,
            originalSettings.folderAnimationDuration
        )
        XCTAssertEqual(decodedSettings.showAppBadges, originalSettings.showAppBadges)
        XCTAssertEqual(
            decodedSettings.showRecentlyAddedIndicator,
            originalSettings.showRecentlyAddedIndicator
        )
        XCTAssertEqual(decodedSettings.animateAppLaunch, originalSettings.animateAppLaunch)
        XCTAssertEqual(decodedSettings.showSearchBar, originalSettings.showSearchBar)
        XCTAssertEqual(
            decodedSettings.enableSpotlightSearch,
            originalSettings.enableSpotlightSearch
        )
        XCTAssertEqual(decodedSettings.showDashboardWidgets, originalSettings.showDashboardWidgets)
        XCTAssertEqual(decodedSettings.iconSpacing, originalSettings.iconSpacing)
        XCTAssertEqual(decodedSettings.appNameFontSize, originalSettings.appNameFontSize)
        XCTAssertEqual(decodedSettings.showAppNames, originalSettings.showAppNames)
        XCTAssertEqual(decodedSettings.theme, originalSettings.theme)
        XCTAssertEqual(
            decodedSettings.headerControlsAutoHideDelay,
            originalSettings.headerControlsAutoHideDelay
        )
        XCTAssertEqual(decodedSettings.enableSoundEffects, originalSettings.enableSoundEffects)
        XCTAssertEqual(decodedSettings.soundEffectsVolume, originalSettings.soundEffectsVolume)
    }

    // MARK: - InterfaceTheme Tests

    func testInterfaceThemeCases() {
        let themes = InterfaceTheme.allCases
        let expectedThemes: [InterfaceTheme] = [.system, .light, .dark]

        XCTAssertEqual(themes, expectedThemes, "Should have all expected interface themes")
    }

    func testInterfaceThemeCodable() throws {
        let themes: [InterfaceTheme] = [.system, .light, .dark]

        for theme in themes {
            let data = try JSONEncoder().encode(theme)
            let decodedTheme = try JSONDecoder().decode(InterfaceTheme.self, from: data)
            XCTAssertEqual(theme, decodedTheme, "Interface theme \(theme) should be codable")
        }
    }
}
