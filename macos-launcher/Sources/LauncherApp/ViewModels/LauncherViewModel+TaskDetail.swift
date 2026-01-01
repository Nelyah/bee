import AppKit
import Foundation

// MARK: - Task Detail Methods

extension LauncherViewModel {
    /// Return the currently selected task.
    var selectedTask: ApiTask? {
        TaskListCoordinator.selectedTask(tasks: tasks, selectedIndex: selectedIndex)
    }

    /// Open the detail view for the currently selected task.
    func openDetail() {
        guard selectedIndex != nil else { return }
        mode = .detail
        detailFocusedIndex = 0
        detailKeyboardNavigationActive = false
        buildDetailFocusableItems()
        if let task = selectedTask {
            loadTaskDetail(taskUUID: task.uuid)
            loadExternalLinks(taskUUID: task.uuid)
        }
    }

    /// Close the detail view and return to the list.
    func closeDetail() {
        mode = .list
        detailKeyboardNavigationActive = false
        taskDetailState = TaskDetailState()
        externalLinksState = ExternalLinksState()
    }

    func loadTaskDetail(taskUUID: String) {
        if taskDetailState.isLoading, taskDetailState.detail?.uuid == taskUUID {
            return
        }
        let currentDetail = taskDetailState.detail?.uuid == taskUUID ? taskDetailState.detail : nil
        taskDetailState = TaskDetailState(
            isLoading: true,
            taskUUID: taskUUID,
            detail: currentDetail,
            errorMessage: nil
        )
        Task {
            do {
                let detail = try await apiClient.fetchTaskDetail(taskUUID: taskUUID)
                taskDetailState = TaskDetailState(
                    isLoading: false,
                    taskUUID: taskUUID,
                    detail: detail,
                    errorMessage: nil
                )
            } catch {
                taskDetailState = TaskDetailState(
                    isLoading: false,
                    taskUUID: taskUUID,
                    detail: nil,
                    errorMessage: error.localizedDescription
                )
            }
        }
    }

    func loadExternalLinks(taskUUID: String) {
        if externalLinksState.isLoading, externalLinksState.taskUUID == taskUUID {
            return
        }
        externalLinksState = ExternalLinksState(isLoading: true, taskUUID: taskUUID)
        Task {
            do {
                let links = try await apiClient.fetchExternalLinks(taskUUID: taskUUID)
                externalLinksState = ExternalLinksState(
                    isLoading: false,
                    taskUUID: taskUUID,
                    links: links,
                    errorMessage: nil,
                    refreshingProviders: []
                )
                buildDetailFocusableItems()
            } catch {
                externalLinksState = ExternalLinksState(
                    isLoading: false,
                    taskUUID: taskUUID,
                    links: [],
                    errorMessage: error.localizedDescription,
                    refreshingProviders: []
                )
            }
        }
    }

    func refreshExternalLinks(provider: ExternalLinkProvider) {
        guard let task = selectedTask else { return }
        if externalLinksState.taskUUID != task.uuid {
            loadExternalLinks(taskUUID: task.uuid)
            return
        }
        let linksToSync = externalLinksState.links.filter { $0.provider.lowercased() == provider.rawValue }
        guard !linksToSync.isEmpty else { return }

        externalLinksState.refreshingProviders.insert(provider)
        Task {
            defer {
                externalLinksState.refreshingProviders.remove(provider)
            }
            do {
                for link in linksToSync {
                    _ = try await apiClient.syncExternalLink(linkId: link.id, force: true)
                }
                loadExternalLinks(taskUUID: task.uuid)
            } catch {
                externalLinksState.errorMessage = error.localizedDescription
            }
        }
    }

    /// Keep selection within bounds after tasks update.
    func syncSelectionAfterTasksUpdate() {
        selectedIndex = TaskListCoordinator.syncSelection(tasks: tasks, selectedIndex: selectedIndex)
        if let selectedIndex {
            let rows = groupedRows
            let rowIndex = rows.firstIndex { row in
                if case let .task(item) = row {
                    return item.flatIndex == selectedIndex
                }
                return false
            }
            updateSelection(rowIndex: rowIndex, rows: rows)
        } else {
            updateSelection(rowIndex: nil)
        }
    }

    /// Sort tasks by urgency, highest first, keeping nil urgency last.
    func sortTasksByUrgency(_ items: [ApiTask]) -> [ApiTask] {
        TaskListCoordinator.sortTasksByUrgency(items)
    }

    // MARK: - Detail Focus Navigation

    /// Builds the list of focusable items for the current detail view.
    func buildDetailFocusableItems() {
        var items: [DetailFocusableItem] = []

        // 1. UUID is always first (if we have a task)
        if let task = selectedTask {
            items.append(.uuid(task.uuid))
        }

        // 2. GitLab MRs
        let gitlabLinks = externalLinksState.links.filter {
            $0.provider.lowercased() == ExternalLinkProvider.gitlab.rawValue
        }
        for link in gitlabLinks {
            items.append(.gitlabMR(link))
        }

        // 3. Jira issues
        let jiraLinks = externalLinksState.links.filter {
            $0.provider.lowercased() == ExternalLinkProvider.jira.rawValue
        }
        for link in jiraLinks {
            items.append(.jiraIssue(link))
        }

        detailFocusableItems = items

        // Keep focus within bounds
        if detailFocusedIndex >= items.count {
            detailFocusedIndex = max(0, items.count - 1)
        }
    }

    /// The currently focused item in detail view.
    /// Returns nil if keyboard navigation is not active (focus ring is lazy).
    var focusedDetailItem: DetailFocusableItem? {
        // Focus ring only shows after user engages with hjkl navigation
        guard detailKeyboardNavigationActive else {
            return nil
        }
        guard detailFocusedIndex >= 0, detailFocusedIndex < detailFocusableItems.count else {
            return nil
        }
        return detailFocusableItems[detailFocusedIndex]
    }

    /// Handle a detail mode keyboard action.
    @discardableResult
    func handleDetailModeAction(_ action: DetailModeAction) -> Bool {
        // Activate keyboard navigation on any navigation action
        switch action {
        case .moveFocus, .moveFocusLeft, .moveFocusRight, .selectFirst, .selectLast:
            detailKeyboardNavigationActive = true
        default:
            break
        }

        switch action {
        case let .moveFocus(delta):
            moveDetailFocus(delta: delta)
            return true
        case .moveFocusLeft:
            // Move to left column (UUID at index 0)
            if detailFocusedIndex > 0 {
                detailFocusedIndex = 0
            }
            return true
        case .moveFocusRight:
            // Move to right column (links), or open if already there
            if detailFocusedIndex == 0, detailFocusableItems.count > 1 {
                detailFocusedIndex = 1
                return true
            }
            // Already in right column - open the focused item
            return openFocusedDetailItem()
        case .openFocused:
            return openFocusedDetailItem()
        case .copyFocused:
            return copyFocusedDetailItem()
        case .selectFirst:
            detailFocusedIndex = 0
            return true
        case .selectLast:
            detailFocusedIndex = max(0, detailFocusableItems.count - 1)
            return true
        case .addAnnotation:
            startAddingAnnotation()
            return true
        }
    }

    private func moveDetailFocus(delta: Int) {
        guard !detailFocusableItems.isEmpty else { return }
        let newIndex = detailFocusedIndex + delta
        detailFocusedIndex = max(0, min(newIndex, detailFocusableItems.count - 1))
    }

    private func openFocusedDetailItem() -> Bool {
        guard let item = focusedDetailItem,
              let url = item.openURL
        else {
            return false
        }

        NSWorkspace.shared.open(url)
        return true
    }

    private func copyFocusedDetailItem() -> Bool {
        guard let item = focusedDetailItem else { return false }

        let value = item.copyValue
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)

        // Show toast with appropriate label
        showToast(message: "\(item.copyLabel) copied", icon: .success)
        return true
    }

    // MARK: - Annotation Methods

    /// Begin adding an annotation (shows the input field).
    func startAddingAnnotation() {
        guard selectedTask != nil else { return }
        isAddingAnnotation = true
        annotationInput = ""
    }

    /// Cancel adding an annotation (hides the input field).
    func cancelAddingAnnotation() {
        isAddingAnnotation = false
        annotationInput = ""
    }

    /// Submit the current annotation text.
    func submitAnnotation() {
        guard let task = selectedTask else { return }
        let text = annotationInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            cancelAddingAnnotation()
            return
        }

        isSubmittingAnnotation = true

        Task {
            defer {
                isSubmittingAnnotation = false
            }

            do {
                // Build properties with annotation text
                // Note: The field name must match TaskProperties.annotation in Rust
                let properties: JSONValue = .object(["annotation": .string(text)])
                // Build filter for this specific task
                // Note: Rust uses typetag::serde which requires a "type" discriminator
                let filter: JSONValue = .object([
                    "type": .string("UuidFilter"),
                    "uuid": .string(task.uuid),
                ])

                _ = try await apiClient.runAction(
                    action: "annotate",
                    properties: properties,
                    filter: filter
                )

                // Success - clear input and reload detail
                isAddingAnnotation = false
                annotationInput = ""
                showToast(message: "Annotation added", icon: .success)

                // Refresh the detail to show the new annotation
                loadTaskDetail(taskUUID: task.uuid)
            } catch {
                showToast(message: "Failed to add annotation", icon: .warning)
            }
        }
    }
}
