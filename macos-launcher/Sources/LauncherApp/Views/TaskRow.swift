import SwiftUI

struct TaskRow: View {
    let task: ApiTask
    let columnConfigs: [ColumnConfig]
    let isSelected: Bool
    var isExpanded: Bool = false
    var expandedContent: TaskExpandedContent?
    var onChevronTap: (() -> Void)?
    /// Optional callback when hover state changes (for ViewModel tracking)
    var onHoverChange: ((Bool) -> Void)?
    /// Testing hook: initial hover state. Only use in tests/previews.
    var initialHovered: Bool = false

    /// Local hover state - prevents full list re-render on hover
    @State private var isHovered = false

    init(
        task: ApiTask,
        columnConfigs: [ColumnConfig],
        isSelected: Bool,
        isExpanded: Bool = false,
        expandedContent: TaskExpandedContent? = nil,
        onChevronTap: (() -> Void)? = nil,
        onHoverChange: ((Bool) -> Void)? = nil,
        initialHovered: Bool = false
    ) {
        self.task = task
        self.columnConfigs = columnConfigs
        self.isSelected = isSelected
        self.isExpanded = isExpanded
        self.expandedContent = expandedContent
        self.onChevronTap = onChevronTap
        self.onHoverChange = onHoverChange
        self.initialHovered = initialHovered
        // Initialize @State with the testing hook value
        _isHovered = State(initialValue: initialHovered)
    }

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
        .padding(.vertical, DesignTokens.Spacing.small)
        .padding(.horizontal, DesignTokens.Spacing.medium)
        .background {
            // Background + selection bar share the same container clipping
            ZStack(alignment: .leading) {
                // Background fill
                backgroundColor

                // Selection accent bar - simple rectangle, clipped by container
                if isSelected {
                    Rectangle()
                        .fill(ThemeManager.current.blue)
                        .frame(width: 5)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium))
        .opacity(rowOpacity)
        .zIndex(isExpanded ? 1 : 0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isExpanded)
        .onHover { hovering in
            isHovered = hovering
            onHoverChange?(hovering)
        }
    }

    private var mainRow: some View {
        HStack(spacing: 12) {
            // Expansion chevron
            chevronIndicator

            // Status indicator with glow effect
            statusIndicator

            // Dynamic columns
            ForEach(columnConfigs) { config in
                columnView(for: config)
            }
        }
    }

    @ViewBuilder
    private func columnView(for config: ColumnConfig) -> some View {
        let column = config.key
        let displayValue = value(for: column) // Compute once, reuse for Text and help

        if config.isFlex {
            // Summary column expands
            Text(displayValue)
                .font(.system(size: DesignTokens.TypeScale.bodyLg, weight: .semibold, design: .rounded))
                .foregroundColor(ThemeManager.current.text)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .help(displayValue)
        } else if column == "id" {
            // ID column - monospaced
            Text(displayValue)
                .font(.system(size: DesignTokens.TypeScale.bodySm, weight: .medium, design: .monospaced))
                .foregroundColor(ThemeManager.current.subtext1)
                .frame(width: config.effectiveWidth, alignment: .leading)
        } else if column == "tags" {
            // Tags column with overflow indicator
            TagsOverflowText(tags: task.tags, maxVisible: maxTagsVisible(for: config.effectiveWidth))
                .frame(width: config.effectiveWidth, alignment: .leading)
        } else {
            // Other columns
            Text(displayValue)
                .font(.system(size: DesignTokens.TypeScale.bodySm, weight: .medium, design: .rounded))
                .foregroundColor(ThemeManager.current.subtext1)
                .frame(width: config.effectiveWidth, alignment: .leading)
                .lineLimit(1)
                .help(displayValue)
        }
    }

    /// Calculate max visible tags based on column width.
    private func maxTagsVisible(for width: CGFloat) -> Int {
        // Roughly 40px per tag, minimum 1
        max(1, Int(width / 40))
    }

    private var chevronIndicator: some View {
        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
            .font(.system(size: DesignTokens.TypeScale.caption, weight: .semibold))
            .foregroundColor(ThemeManager.current.subtext1)
            .frame(width: DesignTokens.IconSize.small, height: DesignTokens.IconSize.small)
            .contentShape(Rectangle())
            .onTapGesture {
                onChevronTap?()
            }
    }

    /// Status indicator with glow effect for better visibility
    private var statusIndicator: some View {
        let color = statusColor(task.status)
        return Circle()
            .fill(color)
            .frame(width: DesignTokens.IconSize.statusIndicator, height: DesignTokens.IconSize.statusIndicator)
            .shadow(color: color.opacity(0.5), radius: 4, x: 0, y: 0)
    }

    /// Whether this task is completed (for dimming effect)
    private var isCompleted: Bool {
        task.status.lowercased() == "completed"
    }

    /// Opacity for the row - completed tasks are dimmed
    private var rowOpacity: Double {
        isCompleted ? 0.65 : 1.0
    }

    @ViewBuilder
    private var expandedSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
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
        .padding(.top, DesignTokens.Spacing.small)
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
        HStack(spacing: DesignTokens.Spacing.small) {
            ProgressView()
                .scaleEffect(0.7)
                .frame(width: DesignTokens.IconSize.medium, height: DesignTokens.IconSize.medium)
            Text("Loading...")
                .font(.system(size: DesignTokens.TypeScale.caption, weight: .medium))
                .foregroundColor(ThemeManager.current.subtext0)
        }
    }

    private func errorView(_ message: String) -> some View {
        HStack(spacing: DesignTokens.Spacing.extraSmall) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: DesignTokens.TypeScale.caption))
                .foregroundColor(ThemeManager.current.red)
            Text(message)
                .font(.system(size: DesignTokens.TypeScale.caption, weight: .medium))
                .foregroundColor(ThemeManager.current.subtext1)
                .lineLimit(1)
        }
    }

    private var emptyView: some View {
        Text("—")
            .font(.system(size: DesignTokens.TypeScale.caption, weight: .medium))
            .foregroundColor(ThemeManager.current.overlay0)
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
        if isSelected, isHovered {
            return ThemeManager.current.surfaceSelectedHover
        }
        if isSelected {
            return ThemeManager.current.surfaceSelected
        }
        if isHovered {
            return ThemeManager.current.surfaceHover
        }
        return ThemeManager.current.base
    }

    /// Get the value for a column from the task.
    /// Direct switch-based lookup avoids dictionary allocation per access.
    private func value(for column: String) -> String {
        switch column {
        case "id": task.dbId.map(String.init) ?? "-"
        case "uuid": String(task.uuid.suffix(8))
        case "summary": task.summary
        case "status": task.status
        case "project": task.project ?? "-"
        case "tags": task.tags.isEmpty ? "-" : task.tags.joined(separator: ", ")
        case "urgency": task.urgency.map(String.init) ?? "-"
        case "date_created": formatDate(task.dateCreated)
        case "date_completed": task.dateCompleted.map(formatDate) ?? "-"
        case "date_due": task.dateDue.map(formatDate) ?? "-"
        default: "-"
        }
    }

    /// Format an ISO date string to a relative or short format.
    private func formatDate(_ isoDate: String) -> String {
        RelativeDateFormatter.description(for: isoDate)
    }
}

/// Helper for creating sample column configs in previews.
private let sampleColumnConfigs = [
    ColumnConfig(key: "id", displayName: "ID", width: nil),
    ColumnConfig(key: "summary", displayName: "Summary", width: nil),
    ColumnConfig(key: "tags", displayName: "Tags", width: nil),
    ColumnConfig(key: "status", displayName: "Status", width: nil),
]

#Preview("Collapsed") {
    TaskRow(
        task: MockApiClient.sampleTasks[0],
        columnConfigs: sampleColumnConfigs,
        isSelected: true,
        isExpanded: false
    )
    .padding()
    .background(ThemeManager.current.base)
}

#Preview("Expanded Loading") {
    TaskRow(
        task: MockApiClient.sampleTasks[1],
        columnConfigs: sampleColumnConfigs,
        isSelected: false,
        isExpanded: true,
        expandedContent: TaskExpandedContent(isLoading: true)
    )
    .padding()
    .background(ThemeManager.current.base)
}

#Preview("Expanded Empty") {
    TaskRow(
        task: MockApiClient.sampleTasks[0],
        columnConfigs: sampleColumnConfigs,
        isSelected: true,
        isExpanded: true,
        expandedContent: TaskExpandedContent(isLoading: false, links: [], annotations: [])
    )
    .padding()
    .background(ThemeManager.current.base)
}
