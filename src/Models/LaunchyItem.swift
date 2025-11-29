import Foundation

enum LaunchyItem: Identifiable, Codable, Equatable {
    case app(AppIcon)
    case folder(LaunchyFolder)

    var id: UUID {
        switch self {
        case .app(let icon):
            return icon.id
        case .folder(let folder):
            return folder.id
        }
    }

    var displayName: String {
        switch self {
        case .app(let icon):
            return icon.name
        case .folder(let folder):
            return folder.name
        }
    }

    var asApp: AppIcon? {
        if case .app(let icon) = self { return icon }
        return nil
    }

    var asFolder: LaunchyFolder? {
        if case .folder(let folder) = self { return folder }
        return nil
    }

    var isFolder: Bool {
        switch self {
        case .folder:
            return true
        case .app:
            return false
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case payload
    }

    private enum ItemType: String, Codable {
        case app
        case folder
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ItemType.self, forKey: .type)
        switch type {
        case .app:
            let icon = try container.decode(AppIcon.self, forKey: .payload)
            self = .app(icon)
        case .folder:
            let folder = try container.decode(LaunchyFolder.self, forKey: .payload)
            self = .folder(folder)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .app(let icon):
            try container.encode(ItemType.app, forKey: .type)
            try container.encode(icon, forKey: .payload)
        case .folder(let folder):
            try container.encode(ItemType.folder, forKey: .type)
            try container.encode(folder, forKey: .payload)
        }
    }
}
