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

    // MARK: - Task Name Editing

    /// Whether the task name is being edited.
    var isEditingTaskName: Bool = false
    /// Binding to the task name edit input.
    @Binding var taskNameEditInput: String
    /// Whether task name submission is in progress.
    var isSubmittingTaskName: Bool = false
    /// Called when the user clicks on the task name to edit it.
    var onStartEditingTaskName: () -> Void = {}
    /// Called when the user submits the task name edit.
    var onSubmitTaskNameEdit: () -> Void = {}
    /// Called when the user cancels the task name edit.
    var onCancelTaskNameEdit: () -> Void = {}

    // MARK: - Annotation Editing

    /// ID of the annotation being edited (nil = not editing).
    /// Uses annotation ID instead of index to avoid mismatch when annotations are sorted.
    var editingAnnotationId: String?
    /// Binding to the annotation edit input.
    @Binding var annotationEditInput: String
    /// Whether annotation edit submission is in progress.
    var isSubmittingAnnotationEdit: Bool = false
    /// Called when the user clicks on an annotation to edit it (passes annotation ID).
    var onStartEditingAnnotation: (String) -> Void = { _ in }
    /// Called when the user submits the annotation edit.
    var onSubmitAnnotationEdit: () -> Void = {}
    /// Called when the user cancels the annotation edit.
    var onCancelAnnotationEdit: () -> Void = {}

    // MARK: - Project Editing

    /// Whether the project field is being edited.
    var isEditingProject: Bool = false
    /// Binding to the project edit input.
    @Binding var projectEditInput: String
    /// Whether project submission is in progress.
    var isSubmittingProject: Bool = false
    /// Filtered project completions for autocomplete.
    var filteredProjects: [CompletionItem] = []
    /// Called when the user clicks on the project to edit it.
    var onStartEditingProject: () -> Void = {}
    /// Called when the user submits the project edit.
    var onSubmitProjectEdit: () -> Void = {}
    /// Called when the user cancels the project edit.
    var onCancelProjectEdit: () -> Void = {}
    /// Called when the user selects a project from autocomplete.
    var onSelectProjectCompletion: (CompletionItem) -> Void = { _ in }

    // MARK: - Tag Editing

    /// Index of the currently selected tag for keyboard navigation (nil = no selection).
    var selectedTagIndex: Int?
    /// Whether the user is adding a new tag.
    var isAddingTag: Bool = false
    /// Binding to the tag add query.
    @Binding var tagAddQuery: String
    /// Whether a tag operation is in progress.
    var isSubmittingTag: Bool = false
    /// All available tag completions for autocomplete.
    var allTagCompletions: [CompletionItem] = []
    /// Called when user selects a tag index (for keyboard navigation).
    var onSelectTagIndex: (Int?) -> Void = { _ in }
    /// Called when the user wants to start adding a tag.
    var onStartAddingTag: () -> Void = {}
    /// Called when the user cancels adding a tag.
    var onCancelAddingTag: () -> Void = {}
    /// Called when the user selects a tag from autocomplete.
    var onSelectTagCompletion: (CompletionItem) -> Void = { _ in }
    /// Called when the user removes a tag.
    var onRemoveTag: (String) -> Void = { _ in }
    /// Called when the user wants to edit a tag at a specific index (Enter on focused tag).
    var onEditTag: (Int) -> Void = { _ in }

    // MARK: - Due Date Editing

    /// Whether the due date field is being edited.
    var isEditingDueDate: Bool = false
    /// Binding to the date picker selection.
    @Binding var dueDateEditSelection: Date
    /// Whether due date submission is in progress.
    var isSubmittingDueDate: Bool = false
    /// Called when the user clicks on the due date to edit it.
    var onStartEditingDueDate: () -> Void = {}
    /// Called when the user submits the due date edit.
    var onSubmitDueDateEdit: () -> Void = {}
    /// Called when the user cancels the due date edit.
    var onCancelDueDateEdit: () -> Void = {}
    /// Called when the user clears the due date.
    var onClearDueDate: () -> Void = {}
    /// Called when the user selects a quick date action.
    var onQuickDueDateAction: (QuickDueDateAction) -> Void = { _ in }

    // MARK: - Attachments

    /// ID of attachment currently showing delete confirmation.
    var confirmingDeleteAttachmentId: Int?
    /// Called when the user wants to add an attachment.
    var onAddAttachment: () -> Void = {}
    /// Called when the user clicks to select an attachment.
    var onSelectAttachment: (TaskAttachmentDto) -> Void = { _ in }
    /// Called when the user wants to open an attachment.
    var onOpenAttachment: (TaskAttachmentDto) -> Void = { _ in }
    /// Called when the user starts the delete confirmation.
    var onDeleteAttachment: (TaskAttachmentDto) -> Void = { _ in }
    /// Called when the user confirms deletion.
    var onConfirmDeleteAttachment: (TaskAttachmentDto) -> Void = { _ in }
    /// Called when the user cancels deletion.
    var onCancelDeleteAttachment: () -> Void = {}
    /// Called when files are dropped onto the attachments section.
    var onDropAttachments: ([URL]) -> Void = { _ in }
    /// Called when an email is dropped from Apple Mail.
    var onEmailDrop: (ParsedEmail) -> Void = { _ in }
    /// Called when the user clicks on an email link to open it.
    var onOpenEmailLink: (EmailLinkDto) -> Void = { _ in }

    // MARK: - Linked Tasks

    /// All tasks for looking up linked task details (title, status).
    var tasks: [ApiTask] = []
    /// Called when the user clicks on a linked task to navigate to it.
    var onNavigateToTask: (String) -> Void = { _ in }

    // MARK: - Task State

    /// Called when the user changes the task state via the status menu.
    var onTaskStateChange: ((TaskStateAction, String) -> Void)?
    /// Trigger provider for programmatic menu display (Cmd+P).
    var taskStateMenuTrigger: MenuTriggerProvider?

    // MARK: - Focus Management

    /// Called when the user clicks on the background to clear focus.
    var onClearFocus: () -> Void = {}

    // MARK: - Collapsible Sections

    /// Whether the history section is expanded (collapsed by default).
    @State private var isHistoryExpanded: Bool = false

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
                    attachmentsSection
                    emailLinksSection
                    linkedTasksSection
                    historySection

                    // Reserve space for BottomHintBar overlay so scroll content isn't hidden
                    Color.clear.frame(height: BottomHintBar.height + DesignTokens.Spacing.large)
                }
                .frame(maxWidth: TaskDetailLayout.maxContentWidth, alignment: .leading)
                .frame(maxWidth: .infinity) // Centers content when view is wider
                .background {
                    // Tap on empty space clears focus, but doesn't steal events from child views
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onClearFocus()
                        }
                }
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
                if isEditingTaskName {
                    ExpandingTextEditor(
                        text: $taskNameEditInput,
                        placeholder: "Task name...",
                        isSubmitting: isSubmittingTaskName,
                        onSubmit: onSubmitTaskNameEdit,
                        onCancel: onCancelTaskNameEdit,
                        minHeight: 40
                    )
                } else {
                    Text(task.summary)
                        .font(.system(size: DesignTokens.TypeScale.title, weight: .bold, design: .rounded))
                        .foregroundColor(ThemeManager.current.text)
                        .lineLimit(nil)
                        .padding(.horizontal, DesignTokens.Spacing.small)
                        .padding(.vertical, DesignTokens.Spacing.extraSmall)
                        .modifier(DetailFocusRing(isFocused: isTaskNameFocused))
                        .onTapGesture {
                            onStartEditingTaskName()
                        }
                        .help(isTaskNameFocused ? "Press Enter to edit" : "Click to edit")
                }
                Spacer()
                TaskStateMenuButton(
                    currentStatus: task.status,
                    onSelect: { action in
                        onTaskStateChange?(action, task.uuid)
                    },
                    triggerProvider: taskStateMenuTrigger
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
                projectRow
                EditableTagsRow(
                    tags: task.tags,
                    selectedTagIndex: selectedTagIndex,
                    keyboardFocusedTagIndex: keyboardFocusedTagIndex,
                    isAddButtonFocused: isAddButtonFocused,
                    isAddingTag: isAddingTag,
                    tagAddQuery: $tagAddQuery,
                    allTagCompletions: allTagCompletions,
                    isSubmitting: isSubmittingTag,
                    onSelectTagIndex: onSelectTagIndex,
                    onStartAdding: onStartAddingTag,
                    onCancelAdding: onCancelAddingTag,
                    onSelectCompletion: onSelectTagCompletion,
                    onRemoveTag: onRemoveTag,
                    onEditTag: onEditTag
                )
                DetailRow(label: "Urgency", value: task.urgency.map(String.init) ?? "None", helpText: nil)
            }
            .zIndex(1) // Keep project completion dropdown above later sections in this column

            DetailSection(title: "Dates") {
                let created = formattedDate(task.dateCreated)
                DetailRow(label: "Created", value: created.display, helpText: created.help)

                let completed = formattedOptionalDate(task.dateCompleted, emptyLabel: "—")
                DetailRow(label: "Completed", value: completed.display, helpText: completed.help)

                EditableDueDateRow(
                    currentDueDate: task.dateDue,
                    isEditing: isEditingDueDate,
                    selectedDate: $dueDateEditSelection,
                    isSubmitting: isSubmittingDueDate,
                    isFocused: isDueDateFocused,
                    onStartEditing: onStartEditingDueDate,
                    onSubmit: onSubmitDueDateEdit,
                    onCancel: onCancelDueDateEdit,
                    onClear: onClearDueDate,
                    onQuickAction: onQuickDueDateAction
                )
            }
            .zIndex(0)
        }
    }

    private func twoColumnLayout(totalWidth: CGFloat) -> some View {
        let availableWidth = max(0, totalWidth - TaskDetailLayout.columnSpacing)
        let leftWidth = availableWidth * TaskDetailLayout.leftColumnFraction
        let rightWidth = availableWidth * TaskDetailLayout.rightColumnFraction

        return HStack(alignment: .top, spacing: TaskDetailLayout.columnSpacing) {
            metadataColumn
                .frame(width: leftWidth, alignment: .leading)
                .zIndex(1) // Ensure left column overlays (e.g., project dropdown) draw above right column

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
                // New annotation input field
                if isAddingAnnotation {
                    ExpandingTextEditor(
                        text: $annotationInput,
                        placeholder: "Enter annotation...",
                        isSubmitting: isSubmittingAnnotation,
                        onSubmit: onSubmitAnnotation,
                        onCancel: onCancelAnnotation
                    )
                }

                // Existing annotations
                let annotations = sortedAnnotations(detailForTask?.annotations ?? [])
                if annotations.isEmpty, !isAddingAnnotation {
                    Text("—")
                        .font(.system(size: DesignTokens.TypeScale.body, weight: .medium))
                        .foregroundColor(ThemeManager.current.overlay0)
                } else {
                    ForEach(annotations) { annotation in
                        if editingAnnotationId == annotation.id {
                            // Edit mode for this annotation
                            ExpandingTextEditor(
                                text: $annotationEditInput,
                                placeholder: "Edit annotation...",
                                isSubmitting: isSubmittingAnnotationEdit,
                                onSubmit: onSubmitAnnotationEdit,
                                onCancel: onCancelAnnotationEdit
                            )
                        } else {
                            // Display mode - clickable to edit
                            EditableTimelineRow(
                                timestamp: annotation.time,
                                value: annotation.value,
                                onTap: { onStartEditingAnnotation(annotation.id) }
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: - Attachments Section

    @ViewBuilder
    private var attachmentsSection: some View {
        if let detail = detailForTask {
            AttachmentsSection(
                attachments: detail.attachments,
                focusedItem: focusedItem,
                confirmingDeleteId: confirmingDeleteAttachmentId,
                onAdd: onAddAttachment,
                onSelect: onSelectAttachment,
                onOpen: onOpenAttachment,
                onDelete: onDeleteAttachment,
                onConfirmDelete: onConfirmDeleteAttachment,
                onCancelDelete: onCancelDeleteAttachment,
                onDrop: onDropAttachments,
                onEmailDrop: onEmailDrop
            )
        }
    }

    // MARK: - Email Links Section

    @ViewBuilder
    private var emailLinksSection: some View {
        if let detail = detailForTask {
            EmailLinksSection(
                emailLinks: detail.emailLinks,
                onOpen: onOpenEmailLink
            )
        }
    }

    // MARK: - Linked Tasks Section

    @ViewBuilder
    private var linkedTasksSection: some View {
        if let detail = detailForTask {
            LinkedTasksSection(
                links: detail.links,
                linksByType: detail.linksByType(),
                tasks: tasks,
                focusedItem: focusedItem,
                onNavigateToTask: onNavigateToTask
            )
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
            // Collapsible header (styled like DetailSection)
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHistoryExpanded.toggle()
                }
            } label: {
                HStack(spacing: DesignTokens.Spacing.small) {
                    Image(systemName: isHistoryExpanded ? "chevron.down" : "chevron.right")
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
            if isHistoryExpanded {
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

    // MARK: - Project Row

    private var projectRow: some View {
        EditableProjectRow(
            currentProject: task.project,
            isEditing: isEditingProject,
            editInput: $projectEditInput,
            isSubmitting: isSubmittingProject,
            allProjects: filteredProjects,
            isFocused: isProjectFocused,
            onStartEditing: onStartEditingProject,
            onSubmit: onSubmitProjectEdit,
            onCancel: onCancelProjectEdit,
            onSelectCompletion: onSelectProjectCompletion
        )
        .zIndex(2) // Ensure project completion dropdown overlays Dates section
    }
}

// MARK: - Focus Helpers

private extension TaskDetailView {
    /// Whether the task name is currently keyboard-focused.
    var isTaskNameFocused: Bool {
        if case .taskName = focusedItem {
            return true
        }
        return false
    }

    /// Whether the UUID row is currently keyboard-focused.
    var isUUIDFocused: Bool {
        if case .uuid = focusedItem {
            return true
        }
        return false
    }

    /// Whether the project row is currently keyboard-focused.
    var isProjectFocused: Bool {
        if case .project = focusedItem {
            return true
        }
        return false
    }

    /// Returns the focused link ID if the current focused item is an external link.
    var focusedLinkId: Int? {
        switch focusedItem {
        case let .gitlabMR(link), let .jiraIssue(link):
            link.id
        default:
            nil
        }
    }

    /// Returns the focused tag index if the current focused item is a tag.
    var keyboardFocusedTagIndex: Int? {
        switch focusedItem {
        case let .tag(_, index):
            index
        default:
            nil
        }
    }

    /// Whether the add tag button is keyboard-focused.
    var isAddButtonFocused: Bool {
        if case .addTagButton = focusedItem {
            return true
        }
        return false
    }

    /// Whether the due date row is keyboard-focused.
    var isDueDateFocused: Bool {
        if case .dueDate = focusedItem {
            return true
        }
        return false
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

#Preview {
    struct PreviewWrapper: View {
        @State private var annotationInput = ""
        @State private var taskNameEditInput = ""
        @State private var annotationEditInput = ""
        @State private var projectEditInput = ""
        @State private var tagAddQuery = ""
        @State private var dueDateEditSelection = Date()

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
                annotationInput: $annotationInput,
                taskNameEditInput: $taskNameEditInput,
                annotationEditInput: $annotationEditInput,
                projectEditInput: $projectEditInput,
                tagAddQuery: $tagAddQuery,
                dueDateEditSelection: $dueDateEditSelection
            )
            .padding(DesignTokens.Spacing.extraExtraLarge)
            .frame(width: 600, height: 400)
            .background(ThemeManager.current.base)
        }
    }

    return PreviewWrapper()
}
