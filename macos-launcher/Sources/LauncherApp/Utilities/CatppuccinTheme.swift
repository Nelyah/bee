import AppKit
import SwiftUI

/// Catppuccin Mocha color palette.
/// https://github.com/catppuccin/catppuccin
enum CatppuccinTheme {
    // MARK: - Base Colors

    /// Main background color (#1e1e2e)
    static let base = Color(hex: "#1e1e2e")
    static let baseNS = NSColor(hex: "#1e1e2e")

    /// Darker background for mantle areas (#181825)
    static let mantle = Color(hex: "#181825")
    static let mantleNS = NSColor(hex: "#181825")

    /// Darkest background for crust (#11111b)
    static let crust = Color(hex: "#11111b")
    static let crustNS = NSColor(hex: "#11111b")

    // MARK: - Surface Colors

    /// Surface for input fields (#313244)
    static let surface0 = Color(hex: "#313244")
    static let surface0NS = NSColor(hex: "#313244")

    /// Surface for borders (#45475a)
    static let surface1 = Color(hex: "#45475a")
    static let surface1NS = NSColor(hex: "#45475a")

    /// Surface for hover states (#585b70)
    static let surface2 = Color(hex: "#585b70")
    static let surface2NS = NSColor(hex: "#585b70")

    // MARK: - Text Colors

    /// Primary text color (#cdd6f4)
    static let text = Color(hex: "#cdd6f4")
    static let textNS = NSColor(hex: "#cdd6f4")

    /// Secondary text color (#bac2de)
    static let subtext1 = Color(hex: "#bac2de")
    static let subtext1NS = NSColor(hex: "#bac2de")

    /// Muted text color (#a6adc8)
    static let subtext0 = Color(hex: "#a6adc8")
    static let subtext0NS = NSColor(hex: "#a6adc8")

    /// Placeholder/overlay text (#6c7086)
    static let overlay0 = Color(hex: "#6c7086")
    static let overlay0NS = NSColor(hex: "#6c7086")

    // MARK: - Accent Colors

    /// Blue - for actions (#89b4fa)
    static let blue = Color(hex: "#89b4fa")
    static let blueNS = NSColor(hex: "#89b4fa")

    /// Green - for active status (#a6e3a1)
    static let green = Color(hex: "#a6e3a1")
    static let greenNS = NSColor(hex: "#a6e3a1")

    /// Yellow - for default/pending status (#f9e2af)
    static let yellow = Color(hex: "#f9e2af")
    static let yellowNS = NSColor(hex: "#f9e2af")

    /// Peach - for tags (#fab387)
    static let peach = Color(hex: "#fab387")
    static let peachNS = NSColor(hex: "#fab387")

    /// Mauve - for projects (#cba6f7)
    static let mauve = Color(hex: "#cba6f7")
    static let mauveNS = NSColor(hex: "#cba6f7")

    /// Red - for deleted/errors (#f38ba8)
    static let red = Color(hex: "#f38ba8")
    static let redNS = NSColor(hex: "#f38ba8")

    /// Teal - for date filters (#94e2d5)
    static let teal = Color(hex: "#94e2d5")
    static let tealNS = NSColor(hex: "#94e2d5")

    /// Sky - for logical operators (#89dceb)
    static let sky = Color(hex: "#89dceb")
    static let skyNS = NSColor(hex: "#89dceb")

    /// Lavender - for dependencies (#b4befe)
    static let lavender = Color(hex: "#b4befe")
    static let lavenderNS = NSColor(hex: "#b4befe")

    /// Pink - for status filter (#f5c2e7)
    static let pink = Color(hex: "#f5c2e7")
    static let pinkNS = NSColor(hex: "#f5c2e7")

    /// Flamingo - for parentheses (#f2cdcd)
    static let flamingo = Color(hex: "#f2cdcd")
    static let flamingoNS = NSColor(hex: "#f2cdcd")

    /// Rosewater - for UUIDs/Ints (#f5e0dc)
    static let rosewater = Color(hex: "#f5e0dc")
    static let rosewaterNS = NSColor(hex: "#f5e0dc")
}

// MARK: - Color Hex Extensions

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

extension NSColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = CGFloat((int >> 16) & 0xFF) / 255.0
        let g = CGFloat((int >> 8) & 0xFF) / 255.0
        let b = CGFloat(int & 0xFF) / 255.0
        // Use explicit sRGB color space for accurate rendering
        self.init(srgbRed: r, green: g, blue: b, alpha: 1.0)
    }
}
