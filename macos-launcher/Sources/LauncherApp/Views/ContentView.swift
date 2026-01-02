import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: LauncherViewModel
    @State private var escapeMonitor: Any?
    @State private var normalModeMonitor: Any?
    @State private var detailModeMonitor: Any?

    var body: some View {
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
                    editingAnnotationIndex: viewModel.editingAnnotationIndex,
                    annotationEditInput: $viewModel.annotationEditInput,
                    isSubmittingAnnotationEdit: viewModel.isSubmittingAnnotationEdit,
                    onStartEditingAnnotation: { index in
                        viewModel.startEditingAnnotation(at: index)
                    },
                    onSubmitAnnotationEdit: {
                        viewModel.submitAnnotationEdit()
                    },
                    onCancelAnnotationEdit: {
                        viewModel.cancelEditingAnnotation()
                    }
                )
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
                .padding(.bottom, BottomHintBar.height + DesignTokens.Spacing.extraExtraLarge)
                .allowsHitTesting(false)
                .zIndex(2)
        }
        .overlay(alignment: .bottom) {
            BottomHintBar(leftHints: viewModel.hintModel.left, rightHints: viewModel.hintModel.right)
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
            // Only handle keys in detail mode when command palette is closed and not adding annotation
            guard viewModel.mode == .detail,
                  !viewModel.commandPalette.isPresented,
                  !viewModel.isAddingAnnotation else { return event }
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
    viewModel.mode = .detail

    return ContentView(viewModel: viewModel)
        .frame(width: 680, height: 440)
}
