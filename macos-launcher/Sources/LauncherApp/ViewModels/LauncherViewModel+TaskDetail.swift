import Foundation

// MARK: - Task Detail Methods

extension LauncherViewModel {
    /// Return the currently selected task.
    var selectedTask: ApiTask? {
        TaskListCoordinator.selectedTask(tasks: tasks, selectedIndex: selectedIndex)
    }

    /// Open the detail view for the currently selected task.
    func openDetail() {
        if let newMode = NavigationCoordinator.modeForOpenDetail(selectedIndex: selectedIndex) {
            mode = newMode
            if let task = selectedTask {
                loadTaskDetail(taskUUID: task.uuid)
                loadExternalLinks(taskUUID: task.uuid)
            }
        }
    }

    /// Close the detail view and return to the list.
    func closeDetail() {
        mode = NavigationCoordinator.modeForCloseDetail()
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
}
