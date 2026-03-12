import SwiftUI
import os.log

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r: Double
        let g: Double
        let b: Double
        let a: Double
        switch hex.count {
        case 3:  // RGB (4-bit per channel)
            r = Double((int >> 8) & 0xF) / 15
            g = Double((int >> 4) & 0xF) / 15
            b = Double(int & 0xF) / 15
            a = 1
        case 4:  // RGBA (4-bit per channel)
            r = Double((int >> 12) & 0xF) / 15
            g = Double((int >> 8) & 0xF) / 15
            b = Double((int >> 4) & 0xF) / 15
            a = Double(int & 0xF) / 15
        case 6:  // RRGGBB
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
            a = 1
        case 8:  // RRGGBBAA
            r = Double((int >> 24) & 0xFF) / 255
            g = Double((int >> 16) & 0xFF) / 255
            b = Double((int >> 8) & 0xFF) / 255
            a = Double(int & 0xFF) / 255
        default:
            Logger(subsystem: "dev.lbenicio.launchy", category: "Color+Hex")
                .warning("Unrecognized hex format (\(hex.count) chars): \(hex)")
            r = 0
            g = 0
            b = 0
            a = 1
        }
        self.init(red: r, green: g, blue: b, opacity: a)
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
