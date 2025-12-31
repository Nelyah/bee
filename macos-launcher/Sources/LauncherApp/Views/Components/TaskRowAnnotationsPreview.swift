import SwiftUI

/// A compact preview of annotations for expanded task rows.
struct TaskRowAnnotationsPreview: View {
    let annotations: [TaskAnnotationDto]
    var maxVisible: Int = 2

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.extraSmall) {
            // Section header
            Text("Annotations")
                .font(.system(size: DesignTokens.TypeScale.caption, weight: .semibold))
                .foregroundColor(ThemeManager.current.subtext0)

            // Annotation rows
            ForEach(visibleAnnotations) { annotation in
                CompactAnnotationRow(annotation: annotation)
            }

            // "+N more" indicator
            if remainingCount > 0 {
                moreIndicator
            }
        }
    }

    private var visibleAnnotations: [TaskAnnotationDto] {
        Array(annotations.prefix(maxVisible))
    }

    private var remainingCount: Int {
        max(0, annotations.count - maxVisible)
    }

    private var moreIndicator: some View {
        Text("+\(remainingCount) more")
            .font(.system(size: DesignTokens.TypeScale.caption, weight: .medium))
            .foregroundColor(ThemeManager.current.subtext0)
            .padding(.leading, 58) // Align with annotation text column
    }
}

/// A compact single-line annotation display.
struct CompactAnnotationRow: View {
    let annotation: TaskAnnotationDto

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.small) {
            // Date column (fixed width)
            Text(formattedDate)
                .font(.system(size: DesignTokens.TypeScale.caption, weight: .medium, design: .monospaced))
                .foregroundColor(ThemeManager.current.subtext0)
                .frame(width: 50, alignment: .leading)

            // Annotation text (wraps naturally)
            Text(annotation.value)
                .font(.system(size: DesignTokens.TypeScale.caption, weight: .medium))
                .foregroundColor(ThemeManager.current.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var formattedDate: String {
        RelativeDateFormatter.shortDescription(for: annotation.time)
    }
}

/// Extension to add short description formatting.
extension RelativeDateFormatter {
    /// Produce a very short date description (e.g., "2d", "1w", "3mo").
    static func shortDescription(for isoDate: String) -> String {
        guard let date = date(from: isoDate) else { return "-" }
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day, .weekOfYear, .month, .year], from: date, to: now)

        if let years = components.year, years > 0 {
            return "\(years)y"
        }
        if let months = components.month, months > 0 {
            return "\(months)mo"
        }
        if let weeks = components.weekOfYear, weeks > 0 {
            return "\(weeks)w"
        }
        if let days = components.day {
            if days == 0 {
                return "today"
            } else if days == 1 {
                return "1d"
            } else if days < 0 {
                return "in \(-days)d"
            } else {
                return "\(days)d"
            }
        }
        return "-"
    }
}

#Preview("Annotations Preview") {
    VStack(alignment: .leading, spacing: 20) {
        TaskRowAnnotationsPreview(annotations: [
            TaskAnnotationDto(value: "Reviewed with team, needs refactor before merge", time: "2025-01-13T10:00:00Z"),
            TaskAnnotationDto(value: "Initial implementation complete", time: "2025-01-08T14:30:00Z"),
            TaskAnnotationDto(value: "Started working on this feature", time: "2025-01-05T09:00:00Z"),
        ])
    }
    .padding()
    .background(ThemeManager.current.base)
}

#Preview("Single Annotation") {
    TaskRowAnnotationsPreview(annotations: [
        TaskAnnotationDto(value: "Quick note about this task", time: "2025-01-14T16:00:00Z"),
    ])
    .padding()
    .background(ThemeManager.current.base)
}
