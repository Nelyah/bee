import SwiftUI

struct BottomHintBar: View {
    let leftHints: [BottomHint]
    let rightHints: [BottomHint]
    let onAction: (HintAction) -> Void
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
                    HintChip(hint: hint, onAction: onAction)
                }
            }
            Spacer(minLength: DesignTokens.Spacing.large)
            HStack(spacing: DesignTokens.Spacing.small) {
                ForEach(rightHints) { hint in
                    HintChip(hint: hint, onAction: onAction)
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
    let onAction: (HintAction) -> Void

    @State private var isHovering = false

    var body: some View {
        Group {
            if hint.isClickable {
                Button(action: { onAction(hint.action) }) {
                    chipContent
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    isHovering = hovering
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            } else {
                chipContent
            }
        }
    }

    private var chipContent: some View {
        HStack(spacing: DesignTokens.Spacing.extraSmall) {
            Text(hint.key)
                .font(.system(size: DesignTokens.TypeScale.caption, weight: .semibold, design: .rounded))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous)
                        .fill(keyBackground)
                )
            Text(hint.label)
        }
        .padding(.horizontal, DesignTokens.Spacing.small)
        .padding(.vertical, DesignTokens.Spacing.extraSmall)
        .background(chipBackground)
    }

    @ViewBuilder
    private var chipBackground: some View {
        if hint.isClickable, isHovering {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous)
                .fill(ThemeManager.current.surface1.opacity(0.6))
        }
    }

    private var keyBackground: Color {
        if hint.isClickable, isHovering {
            return ThemeManager.current.surface2
        }
        return ThemeManager.current.surface1
    }
}

#Preview {
    BottomHintBar(
        leftHints: [BottomHint(key: "Esc", label: "Back", action: .escape)],
        rightHints: [
            BottomHint(key: "Enter", label: "Open", action: .openTask),
            BottomHint(key: "⌘K", label: "Command menu", action: .openCommandPalette),
            BottomHint(key: "hjkl", label: "Navigate"), // Non-clickable
        ],
        onAction: { action in
            print("Hint clicked: \(action)")
        }
    )
    .padding(DesignTokens.Spacing.extraExtraLarge)
    .frame(width: 500, height: 120)
    .background(ThemeManager.current.base)
}
