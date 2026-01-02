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
                // Rust uses #[typetag::serde(tag = "type", content = "value")] which requires
                // the filter content to be wrapped in a "value" field
                let filter: JSONValue = .object([
                    "type": .string("UuidFilter"),
                    "value": .object(["uuid": .string(task.uuid)]),
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

    // MARK: - Task Name Editing Methods

    /// Begin editing the task name.
    func startEditingTaskName() {
        guard let task = selectedTask else { return }
        taskNameEditInput = task.summary
        isEditingTaskName = true
    }

    /// Cancel editing the task name.
    func cancelEditingTaskName() {
        isEditingTaskName = false
        taskNameEditInput = ""
    }

    /// Submit the edited task name.
    func submitTaskNameEdit() {
        guard let task = selectedTask else { return }
        let newSummary = taskNameEditInput.trimmingCharacters(in: .whitespacesAndNewlines)

        // If empty or unchanged, just cancel
        guard !newSummary.isEmpty, newSummary != task.summary else {
            cancelEditingTaskName()
            return
        }

        isSubmittingTaskName = true

        Task {
            defer {
                isSubmittingTaskName = false
            }

            do {
                let properties: JSONValue = .object(["summary": .string(newSummary)])
                let filter: JSONValue = .object([
                    "type": .string("UuidFilter"),
                    "value": .object(["uuid": .string(task.uuid)]),
                ])

                _ = try await apiClient.runAction(
                    action: "modify",
                    properties: properties,
                    filter: filter
                )

                // Success - clear state and reload
                isEditingTaskName = false
                taskNameEditInput = ""
                showToast(message: "Task name updated", icon: .success)

                // Update the task in the local list
                if let idx = tasks.firstIndex(where: { $0.uuid == task.uuid }) {
                    tasks[idx] = ApiTask(
                        dbId: task.dbId,
                        uuid: task.uuid,
                        status: task.status,
                        summary: newSummary,
                        project: task.project,
                        tags: task.tags,
                        dateCreated: task.dateCreated,
                        dateCompleted: task.dateCompleted,
                        dateDue: task.dateDue,
                        urgency: task.urgency
                    )
                }

                // Refresh the detail view
                loadTaskDetail(taskUUID: task.uuid)
            } catch {
                showToast(message: "Failed to update task name", icon: .warning)
            }
        }
    }

    // MARK: - Annotation Editing Methods

    /// Begin editing an existing annotation by its ID.
    ///
    /// Using ID instead of index avoids mismatch when annotations are sorted for display.
    /// The annotation ID is computed as "time-value".
    func startEditingAnnotation(withId id: String) {
        guard let detail = taskDetailState.detail,
              let annotation = detail.annotations.first(where: { $0.id == id })
        else { return }

        annotationEditInput = annotation.value
        editingAnnotationId = id
    }

    /// Cancel editing an annotation.
    func cancelEditingAnnotation() {
        editingAnnotationId = nil
        annotationEditInput = ""
    }

    /// Submit the edited annotation.
    func submitAnnotationEdit() {
        guard let task = selectedTask,
              let detail = taskDetailState.detail,
              let editId = editingAnnotationId,
              let annotation = detail.annotations.first(where: { $0.id == editId })
        else {
            cancelEditingAnnotation()
            return
        }

        let newValue = annotationEditInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let originalValue = annotation.value

        // If empty, treat as delete
        if newValue.isEmpty {
            deleteAnnotation(withId: editId)
            return
        }

        // If unchanged, just cancel
        guard newValue != originalValue else {
            cancelEditingAnnotation()
            return
        }

        isSubmittingAnnotationEdit = true

        Task {
            defer {
                isSubmittingAnnotationEdit = false
            }

            do {
                // Build the updated annotations array
                var updatedAnnotations: [[String: JSONValue]] = []
                for ann in detail.annotations {
                    let value = ann.id == editId ? newValue : ann.value
                    updatedAnnotations.append([
                        "value": .string(value),
                        "time": .string(ann.time),
                    ])
                }

                let properties: JSONValue = .object([
                    "annotations": .array(updatedAnnotations.map { .object($0) }),
                ])
                let filter: JSONValue = .object([
                    "type": .string("UuidFilter"),
                    "value": .object(["uuid": .string(task.uuid)]),
                ])

                _ = try await apiClient.runAction(
                    action: "modify",
                    properties: properties,
                    filter: filter
                )

                // Success
                editingAnnotationId = nil
                annotationEditInput = ""
                showToast(message: "Annotation updated", icon: .success)

                loadTaskDetail(taskUUID: task.uuid)
            } catch {
                showToast(message: "Failed to update annotation", icon: .warning)
            }
        }
    }

    /// Delete an annotation by its ID.
    func deleteAnnotation(withId id: String) {
        guard let task = selectedTask,
              let detail = taskDetailState.detail,
              detail.annotations.contains(where: { $0.id == id })
        else { return }

        // Clear edit state if we're deleting the one being edited
        if editingAnnotationId == id {
            editingAnnotationId = nil
            annotationEditInput = ""
        }

        isSubmittingAnnotationEdit = true

        Task {
            defer {
                isSubmittingAnnotationEdit = false
            }

            do {
                // Build annotations array without the deleted one
                var updatedAnnotations: [[String: JSONValue]] = []
                for ann in detail.annotations where ann.id != id {
                    updatedAnnotations.append([
                        "value": .string(ann.value),
                        "time": .string(ann.time),
                    ])
                }

                let properties: JSONValue = .object([
                    "annotations": .array(updatedAnnotations.map { .object($0) }),
                ])
                let filter: JSONValue = .object([
                    "type": .string("UuidFilter"),
                    "value": .object(["uuid": .string(task.uuid)]),
                ])

                _ = try await apiClient.runAction(
                    action: "modify",
                    properties: properties,
                    filter: filter
                )

                showToast(message: "Annotation deleted", icon: .success)
                loadTaskDetail(taskUUID: task.uuid)
            } catch {
                showToast(message: "Failed to delete annotation", icon: .warning)
            }
        }
    }
}
