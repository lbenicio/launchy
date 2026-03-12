import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r: Double
        let g: Double
        let b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
        default:
            r = 0
            g = 0
            b = 0
        }
        self.init(red: r, green: g, blue: b)
    }

    var hexString: String {
        #if os(macOS)
            guard let nsColor = NSColor(self).usingColorSpace(.sRGB) else { return "000000" }
            let r = Int(nsColor.redComponent * 255)
            let g = Int(nsColor.greenComponent * 255)
            let b = Int(nsColor.blueComponent * 255)
            return String(format: "%02X%02X%02X", r, g, b)
        #else
            return "000000"
        #endif
    }
}
