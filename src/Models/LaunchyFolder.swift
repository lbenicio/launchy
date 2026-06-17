import SwiftUI

struct LaunchyFolder: Identifiable, Codable, Equatable, Hashable, Sendable {
    var id: UUID = UUID()
    var name: String
    var color: IconColor = .gray
    var apps: [AppIcon]

    var previewIcons: [AppIcon] {
        Array(apps.prefix(9))
    }
}
