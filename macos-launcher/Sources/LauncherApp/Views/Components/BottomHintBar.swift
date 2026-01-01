import SwiftUI

struct BottomHintBar: View {
    let leftHints: [BottomHint]
    let rightHints: [BottomHint]
    static let height: CGFloat = 34

    @State private var isHovered = false

    /// Opacity when not hovered - always visible
    private let restingOpacity: Double = 1.0
    /// Opacity when hovered - full visibility
    private let hoveredOpacity: Double = 1.0

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.small) {
            HStack(spacing: DesignTokens.Spacing.small) {
                ForEach(leftHints) { hint in
                    HintChip(hint: hint)
                }
            }
            Spacer(minLength: DesignTokens.Spacing.large)
            HStack(spacing: DesignTokens.Spacing.small) {
                ForEach(rightHints) { hint in
                    HintChip(hint: hint)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .font(.system(size: DesignTokens.TypeScale.caption, weight: .medium, design: .rounded))
        .foregroundColor(ThemeManager.current.subtext0)
        .padding(.horizontal, DesignTokens.Spacing.extraLarge)
        .padding(.vertical, DesignTokens.Spacing.small)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                        .fill(ThemeManager.current.surface0.opacity(0.7))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                        .stroke(
                            ThemeManager.current.surface1.opacity(DesignTokens.Border.containerOpacity),
                            lineWidth: 1
                        )
                )
        )
        .opacity(isHovered ? hoveredOpacity : restingOpacity)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

private struct HintChip: View {
    let hint: BottomHint

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.extraSmall) {
            Text(hint.key)
                .font(.system(size: DesignTokens.TypeScale.caption, weight: .semibold, design: .rounded))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous)
                        .fill(ThemeManager.current.surface1)
                )
            Text(hint.label)
        }
        .padding(.trailing, DesignTokens.Spacing.extraSmall)
    }
}

#Preview {
    BottomHintBar(
        leftHints: [BottomHint(key: "Esc", label: "Back")],
        rightHints: [
            BottomHint(key: "Enter", label: "Open"),
            BottomHint(key: "⌘K", label: "Command menu"),
        ]
    )
    .padding(DesignTokens.Spacing.extraExtraLarge)
    .frame(width: 500, height: 120)
    .background(ThemeManager.current.base)
}
