import AppKit
import SwiftUI

/// One Dark color palette.
/// https://github.com/atom/one-dark-syntax
struct OneDarkTheme: Theme {
    let name = "One Dark"

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
    private static let baseColor = Color(hex: "#222222")
    private static let baseColorNS = NSColor(hex: "#222222")
    private static let mantleColor = Color(hex: "#222222")
    private static let mantleColorNS = NSColor(hex: "#222222")
    private static let crustColor = Color(hex: "#222222")
    private static let crustColorNS = NSColor(hex: "#222222")

    // MARK: - Surface Colors
    private static let surface0Color = Color(hex: "#2c313c")
    private static let surface0ColorNS = NSColor(hex: "#2c313c")
    private static let surface1Color = Color(hex: "#3e4451")
    private static let surface1ColorNS = NSColor(hex: "#3e4451")
    private static let surface2Color = Color(hex: "#4b5263")
    private static let surface2ColorNS = NSColor(hex: "#4b5263")

    // MARK: - Text Colors
    private static let textColor = Color(hex: "#abb2bf")
    private static let textColorNS = NSColor(hex: "#abb2bf")
    private static let subtext1Color = Color(hex: "#a0a8b7")
    private static let subtext1ColorNS = NSColor(hex: "#a0a8b7")
    private static let subtext0Color = Color(hex: "#8b93a1")
    private static let subtext0ColorNS = NSColor(hex: "#8b93a1")
    private static let overlay0Color = Color(hex: "#5c6370")
    private static let overlay0ColorNS = NSColor(hex: "#5c6370")

    // MARK: - Accent Colors
    private static let blueColor = Color(hex: "#61afef")
    private static let blueColorNS = NSColor(hex: "#61afef")
    private static let greenColor = Color(hex: "#98c379")
    private static let greenColorNS = NSColor(hex: "#98c379")
    private static let yellowColor = Color(hex: "#e5c07b")
    private static let yellowColorNS = NSColor(hex: "#e5c07b")
    private static let peachColor = Color(hex: "#d19a66")
    private static let peachColorNS = NSColor(hex: "#d19a66")
    private static let mauveColor = Color(hex: "#c678dd")
    private static let mauveColorNS = NSColor(hex: "#c678dd")
    private static let redColor = Color(hex: "#e06c75")
    private static let redColorNS = NSColor(hex: "#e06c75")
    private static let tealColor = Color(hex: "#56b6c2")
    private static let tealColorNS = NSColor(hex: "#56b6c2")
    private static let skyColor = Color(hex: "#61afef")
    private static let skyColorNS = NSColor(hex: "#61afef")
    private static let lavenderColor = Color(hex: "#c678dd")
    private static let lavenderColorNS = NSColor(hex: "#c678dd")
    private static let pinkColor = Color(hex: "#e06c75")
    private static let pinkColorNS = NSColor(hex: "#e06c75")
    private static let flamingoColor = Color(hex: "#e06c75")
    private static let flamingoColorNS = NSColor(hex: "#e06c75")
    private static let rosewaterColor = Color(hex: "#f0d7b8")
    private static let rosewaterColorNS = NSColor(hex: "#f0d7b8")
}
