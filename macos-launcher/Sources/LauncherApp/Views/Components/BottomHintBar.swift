import SwiftUI

struct BottomHint: Identifiable {
    let id = UUID()
    let key: String
    let label: String
}

struct BottomHintBar: View {
    let hints: [BottomHint]

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            ForEach(hints) { hint in
                HintChip(hint: hint)
            }
            Spacer()
        }
        .font(.system(size: DesignTokens.TypeScale.caption, weight: .medium, design: .rounded))
        .foregroundColor(ThemeManager.current.subtext0)
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                .fill(ThemeManager.current.surface0.opacity(0.6))
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
    BottomHintBar(hints: [
        BottomHint(key: "⌘K", label: "Command menu"),
        BottomHint(key: "Esc", label: "Back")
    ])
    .padding(24)
    .frame(width: 500, height: 120)
    .background(ThemeManager.current.base)
}
