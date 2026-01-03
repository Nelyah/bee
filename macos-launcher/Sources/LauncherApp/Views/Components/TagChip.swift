import SwiftUI

/// A removable tag chip with optional keyboard selection state.
///
/// Displays a tag name with a small × button for removal. When selected via
/// keyboard navigation, shows a highlight border.
struct TagChip: View {
    let tag: String
    let isSelected: Bool
    let onRemove: () -> Void

    private var theme: any Theme {
        ThemeManager.current
    }

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.extraSmall) {
            Text(tag)
                .font(.system(size: DesignTokens.TypeScale.bodySm))
                .foregroundColor(theme.text)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: DesignTokens.IconSize.mini, weight: .semibold))
                    .foregroundColor(theme.subtext0)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
        }
        .padding(.horizontal, DesignTokens.Spacing.small)
        .padding(.vertical, DesignTokens.Spacing.extraSmall)
        .background(isSelected ? theme.surfaceSelected : theme.surface0)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                .stroke(isSelected ? theme.blue : theme.overlay0, lineWidth: 1)
        )
        .cornerRadius(DesignTokens.Radius.small)
    }
}

#Preview("TagChip - Normal") {
    TagChip(tag: "hobby", isSelected: false, onRemove: {})
        .padding()
        .background(ThemeManager.current.base)
}

#Preview("TagChip - Selected") {
    TagChip(tag: "urgent", isSelected: true, onRemove: {})
        .padding()
        .background(ThemeManager.current.base)
}
