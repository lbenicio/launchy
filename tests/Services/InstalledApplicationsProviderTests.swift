import XCTest

@testable import Launchy

final class InstalledApplicationsProviderTests: XCTestCase {
    private var tempDir: URL!
    private var stubFileManager: StubFileManager!

    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(
            "InstalledAppsTests-\(UUID().uuidString)", isDirectory: true
        )
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        stubFileManager = StubFileManager()
    }

    override func tearDown() async throws {
        stubFileManager = nil
        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        tempDir = nil
    }

    // MARK: - Helpers

    @discardableResult
    private func makeBundle(
        name: String,
        bundleID: String,
        displayName: String? = nil,
        in parentDir: URL
    ) throws -> URL {
        let appURL = parentDir.appendingPathComponent("\(name).app", isDirectory: true)
        let contentsDir = appURL.appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contentsDir, withIntermediateDirectories: true)

        var plist: [String: Any] = [
            "CFBundleIdentifier": bundleID,
            "CFBundleName": name,
        ]
        if let displayName {
            plist["CFBundleDisplayName"] = displayName
        }
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: contentsDir.appendingPathComponent("Info.plist"))
        return appURL
    }

    private func makeProvider(customDirs: [String]) -> InstalledApplicationsProvider {
        InstalledApplicationsProvider(fileManager: stubFileManager, customSearchDirectories: customDirs)
    }

    // MARK: - Tests

    func testFetchApplicationsReturnsEmptyWhenNoBundlesExist() {
        let emptyDir = tempDir.appendingPathComponent("empty", isDirectory: true)
        try? FileManager.default.createDirectory(at: emptyDir, withIntermediateDirectories: true)
        let provider = makeProvider(customDirs: [emptyDir.path])
        XCTAssertTrue(provider.fetchApplications().isEmpty)
    }

    func testFetchApplicationsFindsAppBundleInCustomDirectory() throws {
        try makeBundle(name: "TestApp", bundleID: "com.test.app", in: tempDir)
        let provider = makeProvider(customDirs: [tempDir.path])
        let apps = provider.fetchApplications()
        XCTAssertEqual(apps.count, 1)
        XCTAssertEqual(apps[0].bundleIdentifier, "com.test.app")
        XCTAssertEqual(apps[0].name, "TestApp")
    }

    func testFetchApplicationsUsesDisplayNameWhenAvailable() throws {
        try makeBundle(
            name: "AppInternal", bundleID: "com.test.display",
            displayName: "My App", in: tempDir
        )
        let provider = makeProvider(customDirs: [tempDir.path])
        XCTAssertEqual(provider.fetchApplications().first?.name, "My App")
    }

    func testFetchApplicationsDeduplicatesByBundleIdentifier() throws {
        // dirA and dirB are siblings so scanning each individually produces one
        // app per directory — neither directory is enumerated twice.
        let dirA = tempDir.appendingPathComponent("dirA", isDirectory: true)
        let dirB = tempDir.appendingPathComponent("dirB", isDirectory: true)
        try FileManager.default.createDirectory(at: dirA, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dirB, withIntermediateDirectories: true)
        try makeBundle(name: "First",  bundleID: "com.test.dup", in: dirA)
        try makeBundle(name: "Second", bundleID: "com.test.dup", in: dirB)

        let provider = makeProvider(customDirs: [dirA.path, dirB.path])
        let matching = provider.fetchApplications().filter { $0.bundleIdentifier == "com.test.dup" }
        XCTAssertEqual(matching.count, 1, "Duplicate bundle IDs should be deduplicated")
        XCTAssertEqual(matching.first?.name, "First", "First-seen directory should win")
    }

    func testFetchApplicationsReturnsSortedAlphabetically() throws {
        try makeBundle(name: "Zephyr", bundleID: "com.test.z", in: tempDir)
        try makeBundle(name: "Alpha",  bundleID: "com.test.a", in: tempDir)
        try makeBundle(name: "Mango",  bundleID: "com.test.m", in: tempDir)
        let provider = makeProvider(customDirs: [tempDir.path])
        let names = provider.fetchApplications().map(\.name)
        XCTAssertEqual(names, ["Alpha", "Mango", "Zephyr"])
    }
}
