import SwiftUI

struct TaskRow: View {
    let task: ApiTask
    let columns: [String]
    let isSelected: Bool
    let isHovered: Bool
    var isExpanded: Bool = false
    var expandedContent: TaskExpandedContent?
    var onChevronTap: (() -> Void)?

    /// Delayed loading indicator - only shows after 1 second
    @State private var showDelayedLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row
            mainRow

            // Expanded content section
            if isExpanded {
                expandedSection
                    .transition(.asymmetric(
                        insertion: .opacity.animation(.easeIn(duration: 0.2)),
                        removal: .opacity.animation(.easeOut(duration: 0.08))
                    ))
            }
        }
        .padding(.vertical, DesignTokens.Spacing.sm)
        .padding(.horizontal, DesignTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(backgroundColor)
        )
        .zIndex(isExpanded ? 1 : 0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isExpanded)
    }

    private var mainRow: some View {
        HStack(spacing: 12) {
            // Expansion chevron
            chevronIndicator

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
    }

    private var chevronIndicator: some View {
        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(ThemeManager.current.subtext0)
            .frame(width: 12, height: 12)
            .contentShape(Rectangle())
            .onTapGesture {
                onChevronTap?()
            }
    }

    @ViewBuilder
    private var expandedSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            if let content = expandedContent {
                if content.isLoading {
                    // Only show loading indicator after delay
                    if showDelayedLoading {
                        loadingIndicator
                    }
                } else if let error = content.errorMessage {
                    errorView(error)
                } else if content.isEmpty {
                    emptyView
                } else {
                    expandedContentView(content)
                }
            }
        }
        .padding(.top, DesignTokens.Spacing.sm)
        .padding(.leading, 32) // Align with summary column (chevron + circle + spacing)
        .onChange(of: expandedContent?.isLoading) { _, isLoading in
            if isLoading == true {
                // Start timer for delayed loading indicator
                showDelayedLoading = false
                Task {
                    try? await Task.sleep(for: .seconds(1))
                    if expandedContent?.isLoading == true {
                        showDelayedLoading = true
                    }
                }
            } else {
                showDelayedLoading = false
            }
        }
    }

    private var loadingIndicator: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            ProgressView()
                .scaleEffect(0.7)
                .frame(width: 14, height: 14)
            Text("Loading...")
                .font(.system(size: DesignTokens.TypeScale.caption, weight: .medium))
                .foregroundColor(ThemeManager.current.subtext0)
        }
    }

    private func errorView(_ message: String) -> some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: DesignTokens.TypeScale.caption))
                .foregroundColor(ThemeManager.current.red)
            Text(message)
                .font(.system(size: DesignTokens.TypeScale.caption, weight: .medium))
                .foregroundColor(ThemeManager.current.subtext0)
                .lineLimit(1)
        }
    }

    private var emptyView: some View {
        Text("No links or annotations")
            .font(.system(size: DesignTokens.TypeScale.caption, weight: .medium))
            .foregroundColor(ThemeManager.current.subtext0)
    }

    @ViewBuilder
    private func expandedContentView(_ content: TaskExpandedContent) -> some View {
        // Links section
        if !content.links.isEmpty {
            TaskRowLinksPreview(links: content.links)
        }

        // Annotations section
        if !content.annotations.isEmpty {
            TaskRowAnnotationsPreview(annotations: content.annotations)
        }
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

#Preview("Collapsed") {
    TaskRow(
        task: MockApiClient.sampleTasks[0],
        columns: ["id", "summary", "tags", "status"],
        isSelected: true,
        isHovered: false,
        isExpanded: false
    )
    .padding()
    .background(ThemeManager.current.base)
}

#Preview("Expanded Loading") {
    TaskRow(
        task: MockApiClient.sampleTasks[1],
        columns: ["id", "summary", "tags", "status"],
        isSelected: false,
        isHovered: true,
        isExpanded: true,
        expandedContent: TaskExpandedContent(isLoading: true)
    )
    .padding()
    .background(ThemeManager.current.base)
}

#Preview("Expanded Empty") {
    TaskRow(
        task: MockApiClient.sampleTasks[0],
        columns: ["id", "summary", "tags", "status"],
        isSelected: true,
        isHovered: false,
        isExpanded: true,
        expandedContent: TaskExpandedContent(isLoading: false, links: [], annotations: [])
    )
    .padding()
    .background(ThemeManager.current.base)
}
