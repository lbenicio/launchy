import Foundation
import XCTest

@testable import Launchy

@MainActor
final class LayoutPersistenceTests: XCTestCase {
  private var tempURL: URL!

  override func setUpWithError() throws {
    try super.setUpWithError()
    let directory = FileManager.default.temporaryDirectory
    tempURL = directory.appendingPathComponent("LayoutPersistenceTests_\(UUID().uuidString).json")
  }

  override func tearDownWithError() throws {
    if let tempURL {
      try? FileManager.default.removeItem(at: tempURL)
    }
    tempURL = nil
    try super.tearDownWithError()
  }

  func testSaveThenLoadSnapshot() async throws {
    let persistence = LayoutPersistence(fileURL: tempURL)
    let app = AppItem(
      id: "app-1",
      displayName: "Notes",
      bundleIdentifier: "com.example.notes",
      bundleURL: URL(fileURLWithPath: "/Applications/Notes.app")
    )
    let folder = FolderItem(id: "folder-1", name: "Work", apps: [app])
    let entries: [CatalogEntry] = [.app(app), .folder(folder)]

    await persistence.save(entries: entries)
    let snapshot = await persistence.loadSnapshot()

    XCTAssertNotNil(snapshot)
    XCTAssertEqual(snapshot?.entries.count, 2)
  }
}
