import Foundation

actor LayoutPersistence {
  private let fileURL: URL

  init(fileURL: URL? = nil) {
    if let fileURL {
      self.fileURL = fileURL
    } else {
      let defaultDirectory = LayoutPersistence.defaultDirectory()
      self.fileURL = defaultDirectory.appendingPathComponent("layout.json", isDirectory: false)
    }
  }

  func loadSnapshot() -> Snapshot? {
    guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
    guard let data = try? Data(contentsOf: fileURL) else { return nil }
    let decoder = JSONDecoder()
    return try? decoder.decode(Snapshot.self, from: data)
  }

  func save(entries: [CatalogEntry]) {
    let snapshot = Snapshot(entries: entries.compactMap { LayoutEntry(entry: $0) })
    do {
      try ensureDirectoryExists()
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      let data = try encoder.encode(snapshot)
      try data.write(to: fileURL, options: .atomic)
    } catch {
      #if DEBUG
        print("LayoutPersistence.save error: \(error)")
      #endif
    }
  }

  private func ensureDirectoryExists() throws {
    let directory = fileURL.deletingLastPathComponent()
    if !FileManager.default.fileExists(atPath: directory.path) {
      try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true,
        attributes: nil
      )
    }
  }

  private static func defaultDirectory() -> URL {
    if let support = FileManager.default.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    ).first {
      return support.appendingPathComponent("Launchy", isDirectory: true)
    }
    return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(
      "Library/Application Support/Launchy",
      isDirectory: true
    )
  }
}

extension LayoutPersistence {
  struct Snapshot: Codable {
    let entries: [LayoutEntry]
  }

  enum LayoutEntry: Codable {
    case app(String)
    case folder(FolderLayout)

    private enum CodingKeys: String, CodingKey {
      case type
      case id
      case name
      case apps
    }

    init(entry: CatalogEntry) {
      switch entry {
      case .app(let app):
        self = .app(app.id)
      case .folder(let folder):
        let layout = FolderLayout(
          id: folder.id,
          name: folder.name,
          appIDs: folder.apps.map { $0.id }
        )
        self = .folder(layout)
      }
    }

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      let type = try container.decode(String.self, forKey: .type)
      switch type {
      case "app":
        let id = try container.decode(String.self, forKey: .id)
        self = .app(id)
      case "folder":
        let folder = try FolderLayout(from: decoder)
        self = .folder(folder)
      default:
        throw DecodingError.dataCorruptedError(
          forKey: .type,
          in: container,
          debugDescription: "Unknown layout entry type \(type)"
        )
      }
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      switch self {
      case .app(let id):
        try container.encode("app", forKey: .type)
        try container.encode(id, forKey: .id)
      case .folder(let folder):
        try container.encode("folder", forKey: .type)
        try folder.encode(to: encoder)
      }
    }

    var folderID: String? {
      switch self {
      case .app:
        return nil
      case .folder(let folder):
        return folder.id
      }
    }
  }

  struct FolderLayout: Codable {
    let id: String
    let name: String
    let appIDs: [String]

    private enum CodingKeys: String, CodingKey {
      case id
      case name
      case apps
    }

    init(id: String, name: String, appIDs: [String]) {
      self.id = id
      self.name = name
      self.appIDs = appIDs
    }

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      id = try container.decode(String.self, forKey: .id)
      name = try container.decode(String.self, forKey: .name)
      appIDs = try container.decode([String].self, forKey: .apps)
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(id, forKey: .id)
      try container.encode(name, forKey: .name)
      try container.encode(appIDs, forKey: .apps)
    }
  }
}
