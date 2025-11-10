import SwiftUI

enum IconColor: String, CaseIterable, Codable, Hashable {
    case blue
    case indigo
    case purple
    case pink
    case orange
    case yellow
    case green
    case teal
    case mint
    case gray

    var color: Color {
        switch self {
        case .blue:
            return Color(red: 0.24, green: 0.46, blue: 0.85)
        case .indigo:
            return Color(red: 0.29, green: 0.34, blue: 0.87)
        case .purple:
            return Color(red: 0.62, green: 0.27, blue: 0.76)
        case .pink:
            return Color(red: 0.93, green: 0.33, blue: 0.55)
        case .orange:
            return Color(red: 0.97, green: 0.58, blue: 0.11)
        case .yellow:
            return Color(red: 0.99, green: 0.82, blue: 0.12)
        case .green:
            return Color(red: 0.15, green: 0.68, blue: 0.38)
        case .teal:
            return Color(red: 0.23, green: 0.64, blue: 0.72)
        case .mint:
            return Color(red: 0.43, green: 0.78, blue: 0.73)
        case .gray:
            return Color(red: 0.44, green: 0.47, blue: 0.51)
        }
    }

    static var defaultPalette: [IconColor] {
        [.blue, .indigo, .purple, .pink, .orange, .yellow, .green, .teal, .mint, .gray]
    }
}
