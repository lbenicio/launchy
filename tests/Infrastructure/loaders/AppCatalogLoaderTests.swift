import Foundation
import XCTest

@testable import Launchy

final class AppCatalogLoaderTests: XCTestCase {
  private var tempRoot: URL!

  override func setUpWithError() throws {
    try super.setUpWithError()
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("AppCatalogLoaderTests_\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    tempRoot = directory
  }

  override func tearDownWithError() throws {
    if let tempRoot {
      try? FileManager.default.removeItem(at: tempRoot)
    }
    tempRoot = nil
    try super.tearDownWithError()
  }

  func testLoadCatalogBuildsAppsAndFolders() async throws {
    let standaloneApp = tempRoot.appendingPathComponent("Independent.app", isDirectory: true)
    try createAppBundle(
      at: standaloneApp, displayName: "Independent", identifier: "com.example.independent")

    let folderURL = tempRoot.appendingPathComponent("utilities", isDirectory: true)
    try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
    let nestedApp = folderURL.appendingPathComponent("Utility.app", isDirectory: true)
    try createAppBundle(
      at: nestedApp,
      displayName: "Utility",
      identifier: "com.example.utility"
    )

    let loader = AppCatalogLoader(roots: [tempRoot])
    let entries = await loader.loadCatalog()

    XCTAssertTrue(
      entries.contains { entry in
        if case .app(let app) = entry {
          return app.displayName == "Independent"
            && app.bundleIdentifier == "com.example.independent"
        }
        return false
      })

    XCTAssertTrue(
      entries.contains { entry in
        if case .folder(let folder) = entry {
          return folder.name == "Utilities"
            && folder.apps.contains(where: { $0.displayName == "Utility" })
        }
        return false
      })
  }

  private func createAppBundle(at url: URL, displayName: String, identifier: String) throws {
    let contentsURL = url.appendingPathComponent("Contents", isDirectory: true)
    try FileManager.default.createDirectory(at: contentsURL, withIntermediateDirectories: true)
    let infoURL = contentsURL.appendingPathComponent("Info.plist", isDirectory: false)
    let plist: [String: Any] = [
      "CFBundleIdentifier": identifier,
      "CFBundleName": displayName,
      "CFBundleExecutable": displayName,
      "CFBundlePackageType": "APPL",
    ]
    let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
    try data.write(to: infoURL)
  }
}
