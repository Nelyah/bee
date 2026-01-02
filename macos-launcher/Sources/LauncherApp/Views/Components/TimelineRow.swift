import SwiftUI

/// Displays a timestamp and value in a horizontal row for timeline/history views.
struct TimelineRow: View {
    let timestamp: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.medium) {
            Text(RelativeDateFormatter.description(for: timestamp))
                .font(.system(size: DesignTokens.TypeScale.caption, weight: .semibold, design: .rounded))
                .foregroundColor(ThemeManager.current.subtext0)
                .frame(width: 90, alignment: .leading)
                .help(timestamp)
            Text(value)
                .font(.system(size: DesignTokens.TypeScale.body, weight: .regular))
                .foregroundColor(ThemeManager.current.annotationText)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, DesignTokens.Spacing.small)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous)
                .fill(ThemeManager.current.surface1.opacity(0.6))
        )
    }
}
