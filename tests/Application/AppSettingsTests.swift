import XCTest

@testable import Launchy

@MainActor
final class AppSettingsTests: XCTestCase {
  func testInitializerUsesDefaultsWhenStoredValuesAreMissing() {
    let suiteName = "AppSettingsTests_\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
      XCTFail("Failed to create user defaults suite")
      return
    }
    defaults.removePersistentDomain(forName: suiteName)
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let settings = AppSettings(defaults: defaults)

    XCTAssertEqual(settings.gridColumns, 5)
    XCTAssertEqual(settings.gridRows, 3)
    XCTAssertEqual(settings.scrollThreshold, AppSettings.defaultScrollThreshold)
  }

  func testScrollThresholdIsClampedWhenSetting() {
    let suiteName = "AppSettingsTestsClamp_\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
      XCTFail("Failed to create user defaults suite")
      return
    }
    defaults.removePersistentDomain(forName: suiteName)
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let settings = AppSettings(defaults: defaults)
    settings.scrollThreshold = AppSettings.scrollThresholdRange.upperBound + 40
    XCTAssertEqual(settings.scrollThreshold, AppSettings.scrollThresholdRange.upperBound)

    settings.scrollThreshold = AppSettings.scrollThresholdRange.lowerBound - 20
    XCTAssertEqual(settings.scrollThreshold, AppSettings.scrollThresholdRange.lowerBound)
  }
}
