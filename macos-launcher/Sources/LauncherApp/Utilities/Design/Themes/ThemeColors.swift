import AppKit
import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let red = Double((int >> 16) & 0xFF) / 255.0
        let green = Double((int >> 8) & 0xFF) / 255.0
        let blue = Double(int & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue)
    }

    /// Convert the color to a hex string in `#RRGGBB` format.
    ///
    /// Returns `nil` if the color cannot be resolved to RGB components
    /// (e.g., for pattern-based colors).
    var hexString: String? {
        guard let components = NSColor(self).usingColorSpace(.sRGB) else {
            return nil
        }

        let red = Int(round(components.redComponent * 255))
        let green = Int(round(components.greenComponent * 255))
        let blue = Int(round(components.blueComponent * 255))

        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}

extension NSColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let red = CGFloat((int >> 16) & 0xFF) / 255.0
        let green = CGFloat((int >> 8) & 0xFF) / 255.0
        let blue = CGFloat(int & 0xFF) / 255.0
        self.init(srgbRed: red, green: green, blue: blue, alpha: 1.0)
    }
}

// MARK: - Color Blending

extension Color {
    /// Blend this color with another color by the given amount.
    /// - Parameters:
    ///   - other: The color to blend with
    ///   - amount: Blend factor from 0.0 (all self) to 1.0 (all other)
    /// - Returns: The blended color
    func blended(with other: Color, amount: Double) -> Color {
        let clampedAmount = max(0, min(1, amount))

        // Convert to NSColor for component access
        let selfNS = NSColor(self)
        let otherNS = NSColor(other)

        // Get RGB components (in sRGB color space)
        guard let selfRGB = selfNS.usingColorSpace(.sRGB),
              let otherRGB = otherNS.usingColorSpace(.sRGB)
        else {
            return self
        }

        let r = selfRGB.redComponent * (1 - clampedAmount) + otherRGB.redComponent * clampedAmount
        let g = selfRGB.greenComponent * (1 - clampedAmount) + otherRGB.greenComponent * clampedAmount
        let b = selfRGB.blueComponent * (1 - clampedAmount) + otherRGB.blueComponent * clampedAmount

        return Color(red: r, green: g, blue: b)
    }
}
