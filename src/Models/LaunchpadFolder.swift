import SwiftUI

struct LaunchpadFolder: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var color: IconColor = .gray
    var apps: [AppIcon]

    var previewIcons: [AppIcon] {
        Array(apps.prefix(9))
    }
}
