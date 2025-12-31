import SwiftUI

struct BottomHintBar: View {
    let leftHints: [BottomHint]
    let rightHints: [BottomHint]
    static let height: CGFloat = 34

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                ForEach(leftHints) { hint in
                    HintChip(hint: hint)
                }
            }
            Spacer(minLength: DesignTokens.Spacing.lg)
            HStack(spacing: DesignTokens.Spacing.sm) {
                ForEach(rightHints) { hint in
                    HintChip(hint: hint)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .font(.system(size: DesignTokens.TypeScale.caption, weight: .medium, design: .rounded))
        .foregroundColor(ThemeManager.current.subtext0)
        .padding(.horizontal, DesignTokens.Spacing.xl)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                        .fill(ThemeManager.current.surface0.opacity(0.7))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                        .stroke(ThemeManager.current.surface1.opacity(0.5), lineWidth: 1)
                )
        )
    }
}

private struct HintChip: View {
    let hint: BottomHint

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Text(hint.key)
                .font(.system(size: DesignTokens.TypeScale.caption, weight: .semibold, design: .rounded))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                        .fill(ThemeManager.current.surface1)
                )
            Text(hint.label)
        }
        .padding(.trailing, DesignTokens.Spacing.xs)
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
    .padding(24)
    .frame(width: 500, height: 120)
    .background(ThemeManager.current.base)
}
