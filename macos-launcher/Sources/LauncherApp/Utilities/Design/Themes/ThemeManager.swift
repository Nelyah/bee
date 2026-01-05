import SwiftUI

/// Manages the current theme and caches expensive computed colors.
enum ThemeManager {
    private static var _current: Theme = OneDarkTheme()
    private static var _cachedColors: CachedThemeColors?

    /// The current theme. When accessed, returns cached blended colors.
    static var current: CachedTheme {
        if _cachedColors == nil || _cachedColors?.themeName != _current.name {
            _cachedColors = CachedThemeColors(theme: _current)
        }
        return CachedTheme(base: _current, cached: _cachedColors!)
    }

    static let available: [Theme] = [
        OneDarkTheme(),
        CatppuccinTheme(),
    ]

    /// Set the current theme (clears cached colors)
    static func setTheme(_ theme: Theme) {
        _current = theme
        _cachedColors = nil
    }
}

/// Cached blended colors to avoid recomputation per-access.
struct CachedThemeColors {
    let themeName: String
    let surfaceHover: Color
    let surfaceSelected: Color
    let surfaceSelectedHover: Color
    // Multi-select colors (mauve-based)
    let surfaceMultiSelected: Color
    let surfaceMultiSelectedHover: Color
    let surfaceMultiSelectedFocused: Color

    init(theme: Theme) {
        themeName = theme.name
        // Compute blended colors once
        surfaceHover = theme.surface0.blended(with: theme.blue, amount: 0.08)
        surfaceSelected = theme.surface1.blended(with: theme.blue, amount: 0.15)
        surfaceSelectedHover = theme.surface2.blended(with: theme.blue, amount: 0.12)
        // Multi-select uses mauve tint
        surfaceMultiSelected = theme.surface0.blended(with: theme.mauve, amount: 0.12)
        surfaceMultiSelectedHover = theme.surface1.blended(with: theme.mauve, amount: 0.15)
        surfaceMultiSelectedFocused = theme.surface2.blended(with: theme.mauve, amount: 0.18)
    }
}

/// Wrapper that provides cached colors while delegating other properties to base theme.
struct CachedTheme: Theme {
    private let underlying: Theme
    private let cached: CachedThemeColors

    init(base: Theme, cached: CachedThemeColors) {
        underlying = base
        self.cached = cached
    }

    // Cached semantic colors
    var surfaceHover: Color { cached.surfaceHover }
    var surfaceSelected: Color { cached.surfaceSelected }
    var surfaceSelectedHover: Color { cached.surfaceSelectedHover }
    var surfaceMultiSelected: Color { cached.surfaceMultiSelected }
    var surfaceMultiSelectedHover: Color { cached.surfaceMultiSelectedHover }
    var surfaceMultiSelectedFocused: Color { cached.surfaceMultiSelectedFocused }

    // Delegated properties
    var name: String { underlying.name }
    var base: Color { underlying.base }
    var baseNS: NSColor { underlying.baseNS }
    var mantle: Color { underlying.mantle }
    var mantleNS: NSColor { underlying.mantleNS }
    var crust: Color { underlying.crust }
    var crustNS: NSColor { underlying.crustNS }
    var surface0: Color { underlying.surface0 }
    var surface0NS: NSColor { underlying.surface0NS }
    var surface1: Color { underlying.surface1 }
    var surface1NS: NSColor { underlying.surface1NS }
    var surface2: Color { underlying.surface2 }
    var surface2NS: NSColor { underlying.surface2NS }
    var text: Color { underlying.text }
    var textNS: NSColor { underlying.textNS }
    var annotationText: Color { underlying.annotationText }
    var annotationTextNS: NSColor { underlying.annotationTextNS }
    var subtext1: Color { underlying.subtext1 }
    var subtext1NS: NSColor { underlying.subtext1NS }
    var subtext0: Color { underlying.subtext0 }
    var subtext0NS: NSColor { underlying.subtext0NS }
    var overlay0: Color { underlying.overlay0 }
    var overlay0NS: NSColor { underlying.overlay0NS }
    var blue: Color { underlying.blue }
    var blueNS: NSColor { underlying.blueNS }
    var green: Color { underlying.green }
    var greenNS: NSColor { underlying.greenNS }
    var yellow: Color { underlying.yellow }
    var yellowNS: NSColor { underlying.yellowNS }
    var peach: Color { underlying.peach }
    var peachNS: NSColor { underlying.peachNS }
    var mauve: Color { underlying.mauve }
    var mauveNS: NSColor { underlying.mauveNS }
    var red: Color { underlying.red }
    var redNS: NSColor { underlying.redNS }
    var teal: Color { underlying.teal }
    var tealNS: NSColor { underlying.tealNS }
    var sky: Color { underlying.sky }
    var skyNS: NSColor { underlying.skyNS }
    var lavender: Color { underlying.lavender }
    var lavenderNS: NSColor { underlying.lavenderNS }
    var pink: Color { underlying.pink }
    var pinkNS: NSColor { underlying.pinkNS }
    var flamingo: Color { underlying.flamingo }
    var flamingoNS: NSColor { underlying.flamingoNS }
    var rosewater: Color { underlying.rosewater }
    var rosewaterNS: NSColor { underlying.rosewaterNS }
}
