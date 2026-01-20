import AppKit
import SwiftUI

public struct ContentView: View {
    @ObservedObject public var viewModel: LauncherViewModel

    public init(viewModel: LauncherViewModel) {
        self.viewModel = viewModel
    }

    @State private var escapeMonitor: Any?
    @State private var normalModeMonitor: Any?
    @State private var detailModeMonitor: Any?
    /// Trigger provider for programmatic task state menu display (Cmd+P).
    @State private var taskStateMenuTrigger = MenuTriggerProvider()

    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
            WindowAccessor { window in
                WindowConfiguration.applyBorderlessStyle(to: window)
            }

            launcherBackground

            if viewModel.mode == .detail, let task = viewModel.selectedTask {
                TaskDetailView(
                    task: task,
                    detailState: viewModel.taskDetailState,
                    externalLinksState: viewModel.externalLinksState,
                    onRetryDetail: {
                        viewModel.loadTaskDetail(taskUUID: task.uuid)
                    },
                    onRefreshLinks: { provider in
                        viewModel.refreshExternalLinks(provider: provider)
                    },
                    onCopyBranch: { branch in
                        viewModel.copyBranchNameToClipboard(branch)
                    },
                    onCopyLink: { url in
                        viewModel.copyLinkToClipboard(url)
                    },
                    onCopyUUID: { uuid in
                        viewModel.copyUUIDToClipboard(uuid)
                    },
                    onClose: {
                        viewModel.closeDetail()
                    },
                    focusedItem: viewModel.focusedDetailItem,
                    isAddingAnnotation: viewModel.isAddingAnnotation,
                    annotationInput: $viewModel.annotationInput,
                    isSubmittingAnnotation: viewModel.isSubmittingAnnotation,
                    onSubmitAnnotation: {
                        viewModel.submitAnnotation()
                    },
                    onCancelAnnotation: {
                        viewModel.cancelAddingAnnotation()
                    },
                    onStartAnnotation: {
                        viewModel.startAddingAnnotation()
                    },
                    // Task name editing
                    isEditingTaskName: viewModel.isEditingTaskName,
                    taskNameEditInput: $viewModel.taskNameEditInput,
                    isSubmittingTaskName: viewModel.isSubmittingTaskName,
                    onStartEditingTaskName: {
                        viewModel.startEditingTaskName()
                    },
                    onSubmitTaskNameEdit: {
                        viewModel.submitTaskNameEdit()
                    },
                    onCancelTaskNameEdit: {
                        viewModel.cancelEditingTaskName()
                    },
                    // Annotation editing
                    editingAnnotationId: viewModel.editingAnnotationId,
                    annotationEditInput: $viewModel.annotationEditInput,
                    isSubmittingAnnotationEdit: viewModel.isSubmittingAnnotationEdit,
                    onStartEditingAnnotation: { annotationId in
                        viewModel.startEditingAnnotation(withId: annotationId)
                    },
                    onSubmitAnnotationEdit: {
                        viewModel.submitAnnotationEdit()
                    },
                    onCancelAnnotationEdit: {
                        viewModel.cancelEditingAnnotation()
                    },
                    // Project editing
                    isEditingProject: viewModel.isEditingProject,
                    projectEditInput: $viewModel.projectEditInput,
                    isSubmittingProject: viewModel.isSubmittingProject,
                    filteredProjects: viewModel.filteredProjects,
                    onStartEditingProject: {
                        viewModel.startEditingProject()
                    },
                    onSubmitProjectEdit: {
                        viewModel.submitProjectEdit()
                    },
                    onCancelProjectEdit: {
                        viewModel.cancelEditingProject()
                    },
                    onSelectProjectCompletion: { item in
                        viewModel.selectProjectFromCompletion(item)
                    },
                    // Tag editing
                    selectedTagIndex: viewModel.selectedTagIndex,
                    isAddingTag: viewModel.isAddingTag,
                    tagAddQuery: $viewModel.tagAddQuery,
                    isSubmittingTag: viewModel.isSubmittingTag,
                    allTagCompletions: viewModel.allTagCompletions,
                    onSelectTagIndex: { index in
                        viewModel.selectTagIndex(index)
                    },
                    onStartAddingTag: {
                        viewModel.startAddingTag()
                    },
                    onCancelAddingTag: {
                        viewModel.cancelAddingTag()
                    },
                    onSelectTagCompletion: { item in
                        viewModel.selectTagFromCompletion(item)
                    },
                    onRemoveTag: { tag in
                        viewModel.removeTag(tag)
                    },
                    onEditTag: { index in
                        viewModel.startEditingTag(at: index)
                    },
                    // Due date editing
                    isEditingDueDate: viewModel.isEditingDueDate,
                    dueDateEditSelection: $viewModel.dueDateEditSelection,
                    isSubmittingDueDate: viewModel.isSubmittingDueDate,
                    onStartEditingDueDate: {
                        viewModel.startEditingDueDate()
                    },
                    onSubmitDueDateEdit: {
                        viewModel.submitDueDateEdit()
                    },
                    onCancelDueDateEdit: {
                        viewModel.cancelEditingDueDate()
                    },
                    onClearDueDate: {
                        viewModel.clearDueDate()
                    },
                    onQuickDueDateAction: { action in
                        viewModel.applyQuickDueDateAction(action)
                    },
                    // Planned date editing
                    isEditingPlannedDate: viewModel.isEditingPlannedDate,
                    plannedDateEditSelection: $viewModel.plannedDateEditSelection,
                    isSubmittingPlannedDate: viewModel.isSubmittingPlannedDate,
                    onStartEditingPlannedDate: {
                        viewModel.startEditingPlannedDate()
                    },
                    onSubmitPlannedDateEdit: {
                        viewModel.submitPlannedDateEdit()
                    },
                    onCancelPlannedDateEdit: {
                        viewModel.cancelEditingPlannedDate()
                    },
                    onClearPlannedDate: {
                        viewModel.clearPlannedDate()
                    },
                    onQuickPlannedDateAction: { action in
                        viewModel.applyQuickPlannedDateAction(action)
                    },
                    // Attachments
                    confirmingDeleteAttachmentId: viewModel.confirmingDeleteAttachmentId,
                    onAddAttachment: {
                        viewModel.addAttachment()
                    },
                    onSelectAttachment: { attachment in
                        viewModel.selectAttachment(attachment)
                    },
                    onOpenAttachment: { attachment in
                        viewModel.openAttachment(attachment)
                    },
                    onDeleteAttachment: { attachment in
                        viewModel.startDeleteAttachment(attachment)
                    },
                    onConfirmDeleteAttachment: { attachment in
                        Task { await viewModel.confirmDeleteAttachment(attachment) }
                    },
                    onCancelDeleteAttachment: {
                        viewModel.cancelDeleteAttachment()
                    },
                    onDropAttachments: { urls in
                        viewModel.handleAttachmentDrop(urls)
                    },
                    onEmailDrop: { email in
                        viewModel.handleEmailDrop(email)
                    },
                    onOpenEmailLink: { emailLink in
                        viewModel.openEmailLinkUrl(emailLink.mailUrl)
                    },
                    onOpenImportantLink: { importantLink in
                        if let url = URL(string: importantLink.url) {
                            NSWorkspace.shared.open(url)
                        }
                    },
                    onRemoveImportantLink: { link in
                        Task { await viewModel.removeImportantLink(link) }
                    },
                    onStartAddingImportantLink: {
                        viewModel.startAddingImportantLink()
                    },
                    isAddingImportantLink: viewModel.isAddingImportantLink,
                    importantLinkUrlInput: $viewModel.importantLinkUrlInput,
                    importantLinkTitleInput: $viewModel.importantLinkTitleInput,
                    isSubmittingImportantLink: viewModel.isSubmittingImportantLink,
                    onSubmitImportantLink: {
                        Task { await viewModel.submitImportantLink() }
                    },
                    onCancelAddingImportantLink: {
                        viewModel.cancelAddingImportantLink()
                    },
                    // Linked tasks navigation
                    tasks: viewModel.tasks,
                    onNavigateToTask: { uuid in
                        viewModel.navigateToTask(uuid: uuid)
                    },
                    // Task state changes
                    onTaskStateChange: { action, uuid in
                        viewModel.handleTaskStateChange(action, taskUUID: uuid)
                    },
                    taskStateMenuTrigger: taskStateMenuTrigger,
                    // Focus management
                    onClearFocus: {
                        viewModel.clearDetailFocus()
                        // Cancel adding important link if URL is empty (click-away-to-cancel behavior)
                        if viewModel.isAddingImportantLink,
                           viewModel.importantLinkUrlInput.trimmingCharacters(in: .whitespacesAndNewlines)
                           .isEmpty {
                            viewModel.cancelAddingImportantLink()
                        }
                    },
                    onRegisterNavigation: { entries in
                        for entry in entries {
                            viewModel.navigationRegistry.register(entry.item, frame: entry.frame)
                        }
                    }
                )
                .padding(DesignTokens.Spacing.extraExtraLarge)
                .onAppear {
                    // Wire up the Cmd+P trigger for task state menu
                    viewModel.taskStateMenuTrigger = {
                        taskStateMenuTrigger.trigger?()
                    }
                }
            } else if viewModel.mode == .projectOverview {
                ProjectOverviewView(viewModel: viewModel)
                    .padding(DesignTokens.Spacing.extraExtraLarge)
            } else {
                TaskListView(viewModel: viewModel, completion: viewModel.completion)
                    .padding(DesignTokens.Spacing.extraLarge)
            }

            if viewModel.commandPalette.isPresented {
                CommandPaletteView(viewModel: viewModel, commandPalette: viewModel.commandPalette)
            }

            ToastStackView(toasts: viewModel.toasts)
                .padding(.horizontal, DesignTokens.Spacing.large)
                .padding(.bottom, BottomHintBar.height + 40)
                .allowsHitTesting(false)
                .zIndex(2)
        }
        .overlay(alignment: .bottom) {
            BottomHintBar(
                leftHints: viewModel.hintModel.left,
                rightHints: viewModel.hintModel.right,
                onAction: viewModel.handleHintAction
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
            .zIndex(1)
        }
        .onExitCommand {
            viewModel.handleEscape()
        }
        .onReceive(viewModel.windowClose) { _ in
            closeWindow()
        }
        .clipShape(RoundedRectangle(cornerRadius: WindowConfiguration.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: WindowConfiguration.cornerRadius, style: .continuous)
                .stroke(ThemeManager.current.surface1.opacity(DesignTokens.Border.containerOpacity), lineWidth: 1)
        )
        .frame(minWidth: 680, minHeight: 440)
        .ignoresSafeArea()
        .sheet(isPresented: $viewModel.showingSaveReportSheet) {
            SaveReportSheet(
                isPresented: $viewModel.showingSaveReportSheet,
                currentFilter: viewModel.lastSuccessfulParse?.filter,
                filterChipLabels: viewModel.criteriaFilterChips.map(\.label),
                currentColumns: viewModel.reportConfig?.columns ?? [],
                currentColumnNames: viewModel.reportConfig?.columnNames ?? [],
                staticReportNames: Set(viewModel.availableReports.filter { !$0.isUserReport }.map(\.name)),
                existingUserReportNames: Set(viewModel.availableReports.filter(\.isUserReport).map(\.name)),
                onSave: { name, filter, columns, columnNames in
                    let isUpdate = viewModel.availableReports.contains { $0.name == name && $0.isUserReport }
                    Task {
                        await viewModel.saveReport(
                            name: name,
                            filter: filter,
                            columns: columns,
                            columnNames: columnNames,
                            isUpdate: isUpdate
                        )
                    }
                }
            )
        }
        .onAppear {
            DispatchQueue.main.async {
                NSApplication.shared.setActivationPolicy(.regular)
                NSApplication.shared.activate(ignoringOtherApps: true)
                installEscapeMonitor()
                installNormalModeMonitor()
                installDetailModeMonitor()
            }
        }
        .onDisappear {
            removeEscapeMonitor()
            removeNormalModeMonitor()
            removeDetailModeMonitor()
        }
    }

    private var launcherBackground: some View {
        ThemeManager.current.base
    }

    /// Capture Escape at the window level to close detail view or exit insert mode.
    private func installEscapeMonitor() {
        guard escapeMonitor == nil else { return }
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == KeyCode.escape {
                return viewModel.handleEscape() ? nil : event
            }
            return event
        }
    }

    /// Remove the Escape key monitor.
    private func removeEscapeMonitor() {
        if let monitor = escapeMonitor {
            NSEvent.removeMonitor(monitor)
            escapeMonitor = nil
        }
    }

    /// Handle keys in normal mode (when text input is not focused).
    private func installNormalModeMonitor() {
        guard normalModeMonitor == nil else { return }
        normalModeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Only handle keys in normal mode (not insert mode), in list mode (not detail), and when command palette is
            // closed
            guard !viewModel.isInsertMode,
                  viewModel.mode == .list,
                  !viewModel.commandPalette.isPresented else { return event }
            guard let action = KeyHandlingDecider.normalModeAction(for: KeyInput(event: event)) else {
                return event
            }

            return viewModel.handleNormalModeAction(action) ? nil : event
        }
    }

    /// Remove the normal mode key monitor.
    private func removeNormalModeMonitor() {
        if let monitor = normalModeMonitor {
            NSEvent.removeMonitor(monitor)
            normalModeMonitor = nil
        }
    }

    /// Handle keys in detail mode (j/k/o/y for vim-style navigation).
    private func installDetailModeMonitor() {
        guard detailModeMonitor == nil else { return }
        detailModeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Only handle keys in detail mode when not in any editing state
            guard viewModel.mode == .detail,
                  !viewModel.commandPalette.isPresented,
                  !isTextInputFirstResponder() else { return event }
            guard let action = KeyHandlingDecider.detailModeAction(for: KeyInput(event: event)) else {
                return event
            }

            return viewModel.handleDetailModeAction(action) ? nil : event
        }
    }

    /// Remove the detail mode key monitor.
    private func removeDetailModeMonitor() {
        if let monitor = detailModeMonitor {
            NSEvent.removeMonitor(monitor)
            detailModeMonitor = nil
        }
    }

    /// Returns true if the current first responder is a text input field.
    /// Allows keyboard shortcuts to automatically pass through to text fields
    /// without requiring explicit state tracking for each field.
    private func isTextInputFirstResponder() -> Bool {
        guard let window = NSApp.keyWindow,
              let responder = window.firstResponder else {
            return false
        }
        // NSTextView is used by both TextField and TextEditor in SwiftUI
        return responder is NSTextView || responder is NSTextField
    }

    private func closeWindow() {
        let app = NSApplication.shared
        if let window = app.keyWindow ?? app.mainWindow {
            window.close()
            return
        }
        if let window = app.windows.first(where: { $0.isVisible }) ?? app.windows.first {
            window.close()
            return
        }
        _ = app.sendAction(#selector(NSWindow.performClose(_:)), to: nil, from: nil)
    }
}

#Preview("List Mode") {
    let viewModel = LauncherViewModel(apiClient: MockApiClient())
    viewModel.tasks = MockApiClient.sampleTasks

    return ContentView(viewModel: viewModel)
        .frame(width: 680, height: 440)
}

#Preview("Detail Mode") {
    let viewModel = LauncherViewModel(apiClient: MockApiClient())
    viewModel.tasks = MockApiClient.sampleTasks
    viewModel.selectedIndex = 0
    viewModel.openDetail()

    return ContentView(viewModel: viewModel)
        .frame(width: 680, height: 440)
}
