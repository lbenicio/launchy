import Foundation

struct AppIcon: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var name: String
    var bundleIdentifier: String
    var bundleURL: URL

    init(id: UUID = UUID(), name: String, bundleIdentifier: String, bundleURL: URL) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.bundleURL = bundleURL
    }
}
