import SwiftUI

/// Defines the visual theme for completion menus.
struct CompletionTheme {
    // MARK: - Container Styling

    /// Background color for the completion menu.
    let background: Color

    /// Border color for the completion menu.
    let border: Color

    /// Border opacity (0.0-1.0).
    let borderOpacity: Double

    /// Shadow configuration (color, radius, x-offset, y-offset).
    let shadow: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat)

    // MARK: - Row States

    /// Background color for the selected (keyboard-focused) row.
    let selectedBackground: Color

    /// Text color for the selected row.
    let selectedText: Color

    /// Background color for a hovered (mouse-over) row.
    let hoverBackground: Color

    /// Text color for normal (non-selected, non-hovered) rows.
    let normalText: Color

    /// Text color for the current value row (greyed out, non-selectable).
    let currentValueText: Color

    /// Count/metadata text color for normal rows.
    let metadataText: Color

    /// Count/metadata text color for selected rows.
    let metadataSelectedText: Color

    // MARK: - Fuzzy Match Highlighting

    /// Color for highlighting matched characters in fuzzy search.
    let matchHighlightColor: Color

    /// Font weight for matched characters (e.g., .bold).
    let matchFontWeight: Font.Weight

    // MARK: - Dimensions

    /// Padding around the entire menu.
    let menuPadding: EdgeInsets

    /// Corner radius for the menu container.
    let cornerRadius: CGFloat

    // MARK: - Default Theme

    /// The default completion theme using Catppuccin colors.
    static var `default`: CompletionTheme {
        CompletionTheme(
            background: ThemeManager.current.surface0,
            border: ThemeManager.current.surface1,
            borderOpacity: DesignTokens.Border.containerOpacity,
            shadow: (
                color: Color.black.opacity(0.4),
                radius: 12,
                x: 0,
                y: 6
            ),
            selectedBackground: ThemeManager.current.blue.opacity(0.35),
            selectedText: ThemeManager.current.text,
            hoverBackground: ThemeManager.current.surfaceHover,
            normalText: ThemeManager.current.text,
            currentValueText: ThemeManager.current.overlay0,
            metadataText: ThemeManager.current.overlay0,
            metadataSelectedText: ThemeManager.current.text,
            matchHighlightColor: ThemeManager.current.blue,
            matchFontWeight: .bold,
            menuPadding: EdgeInsets(
                top: DesignTokens.Spacing.extraSmall,
                leading: 0,
                bottom: DesignTokens.Spacing.extraSmall,
                trailing: 0
            ),
            cornerRadius: DesignTokens.Radius.small
        )
    }

    /// A high-contrast variant for better visibility.
    static var highContrast: CompletionTheme {
        CompletionTheme(
            background: ThemeManager.current.base,
            border: ThemeManager.current.blue,
            borderOpacity: 1.0,
            shadow: (
                color: Color.black.opacity(0.6),
                radius: 16,
                x: 0,
                y: 8
            ),
            selectedBackground: ThemeManager.current.blue,
            selectedText: ThemeManager.current.base,
            hoverBackground: ThemeManager.current.surface1,
            normalText: ThemeManager.current.text,
            currentValueText: ThemeManager.current.subtext0,
            metadataText: ThemeManager.current.subtext0,
            metadataSelectedText: ThemeManager.current.base,
            matchHighlightColor: ThemeManager.current.yellow,
            matchFontWeight: .heavy,
            menuPadding: EdgeInsets(
                top: DesignTokens.Spacing.small,
                leading: 0,
                bottom: DesignTokens.Spacing.small,
                trailing: 0
            ),
            cornerRadius: DesignTokens.Radius.medium
        )
    }
}
