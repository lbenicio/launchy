import XCTest
@testable import Launchy

@MainActor
final class AppExclusionServiceTests: XCTestCase {
    private var exclusionService: AppExclusionService!
    private var testApps: [AppIcon]!
    private var testItems: [LaunchyItem]!
    
    override func setUp() async throws {
        exclusionService = AppExclusionService.shared
        
        // Create test data
        testApps = [
            AppIcon(name: "Safari", bundleIdentifier: "com.apple.safari", bundleURL: URL(fileURLWithPath: "/Applications/Safari.app")),
            AppIcon(name: "Mail", bundleIdentifier: "com.apple.mail", bundleURL: URL(fileURLWithPath: "/Applications/Mail.app")),
            AppIcon(name: "Calendar", bundleIdentifier: "com.apple.calendar", bundleURL: URL(fileURLWithPath: "/Applications/Calendar.app")),
            AppIcon(name: "TestApp", bundleIdentifier: "com.test.app", bundleURL: URL(fileURLWithPath: "/Applications/TestApp.app"))
        ]
        
        testItems = testApps.map { LaunchyItem.app($0) }
        
        // Clear any existing exclusions
        exclusionService.includeAllApps()
    }
    
    override func tearDown() async throws {
        exclusionService.includeAllApps()
        exclusionService = nil
        testApps = nil
        testItems = nil
    }
    
    // MARK: - Exclusion Tests
    
    func testExcludeApp() async throws {
        let safariApp = testApps.first { $0.bundleIdentifier == "com.apple.safari" }!
        
        exclusionService.excludeApp(safariApp)
        
        XCTAssertTrue(exclusionService.isAppExcluded(safariApp), "Safari should be excluded")
        XCTAssertTrue(exclusionService.excludedBundleIDs.contains("com.apple.safari"), "Safari bundle ID should be in excluded list")
    }
    
    func testIncludeApp() async throws {
        let safariApp = testApps.first { $0.bundleIdentifier == "com.apple.safari" }!
        
        // First exclude
        exclusionService.excludeApp(safariApp)
        XCTAssertTrue(exclusionService.isAppExcluded(safariApp))
        
        // Then include
        exclusionService.includeApp(safariApp)
        XCTAssertFalse(exclusionService.isAppExcluded(safariApp), "Safari should no longer be excluded")
        XCTAssertFalse(exclusionService.excludedBundleIDs.contains("com.apple.safari"), "Safari bundle ID should be removed from excluded list")
    }
    
    func testFilterExcludedApps() async throws {
        // Exclude Safari and Mail
        let appsToExclude = Array(testApps.prefix(2))
        for app in appsToExclude {
            exclusionService.excludeApp(app)
        }
        
        let filteredApps = exclusionService.filterExcludedApps(testApps)
        
        XCTAssertEqual(filteredApps.count, testApps.count - appsToExclude.count, "Should have filtered out excluded apps")
        
        // Check that excluded apps are not in filtered list
        for excludedApp in appsToExclude {
            XCTAssertFalse(filteredApps.contains(excludedApp), "\(excludedApp.name) should not be in filtered list")
        }
        
        // Check that non-excluded apps are in filtered list
        let nonExcludedApps = Array(testApps.suffix(2))
        for nonExcludedApp in nonExcludedApps {
            XCTAssertTrue(filteredApps.contains(nonExcludedApp), "\(nonExcludedApp.name) should be in filtered list")
        }
    }
    
    func testDefaultExclusions() async throws {
        // Clear current exclusions
        exclusionService.includeAllApps()
        
        // Add default exclusions
        exclusionService.addDefaultExclusions()
        
        XCTAssertFalse(exclusionService.excludedBundleIDs.isEmpty, "Should have default exclusions")
        
        // Check for common system apps
        let commonSystemApps = [
            "com.apple.finder",
            "com.apple.systempreferences",
            "com.apple.ActivityMonitor",
            "com.apple.Console",
            "com.apple.dock",
            "com.apple.loginwindow",
            "com.apple.screencaptureui",
            "com.apple.screenshot.services",
            "com.apple.spotlight",
            "com.apple.Terminal"
        ]
        
        for systemApp in commonSystemApps {
            XCTAssertTrue(exclusionService.excludedBundleIDs.contains(systemApp), "Should exclude \(systemApp)")
        }
    }
}
