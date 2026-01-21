import AppKit
import Foundation

// MARK: - Task Detail Methods

extension LauncherViewModel {
    /// Return the currently selected task.
    var selectedTask: ApiTask? {
        TaskListCoordinator.selectedTask(tasks: tasks, selectedIndex: selectedIndex)
    }

    /// Open the detail view for the currently selected task.
    /// Pushes the task detail onto the navigation stack.
    func openDetail() {
        guard let task = selectedTask else { return }
        pushTaskDetail(uuid: task.uuid)
    }

    /// Close the detail view and return to the previous view.
    /// Delegates to navigateBack() to pop from the navigation stack.
    public func closeDetail() {
        _ = navigateBack()
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
                // Rebuild focusable items now that attachments are loaded
                buildDetailFocusableItems()
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

    // MARK: - Annotation Methods

    /// Begin adding an annotation (shows the input field).
    func startAddingAnnotation() {
        guard selectedTask != nil else { return }
        annotationInput = ""
        detailEditingState = .addingAnnotation
    }

    /// Cancel adding an annotation (hides the input field).
    func cancelAddingAnnotation() {
        annotationInput = ""
        detailEditingState = .none
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
                annotationInput = ""
                detailEditingState = .none
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
        detailEditingState = .editingTaskName
    }

    /// Cancel editing the task name.
    func cancelEditingTaskName() {
        taskNameEditInput = ""
        detailEditingState = .none
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
                taskNameEditInput = ""
                detailEditingState = .none
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
                        datePlanned: task.datePlanned,
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

    // MARK: - Project Editing Methods

    /// Begin editing the project field.
    func startEditingProject() {
        guard let task = selectedTask else { return }
        projectEditInput = task.project ?? ""
        detailEditingState = .editingProject
    }

    /// Cancel editing the project.
    func cancelEditingProject() {
        projectEditInput = ""
        detailEditingState = .none
    }

    /// All available projects for autocomplete.
    /// Filtering is handled by CompletionField's internal FuzzyMatcher.
    var filteredProjects: [CompletionItem] {
        var items = completion.projectItems.filter { !$0.value.isEmpty }

        // Deduplicate by value while preserving order.
        var seen = Set<String>()
        items = items.filter { seen.insert($0.value).inserted }

        return items
    }

    private func isCurrentProjectCompletion(_ item: CompletionItem) -> Bool {
        guard let current = selectedTask?.project, !current.isEmpty else { return false }
        return item.value == current
    }

    /// Submit the edited project (from typed input).
    func submitProjectEdit() {
        guard let task = selectedTask else { return }

        let newProject = projectEditInput.trimmingCharacters(in: .whitespacesAndNewlines)

        // If unchanged, just cancel
        let currentProject = task.project ?? ""
        guard newProject != currentProject else {
            cancelEditingProject()
            return
        }

        isSubmittingProject = true

        Task {
            defer {
                isSubmittingProject = false
            }

            do {
                // Use null if clearing the project
                let projectValue: JSONValue = newProject.isEmpty ? .null : .string(newProject)
                let properties: JSONValue = .object(["project": projectValue])
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
                projectEditInput = ""
                detailEditingState = .none
                showToast(message: newProject.isEmpty ? "Project cleared" : "Project updated", icon: .success)

                // Update the task in the local list
                if let idx = tasks.firstIndex(where: { $0.uuid == task.uuid }) {
                    tasks[idx] = ApiTask(
                        dbId: task.dbId,
                        uuid: task.uuid,
                        status: task.status,
                        summary: task.summary,
                        project: newProject.isEmpty ? nil : newProject,
                        tags: task.tags,
                        dateCreated: task.dateCreated,
                        dateCompleted: task.dateCompleted,
                        dateDue: task.dateDue,
                        datePlanned: task.datePlanned,
                        urgency: task.urgency
                    )
                }

                // Rebuild focusable items since project changed
                buildDetailFocusableItems()

                // Refresh the detail view
                loadTaskDetail(taskUUID: task.uuid)
            } catch {
                showToast(message: "Failed to update project", icon: .warning)
            }
        }
    }

    /// Select a project from the autocomplete list and submit immediately.
    func selectProjectFromCompletion(_ item: CompletionItem) {
        guard !isCurrentProjectCompletion(item) else { return }

        // Use Task with @MainActor to properly defer state changes
        // and avoid "Publishing changes from within view updates"
        Task { @MainActor in
            projectEditInput = item.value
            submitProjectEdit()
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
        detailEditingState = .editingAnnotation(id: id)
    }

    /// Cancel editing an annotation.
    func cancelEditingAnnotation() {
        annotationEditInput = ""
        detailEditingState = .none
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
                annotationEditInput = ""
                detailEditingState = .none
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
        if case let .editingAnnotation(editId) = detailEditingState, editId == id {
            annotationEditInput = ""
            detailEditingState = .none
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
