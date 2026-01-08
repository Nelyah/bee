import SwiftUI

enum DesignTokens {
    /// Border opacity tokens for consistent stroke appearance
    enum Border {
        /// Container borders (windows, cards, panels) - visible but subtle
        static let containerOpacity: Double = 0.8
        /// Separator/divider borders - lighter for visual separation
        static let separatorOpacity: Double = 0.5
        /// Focus state borders use full accent color (no opacity token needed)
    }

    enum Spacing {
        static let extraSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let extraLarge: CGFloat = 20
        static let extraExtraLarge: CGFloat = 24
    }

    enum Radius {
        static let small: CGFloat = 6
        static let medium: CGFloat = 10
        static let large: CGFloat = 12
        static let extraLarge: CGFloat = 16
    }

    enum TypeScale {
        static let mini: CGFloat = 8
        static let caption: CGFloat = 10
        static let label: CGFloat = 11
        static let bodySm: CGFloat = 12
        static let body: CGFloat = 14
        static let bodyLg: CGFloat = 15
        static let bodyXl: CGFloat = 16
        static let input: CGFloat = 18
        static let title: CGFloat = 22
        static let display: CGFloat = 32
    }

    enum IconSize {
        static let mini: CGFloat = 8
        static let statusIndicator: CGFloat = 10
        static let small: CGFloat = 12
        static let medium: CGFloat = 14
        static let standard: CGFloat = 16
        static let large: CGFloat = 34
    }

    /// Command palette responsive sizing constants
    enum CommandPalette {
        static let minWidth: CGFloat = 400
        static let maxWidth: CGFloat = 640
        static let maxHeightRatio: CGFloat = 0.6
        static let maxHeightAbsolute: CGFloat = 500

        /// Calculates responsive width based on window width.
        /// Scales from 92% on small windows down to a capped 640px on large windows.
        static func responsiveWidth(for windowWidth: CGFloat) -> CGFloat {
            let calculated: CGFloat = switch windowWidth {
            case ..<600:
                windowWidth * 0.92
            case 600 ..< 900:
                windowWidth * 0.75
            case 900 ..< 1400:
                windowWidth * 0.58
            default:
                maxWidth
            }
            return min(max(calculated, minWidth), maxWidth)
        }

        /// Calculates responsive max height based on window height.
        static func responsiveMaxHeight(for windowHeight: CGFloat) -> CGFloat {
            min(windowHeight * maxHeightRatio, maxHeightAbsolute)
        }
    }
}
