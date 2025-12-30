import AppKit
import SwiftUI

protocol Theme {
    var name: String { get }

    var base: Color { get }
    var baseNS: NSColor { get }

    var mantle: Color { get }
    var mantleNS: NSColor { get }

    var crust: Color { get }
    var crustNS: NSColor { get }

    var surface0: Color { get }
    var surface0NS: NSColor { get }

    var surface1: Color { get }
    var surface1NS: NSColor { get }

    var surface2: Color { get }
    var surface2NS: NSColor { get }

    var text: Color { get }
    var textNS: NSColor { get }

    var subtext1: Color { get }
    var subtext1NS: NSColor { get }

    var subtext0: Color { get }
    var subtext0NS: NSColor { get }

    var overlay0: Color { get }
    var overlay0NS: NSColor { get }

    var blue: Color { get }
    var blueNS: NSColor { get }

    var green: Color { get }
    var greenNS: NSColor { get }

    var yellow: Color { get }
    var yellowNS: NSColor { get }

    var peach: Color { get }
    var peachNS: NSColor { get }

    var mauve: Color { get }
    var mauveNS: NSColor { get }

    var red: Color { get }
    var redNS: NSColor { get }

    var teal: Color { get }
    var tealNS: NSColor { get }

    var sky: Color { get }
    var skyNS: NSColor { get }

    var lavender: Color { get }
    var lavenderNS: NSColor { get }

    var pink: Color { get }
    var pinkNS: NSColor { get }

    var flamingo: Color { get }
    var flamingoNS: NSColor { get }

    var rosewater: Color { get }
    var rosewaterNS: NSColor { get }
}
