import SwiftUI

struct TaskRow: View {
    let task: ApiTask
    let columns: [String]
    let isSelected: Bool

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
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(CatppuccinTheme.subtext0)
                        .frame(width: 30, alignment: .leading)
                } else if column == "summary" {
                    // Summary column expands
                    Text(value(for: column))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(CatppuccinTheme.text)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    // Other columns
                    Text(value(for: column))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(CatppuccinTheme.subtext1)
                        .frame(width: 60, alignment: .leading)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? CatppuccinTheme.surface1.opacity(0.6) : CatppuccinTheme.surface0.opacity(0.3))
        )
    }

    /// Get the value for a column from the task.
    private func value(for column: String) -> String {
        switch column {
        case "id":
            return task.dbId.map(String.init) ?? "-"
        case "uuid":
            return String(task.uuid.prefix(8))
        case "summary":
            return task.summary
        case "status":
            return task.status
        case "project":
            return task.project ?? "-"
        case "tags":
            return task.tags.isEmpty ? "-" : task.tags.joined(separator: ", ")
        case "urgency":
            return task.urgency.map(String.init) ?? "-"
        case "date_created":
            return formatDate(task.dateCreated)
        case "date_completed":
            return task.dateCompleted.map(formatDate) ?? "-"
        case "date_due":
            return task.dateDue.map(formatDate) ?? "-"
        default:
            return "-"
        }
    }

    /// Format an ISO date string to a relative or short format.
    private func formatDate(_ isoDate: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: isoDate) {
            let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
            if abs(days) < 1 {
                return "today"
            } else if days == 1 {
                return "yesterday"
            } else if days == -1 {
                return "tomorrow"
            } else if days > 0 {
                return "\(days)d ago"
            } else {
                return "in \(abs(days))d"
            }
        }
        // Fallback: try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: isoDate) {
            let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
            if abs(days) < 1 {
                return "today"
            } else if days == 1 {
                return "yesterday"
            } else if days == -1 {
                return "tomorrow"
            } else if days > 0 {
                return "\(days)d ago"
            } else {
                return "in \(abs(days))d"
            }
        }
        return isoDate
    }
}

#Preview("Selected") {
    TaskRow(
        task: MockApiClient.sampleTasks[0],
        columns: ["id", "summary", "tags", "status"],
        isSelected: true
    )
    .padding()
    .background(CatppuccinTheme.base)
}

#Preview("Unselected") {
    TaskRow(
        task: MockApiClient.sampleTasks[1],
        columns: ["id", "summary", "tags", "status"],
        isSelected: false
    )
    .padding()
    .background(CatppuccinTheme.base)
}
