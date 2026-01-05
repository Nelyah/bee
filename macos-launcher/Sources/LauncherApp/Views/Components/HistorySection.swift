import SwiftUI

/// Collapsible section displaying task history entries.
///
/// Features:
/// - Collapsible with chevron indicator
/// - Sorted by timestamp (newest first)
/// - Uses TimelineRow for consistent styling
struct HistorySection: View {
    let history: [TaskHistoryDto]

    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
            // Collapsible header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: DesignTokens.Spacing.small) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(ThemeManager.current.subtext0)
                        .frame(width: 12)
                    Text("HISTORY")
                        .font(.system(size: DesignTokens.TypeScale.label, weight: .bold, design: .rounded))
                        .foregroundColor(ThemeManager.current.subtext0)
                }
            }
            .buttonStyle(.plain)

            // Collapsible content
            if isExpanded {
                let sortedHistory = history.sorted { lhs, rhs in
                    guard let left = RelativeDateFormatter.date(from: lhs.datetime),
                          let right = RelativeDateFormatter.date(from: rhs.datetime)
                    else {
                        return lhs.datetime > rhs.datetime
                    }
                    return left > right
                }

                if sortedHistory.isEmpty {
                    Text("—")
                        .font(.system(size: DesignTokens.TypeScale.bodySm, weight: .medium))
                        .foregroundColor(ThemeManager.current.overlay0)
                } else {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
                        ForEach(sortedHistory) { entry in
                            TimelineRow(
                                timestamp: entry.datetime,
                                value: entry.value
                            )
                        }
                    }
                }
            }
        }
        .padding(DesignTokens.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                .fill(ThemeManager.current.surface0)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                .stroke(ThemeManager.current.surface1.opacity(DesignTokens.Border.containerOpacity), lineWidth: 1)
        )
    }
}

// MARK: - Previews

#Preview("With History") {
    HistorySection(history: [
        TaskHistoryDto(value: "Status changed from 'PENDING' to 'ACTIVE'", datetime: "2024-01-16T12:30:00Z"),
        TaskHistoryDto(value: "Added tag 'urgent'", datetime: "2024-01-15T11:00:00Z"),
        TaskHistoryDto(value: "Task created", datetime: "2024-01-14T09:00:00Z"),
    ])
    .padding()
    .frame(width: 400)
    .background(ThemeManager.current.base)
}

#Preview("Empty History") {
    HistorySection(history: [])
        .padding()
        .frame(width: 400)
        .background(ThemeManager.current.base)
}
