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

    // MARK: - Semantic Surface Colors (Interactive States)

    /// Surface color for hover state - provides subtle highlight
    var surfaceHover: Color { get }

    /// Surface color for selected state - clearly indicates selection
    var surfaceSelected: Color { get }

    /// Surface color for selected + hover state - combines both states
    var surfaceSelectedHover: Color { get }

    var text: Color { get }
    var textNS: NSColor { get }

    // MARK: - Semantic Text Colors

    /// Brighter text color for annotation content - provides better contrast for user-generated content
    var annotationText: Color { get }
    var annotationTextNS: NSColor { get }

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

// MARK: - Default Semantic Surface Colors

extension Theme {
    /// Default hover state: surface0 blended with blue (8%) for subtle highlight
    var surfaceHover: Color {
        surface0.blended(with: blue, amount: 0.08)
    }

    /// Default selected state: surface1 blended with blue (15%) for clear selection
    var surfaceSelected: Color {
        surface1.blended(with: blue, amount: 0.15)
    }

    /// Default selected + hover: surface2 blended with blue (12%) for combined state
    var surfaceSelectedHover: Color {
        surface2.blended(with: blue, amount: 0.12)
    }
}
