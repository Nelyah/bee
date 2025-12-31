import SwiftUI

struct TaskRow: View {
    let task: ApiTask
    let columns: [String]
    let isSelected: Bool
    let isHovered: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(statusColor(task.status))
                .frame(width: 8, height: 8)

            // Dynamic columns
            ForEach(Array(columns.enumerated()), id: \.offset) { index, column in
                if index == 0 {
                    // First column (usually ID) - small fixed width
                    Text(value(for: column))
                        .font(.system(size: DesignTokens.TypeScale.bodySm, weight: .medium, design: .monospaced))
                        .foregroundColor(ThemeManager.current.subtext0)
                        .frame(width: 30, alignment: .leading)
                } else if column == "summary" {
                    // Summary column expands
                    Text(value(for: column))
                        .font(.system(size: DesignTokens.TypeScale.bodyLg, weight: .semibold, design: .rounded))
                        .foregroundColor(ThemeManager.current.text)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    // Other columns
                    Text(value(for: column))
                        .font(.system(size: DesignTokens.TypeScale.bodySm, weight: .medium, design: .rounded))
                        .foregroundColor(ThemeManager.current.subtext1)
                        .frame(width: 60, alignment: .leading)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, DesignTokens.Spacing.sm)
        .padding(.horizontal, DesignTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(backgroundColor)
        )
    }

    private var backgroundColor: Color {
        if isSelected {
            return ThemeManager.current.surface1
        }
        if isHovered {
            return ThemeManager.current.surface0
        }
        return ThemeManager.current.base
    }

    /// Get the value for a column from the task.
    private func value(for column: String) -> String {
        switch column {
        case "id":
            task.dbId.map(String.init) ?? "-"
        case "uuid":
            String(task.uuid.prefix(8))
        case "summary":
            task.summary
        case "status":
            task.status
        case "project":
            task.project ?? "-"
        case "tags":
            task.tags.isEmpty ? "-" : task.tags.joined(separator: ", ")
        case "urgency":
            task.urgency.map(String.init) ?? "-"
        case "date_created":
            formatDate(task.dateCreated)
        case "date_completed":
            task.dateCompleted.map(formatDate) ?? "-"
        case "date_due":
            task.dateDue.map(formatDate) ?? "-"
        default:
            "-"
        }
    }

    /// Format an ISO date string to a relative or short format.
    private func formatDate(_ isoDate: String) -> String {
        RelativeDateFormatter.description(for: isoDate)
    }
}

#Preview("Selected") {
    TaskRow(
        task: MockApiClient.sampleTasks[0],
        columns: ["id", "summary", "tags", "status"],
        isSelected: true,
        isHovered: false
    )
    .padding()
    .background(ThemeManager.current.base)
}

#Preview("Unselected") {
    TaskRow(
        task: MockApiClient.sampleTasks[1],
        columns: ["id", "summary", "tags", "status"],
        isSelected: false,
        isHovered: true
    )
    .padding()
    .background(ThemeManager.current.base)
}
