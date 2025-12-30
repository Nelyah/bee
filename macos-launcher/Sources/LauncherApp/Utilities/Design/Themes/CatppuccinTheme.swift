import AppKit
import SwiftUI

/// Catppuccin Mocha color palette.
/// https://github.com/catppuccin/catppuccin
struct CatppuccinTheme: Theme {
    let name = "Catppuccin Mocha"

    var base: Color { Self.baseColor }
    var baseNS: NSColor { Self.baseColorNS }

    var mantle: Color { Self.mantleColor }
    var mantleNS: NSColor { Self.mantleColorNS }

    var crust: Color { Self.crustColor }
    var crustNS: NSColor { Self.crustColorNS }

    var surface0: Color { Self.surface0Color }
    var surface0NS: NSColor { Self.surface0ColorNS }

    var surface1: Color { Self.surface1Color }
    var surface1NS: NSColor { Self.surface1ColorNS }

    var surface2: Color { Self.surface2Color }
    var surface2NS: NSColor { Self.surface2ColorNS }

    var text: Color { Self.textColor }
    var textNS: NSColor { Self.textColorNS }

    var subtext1: Color { Self.subtext1Color }
    var subtext1NS: NSColor { Self.subtext1ColorNS }

    var subtext0: Color { Self.subtext0Color }
    var subtext0NS: NSColor { Self.subtext0ColorNS }

    var overlay0: Color { Self.overlay0Color }
    var overlay0NS: NSColor { Self.overlay0ColorNS }

    var blue: Color { Self.blueColor }
    var blueNS: NSColor { Self.blueColorNS }

    var green: Color { Self.greenColor }
    var greenNS: NSColor { Self.greenColorNS }

    var yellow: Color { Self.yellowColor }
    var yellowNS: NSColor { Self.yellowColorNS }

    var peach: Color { Self.peachColor }
    var peachNS: NSColor { Self.peachColorNS }

    var mauve: Color { Self.mauveColor }
    var mauveNS: NSColor { Self.mauveColorNS }

    var red: Color { Self.redColor }
    var redNS: NSColor { Self.redColorNS }

    var teal: Color { Self.tealColor }
    var tealNS: NSColor { Self.tealColorNS }

    var sky: Color { Self.skyColor }
    var skyNS: NSColor { Self.skyColorNS }

    var lavender: Color { Self.lavenderColor }
    var lavenderNS: NSColor { Self.lavenderColorNS }

    var pink: Color { Self.pinkColor }
    var pinkNS: NSColor { Self.pinkColorNS }

    var flamingo: Color { Self.flamingoColor }
    var flamingoNS: NSColor { Self.flamingoColorNS }

    var rosewater: Color { Self.rosewaterColor }
    var rosewaterNS: NSColor { Self.rosewaterColorNS }

    // MARK: - Base Colors
    private static let baseColor = Color(hex: "#1e1e2e")
    private static let baseColorNS = NSColor(hex: "#1e1e2e")
    private static let mantleColor = Color(hex: "#181825")
    private static let mantleColorNS = NSColor(hex: "#181825")
    private static let crustColor = Color(hex: "#11111b")
    private static let crustColorNS = NSColor(hex: "#11111b")

    // MARK: - Surface Colors
    private static let surface0Color = Color(hex: "#313244")
    private static let surface0ColorNS = NSColor(hex: "#313244")
    private static let surface1Color = Color(hex: "#45475a")
    private static let surface1ColorNS = NSColor(hex: "#45475a")
    private static let surface2Color = Color(hex: "#585b70")
    private static let surface2ColorNS = NSColor(hex: "#585b70")

    // MARK: - Text Colors
    private static let textColor = Color(hex: "#cdd6f4")
    private static let textColorNS = NSColor(hex: "#cdd6f4")
    private static let subtext1Color = Color(hex: "#bac2de")
    private static let subtext1ColorNS = NSColor(hex: "#bac2de")
    private static let subtext0Color = Color(hex: "#a6adc8")
    private static let subtext0ColorNS = NSColor(hex: "#a6adc8")
    private static let overlay0Color = Color(hex: "#6c7086")
    private static let overlay0ColorNS = NSColor(hex: "#6c7086")

    // MARK: - Accent Colors
    private static let blueColor = Color(hex: "#89b4fa")
    private static let blueColorNS = NSColor(hex: "#89b4fa")
    private static let greenColor = Color(hex: "#a6e3a1")
    private static let greenColorNS = NSColor(hex: "#a6e3a1")
    private static let yellowColor = Color(hex: "#f9e2af")
    private static let yellowColorNS = NSColor(hex: "#f9e2af")
    private static let peachColor = Color(hex: "#fab387")
    private static let peachColorNS = NSColor(hex: "#fab387")
    private static let mauveColor = Color(hex: "#cba6f7")
    private static let mauveColorNS = NSColor(hex: "#cba6f7")
    private static let redColor = Color(hex: "#f38ba8")
    private static let redColorNS = NSColor(hex: "#f38ba8")
    private static let tealColor = Color(hex: "#94e2d5")
    private static let tealColorNS = NSColor(hex: "#94e2d5")
    private static let skyColor = Color(hex: "#89dceb")
    private static let skyColorNS = NSColor(hex: "#89dceb")
    private static let lavenderColor = Color(hex: "#b4befe")
    private static let lavenderColorNS = NSColor(hex: "#b4befe")
    private static let pinkColor = Color(hex: "#f5c2e7")
    private static let pinkColorNS = NSColor(hex: "#f5c2e7")
    private static let flamingoColor = Color(hex: "#f2cdcd")
    private static let flamingoColorNS = NSColor(hex: "#f2cdcd")
    private static let rosewaterColor = Color(hex: "#f5e0dc")
    private static let rosewaterColorNS = NSColor(hex: "#f5e0dc")
}
