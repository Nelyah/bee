import SwiftUI

/// A clickable chip that displays the current project scope with a clear action.
struct ProjectScopeChipView: View {
    let project: String
    let onClear: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: { onClear() }) {
            HStack(spacing: DesignTokens.Spacing.extraSmall) {
                Image(systemName: "folder")
                    .font(.system(size: DesignTokens.TypeScale.caption, weight: .medium))
                Text(project)
                    .font(.system(size: DesignTokens.TypeScale.label, weight: .semibold, design: .rounded))
                Image(systemName: "xmark")
                    .font(.system(size: DesignTokens.TypeScale.caption - 1, weight: .bold))
                    .opacity(isHovered ? 1.0 : 0.6)
            }
            .foregroundColor(ThemeManager.current.teal)
            .padding(.horizontal, DesignTokens.Spacing.small)
            .padding(.vertical, DesignTokens.Spacing.extraSmall)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                    .fill(ThemeManager.current.teal.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                    .stroke(ThemeManager.current.teal.opacity(isHovered ? 0.8 : 0.4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("Click to clear project scope")
    }
}
