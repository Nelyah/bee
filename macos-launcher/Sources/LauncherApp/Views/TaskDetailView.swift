import SwiftUI

struct TaskDetailView: View {
    let task: ApiTask
    let detailState: TaskDetailState
    let externalLinksState: ExternalLinksState
    let onRetryDetail: () -> Void
    let onRefreshLinks: (ExternalLinkProvider) -> Void
    let onCopyBranch: (String) -> Void
    let onCopyLink: (String) -> Void
    let onCopyUUID: (String) -> Void
    let onClose: () -> Void
    /// The currently keyboard-focused item (for j/k navigation).
    var focusedItem: DetailFocusableItem?

    // MARK: - Annotation Input

    /// Whether the annotation input field is visible.
    var isAddingAnnotation: Bool = false
    /// Binding to the annotation input text.
    @Binding var annotationInput: String
    /// Whether annotation submission is in progress.
    var isSubmittingAnnotation: Bool = false
    /// Called when the user presses Enter to submit the annotation.
    var onSubmitAnnotation: () -> Void = {}
    /// Called when the user cancels annotation input (Escape).
    var onCancelAnnotation: () -> Void = {}
    /// Called when the user wants to start adding an annotation.
    var onStartAnnotation: () -> Void = {}

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                // Constrain content width and center when view is wider
                let effectiveWidth = min(proxy.size.width, TaskDetailLayout.maxContentWidth)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.large) {
                    header

                    if isSingleColumn(for: effectiveWidth) {
                        metadataColumn
                        externalLinksSection
                    } else {
                        twoColumnLayout(totalWidth: effectiveWidth)
                    }

                    annotationsSection
                    historySection
                }
                .frame(maxWidth: TaskDetailLayout.maxContentWidth, alignment: .leading)
                .frame(maxWidth: .infinity) // Centers content when view is wider
            }
            .onExitCommand {
                onClose()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
            // Back button
            HStack {
                Button {
                    onClose()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: DesignTokens.TypeScale.bodySm, weight: .medium))
                        Text("Back")
                            .font(.system(size: DesignTokens.TypeScale.bodySm, weight: .medium))
                    }
                    .foregroundColor(ThemeManager.current.subtext0)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Spacer()
            }

            HStack(alignment: .top) {
                Text(task.summary)
                    .font(.system(size: DesignTokens.TypeScale.title, weight: .bold, design: .rounded))
                    .foregroundColor(ThemeManager.current.text)
                    .lineLimit(2)
                Spacer()
                Text(task.status.uppercased())
                    .font(.system(size: DesignTokens.TypeScale.bodySm, weight: .semibold, design: .rounded))
                    .foregroundColor(ThemeManager.current.text)
                    .padding(.horizontal, DesignTokens.Spacing.medium)
                    .padding(.vertical, DesignTokens.Spacing.extraSmall)
                    .background(
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous)
                            .fill(ThemeManager.current.surface1)
                    )
            }

            if detailLoading {
                Text("Loading details…")
                    .font(.system(size: DesignTokens.TypeScale.bodySm, weight: .medium))
                    .foregroundColor(ThemeManager.current.subtext0)
            } else if let error = detailError {
                ErrorBannerView(message: error, onRetry: onRetryDetail)
            }
        }
    }

    private var externalLinksSection: some View {
        DetailSection(title: "External Links") {
            if externalLinksLoading {
                Text("Loading links…")
                    .font(.system(size: DesignTokens.TypeScale.bodySm, weight: .medium))
                    .foregroundColor(ThemeManager.current.subtext0)
            } else if let error = externalLinksError {
                ErrorBannerView(message: error)
            }

            ExternalLinksProviderSection(
                title: "GitLab",
                icon: AssetIcon.gitlab(),
                useOriginalIcon: true,
                isRefreshing: externalLinksState.refreshingProviders.contains(.gitlab),
                links: externalLinksForTask.filter { $0.provider.lowercased() == ExternalLinkProvider.gitlab.rawValue },
                onRefresh: { onRefreshLinks(.gitlab) },
                onCopyBranch: onCopyBranch,
                onCopyLink: onCopyLink,
                focusedLinkId: focusedLinkId
            )

            ExternalLinksProviderSection(
                title: "Jira",
                icon: AssetIcon.jira(),
                useOriginalIcon: true,
                isRefreshing: externalLinksState.refreshingProviders.contains(.jira),
                links: externalLinksForTask.filter { $0.provider.lowercased() == ExternalLinkProvider.jira.rawValue },
                onRefresh: { onRefreshLinks(.jira) },
                onCopyBranch: onCopyBranch,
                onCopyLink: onCopyLink,
                focusedLinkId: focusedLinkId
            )
        }
    }

    private var metadataColumn: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.large) {
            DetailSection(title: "Overview") {
                CopyableDetailRow(
                    label: "UUID",
                    value: shortUUID(task.uuid),
                    fullValue: task.uuid,
                    onCopy: onCopyUUID,
                    isKeyboardFocused: isUUIDFocused
                )
                DetailRow(label: "Project", value: task.project ?? "None", helpText: nil)
                DetailRow(
                    label: "Tags",
                    value: task.tags.isEmpty ? "None" : task.tags.joined(separator: ", "),
                    helpText: nil
                )
                DetailRow(label: "Urgency", value: task.urgency.map(String.init) ?? "None", helpText: nil)
            }

            DetailSection(title: "Dates") {
                let created = formattedDate(task.dateCreated)
                DetailRow(label: "Created", value: created.display, helpText: created.help)

                let completed = formattedOptionalDate(task.dateCompleted, emptyLabel: "—")
                DetailRow(label: "Completed", value: completed.display, helpText: completed.help)

                let due = formattedOptionalDate(task.dateDue, emptyLabel: "—")
                DetailRow(label: "Due", value: due.display, helpText: due.help)
            }
        }
    }

    private func twoColumnLayout(totalWidth: CGFloat) -> some View {
        let availableWidth = max(0, totalWidth - TaskDetailLayout.columnSpacing)
        let leftWidth = availableWidth * TaskDetailLayout.leftColumnFraction
        let rightWidth = availableWidth * TaskDetailLayout.rightColumnFraction

        return HStack(alignment: .top, spacing: TaskDetailLayout.columnSpacing) {
            metadataColumn
                .frame(width: leftWidth, alignment: .leading)

            externalLinksSection
                .frame(width: rightWidth, alignment: .leading)
        }
    }

    private func isSingleColumn(for width: CGFloat) -> Bool {
        width < TaskDetailLayout.collapseWidth
    }

    private var annotationsSection: some View {
        DetailSectionWithAction(
            title: "Annotations",
            actionLabel: "Add",
            actionIcon: "plus",
            onAction: onStartAnnotation
        ) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
                // Annotation input field
                if isAddingAnnotation {
                    AnnotationInputField(
                        text: $annotationInput,
                        isSubmitting: isSubmittingAnnotation,
                        onSubmit: onSubmitAnnotation,
                        onCancel: onCancelAnnotation
                    )
                }

                // Existing annotations
                let annotations = sortedAnnotations(detailForTask?.annotations ?? [])
                if annotations.isEmpty, !isAddingAnnotation {
                    Text("—")
                        .font(.system(size: DesignTokens.TypeScale.bodySm, weight: .medium))
                        .foregroundColor(ThemeManager.current.overlay0)
                } else {
                    ForEach(annotations) { annotation in
                        TimelineRow(
                            timestamp: annotation.time,
                            value: annotation.value
                        )
                    }
                }
            }
        }
    }

    private var historySection: some View {
        DetailSection(title: "History") {
            let history = sortedHistory(detailForTask?.history ?? [])
            if history.isEmpty {
                Text("—")
                    .font(.system(size: DesignTokens.TypeScale.bodySm, weight: .medium))
                    .foregroundColor(ThemeManager.current.overlay0)
            } else {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
                    ForEach(history) { entry in
                        TimelineRow(
                            timestamp: entry.datetime,
                            value: entry.value
                        )
                    }
                }
            }
        }
    }

    private func shortUUID(_ value: String) -> String {
        let suffix = value.suffix(8)
        return "…\(suffix)"
    }

    private func formattedDate(_ value: String) -> (display: String, help: String?) {
        let display = RelativeDateFormatter.description(for: value)
        return (display, value)
    }

    private func formattedOptionalDate(_ value: String?, emptyLabel: String) -> (display: String, help: String?) {
        guard let value else {
            return (emptyLabel, nil)
        }
        return formattedDate(value)
    }

    private func sortedAnnotations(_ items: [TaskAnnotationDto]) -> [TaskAnnotationDto] {
        items.sorted { lhs, rhs in
            guard let left = RelativeDateFormatter.date(from: lhs.time),
                  let right = RelativeDateFormatter.date(from: rhs.time)
            else {
                return lhs.time > rhs.time
            }
            return left > right
        }
    }

    private func sortedHistory(_ items: [TaskHistoryDto]) -> [TaskHistoryDto] {
        items.sorted { lhs, rhs in
            guard let left = RelativeDateFormatter.date(from: lhs.datetime),
                  let right = RelativeDateFormatter.date(from: rhs.datetime)
            else {
                return lhs.datetime > rhs.datetime
            }
            return left > right
        }
    }

    private var detailForTask: ApiTaskDetail? {
        guard detailState.taskUUID == task.uuid,
              let detail = detailState.detail,
              detail.uuid == task.uuid
        else {
            return nil
        }
        return detail
    }

    private var detailLoading: Bool {
        detailState.isLoading && detailState.taskUUID == task.uuid
    }

    private var detailError: String? {
        guard detailState.taskUUID == task.uuid else { return nil }
        return detailState.errorMessage
    }

    private var externalLinksForTask: [ExternalLinkDto] {
        guard externalLinksState.taskUUID == task.uuid else { return [] }
        return externalLinksState.links
    }

    private var externalLinksLoading: Bool {
        externalLinksState.isLoading && externalLinksState.taskUUID == task.uuid
    }

    private var externalLinksError: String? {
        guard externalLinksState.taskUUID == task.uuid else { return nil }
        return externalLinksState.errorMessage
    }

    // MARK: - Focus Helpers

    /// Whether the UUID row is currently keyboard-focused.
    private var isUUIDFocused: Bool {
        if case .uuid = focusedItem {
            return true
        }
        return false
    }

    /// Returns the focused link ID if the current focused item is an external link.
    private var focusedLinkId: Int? {
        switch focusedItem {
        case let .gitlabMR(link), let .jiraIssue(link):
            link.id
        default:
            nil
        }
    }
}

private enum TaskDetailLayout {
    static let leftColumnFraction: CGFloat = 0.3
    static let rightColumnFraction: CGFloat = 0.7
    static let columnSpacing: CGFloat = DesignTokens.Spacing.large
    static let collapseWidth: CGFloat = 600
    /// Maximum width for content - centers when view is wider
    static let maxContentWidth: CGFloat = 900
}

/// A card-style container for detail view sections.
/// All sections use consistent visual treatment for proper hierarchy.
private struct DetailSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
            Text(title.uppercased())
                .font(.system(size: DesignTokens.TypeScale.label, weight: .bold, design: .rounded))
                .foregroundColor(ThemeManager.current.subtext0)
            content
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

/// A card-style section with an action button in the header.
private struct DetailSectionWithAction<Content: View>: View {
    let title: String
    let actionLabel: String
    let actionIcon: String
    let onAction: () -> Void
    let content: Content

    init(
        title: String,
        actionLabel: String,
        actionIcon: String,
        onAction: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.actionLabel = actionLabel
        self.actionIcon = actionIcon
        self.onAction = onAction
        self.content = content()
    }

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
            HStack {
                Text(title.uppercased())
                    .font(.system(size: DesignTokens.TypeScale.label, weight: .bold, design: .rounded))
                    .foregroundColor(ThemeManager.current.subtext0)
                Spacer()
                Button(action: onAction) {
                    HStack(spacing: 4) {
                        Image(systemName: actionIcon)
                            .font(.system(size: DesignTokens.TypeScale.caption, weight: .medium))
                        Text(actionLabel)
                            .font(.system(size: DesignTokens.TypeScale.caption, weight: .medium))
                    }
                    .foregroundColor(isHovering ? ThemeManager.current.text : ThemeManager.current.subtext0)
                }
                .buttonStyle(.plain)
                .onHover { isHovering = $0 }
            }
            content
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

/// An inline text field for entering annotation text.
private struct AnnotationInputField: View {
    @Binding var text: String
    let isSubmitting: Bool
    let onSubmit: () -> Void
    let onCancel: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.small) {
            TextField("Enter annotation...", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: DesignTokens.TypeScale.bodySm))
                .foregroundColor(ThemeManager.current.text)
                .focused($isFocused)
                .onSubmit(onSubmit)
                .disabled(isSubmitting)

            if isSubmitting {
                ProgressView()
                    .scaleEffect(0.7)
            } else {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: DesignTokens.TypeScale.caption, weight: .medium))
                        .foregroundColor(ThemeManager.current.subtext0)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.small)
        .padding(.vertical, DesignTokens.Spacing.extraSmall)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous)
                .fill(ThemeManager.current.surface1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous)
                .stroke(
                    isFocused ? ThemeManager.current.blue : ThemeManager.current.surface2,
                    lineWidth: isFocused ? 2 : 1
                )
        )
        .onAppear {
            isFocused = true
        }
    }
}

private struct ExternalLinksProviderSection: View {
    let title: String
    let icon: Image?
    let useOriginalIcon: Bool
    let isRefreshing: Bool
    let links: [ExternalLinkDto]
    let onRefresh: () -> Void
    let onCopyBranch: (String) -> Void
    let onCopyLink: (String) -> Void
    /// The ID of the currently keyboard-focused link (if any).
    var focusedLinkId: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            HStack(spacing: DesignTokens.Spacing.small) {
                if let icon {
                    icon
                        .resizable()
                        .renderingMode(useOriginalIcon ? .original : .template)
                        .foregroundColor(useOriginalIcon ? nil : ThemeManager.current.subtext0)
                        .frame(width: DesignTokens.IconSize.medium, height: DesignTokens.IconSize.medium)
                }
                Text(title)
                    .font(.system(size: DesignTokens.TypeScale.bodySm, weight: .semibold, design: .rounded))
                    .foregroundColor(ThemeManager.current.text)
                Spacer()
                if !links.isEmpty {
                    HoverableButton(
                        action: onRefresh,
                        pressedOpacity: 0.6,
                        pressedScale: 0.96,
                        animationDuration: 0.15
                    ) { isHovering in
                        Group {
                            if isRefreshing {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                Text("Refresh")
                                    .underline(isHovering)
                            }
                        }
                        .font(.system(size: DesignTokens.TypeScale.caption, weight: .medium))
                        .foregroundColor(isHovering ? ThemeManager.current.subtext1 : ThemeManager.current.subtext0)
                    }
                    .contentShape(Rectangle())
                    .disabled(isRefreshing)
                }
            }

            if links.isEmpty {
                Text("—")
                    .font(.system(size: DesignTokens.TypeScale.bodySm, weight: .medium))
                    .foregroundColor(ThemeManager.current.overlay0)
            } else {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
                    ForEach(links, id: \.id) { link in
                        ExternalLinkRow(
                            link: link,
                            onCopyBranch: onCopyBranch,
                            onCopyLink: onCopyLink,
                            isKeyboardFocused: link.id == focusedLinkId
                        )
                    }
                }
            }
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var annotationInput = ""

        var body: some View {
            TaskDetailView(
                task: MockApiClient.sampleTasks[0],
                detailState: TaskDetailState(
                    taskUUID: MockApiClient.sampleTaskDetail.uuid,
                    detail: MockApiClient.sampleTaskDetail
                ),
                externalLinksState: ExternalLinksState(
                    taskUUID: MockApiClient.sampleTaskDetail.uuid,
                    links: MockApiClient.sampleExternalLinks
                ),
                onRetryDetail: {},
                onRefreshLinks: { _ in },
                onCopyBranch: { _ in },
                onCopyLink: { _ in },
                onCopyUUID: { _ in },
                onClose: {},
                annotationInput: $annotationInput
            )
            .padding(DesignTokens.Spacing.extraExtraLarge)
            .frame(width: 600, height: 400)
            .background(ThemeManager.current.base)
        }
    }

    return PreviewWrapper()
}
