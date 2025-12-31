import Foundation

// MARK: - Task Expansion Methods

extension LauncherViewModel {
    /// Toggle expansion for a task. If expanding and data not loaded, triggers load.
    func toggleTaskExpansion(_ taskUUID: String) {
        if expandedTasks.contains(taskUUID) {
            expandedTasks.remove(taskUUID)
        } else {
            expandedTasks.insert(taskUUID)
            // Load data if not already loaded
            if taskExpandedData[taskUUID] == nil {
                loadExpandedContent(for: taskUUID)
            }
        }
    }

    /// Check if a task is expanded.
    func isTaskExpanded(_ taskUUID: String) -> Bool {
        expandedTasks.contains(taskUUID)
    }

    /// Toggle expansion for the currently selected or hovered task. Returns true if toggled.
    func toggleSelectedOrHoveredTaskExpansion() -> Bool {
        let rows = groupedRows
        let idx = selectedRowIndex ?? hoveredRowIndex
        guard let idx,
              idx < rows.count,
              case let .task(item) = rows[idx]
        else {
            return false
        }
        toggleTaskExpansion(item.task.uuid)
        return true
    }

    /// Check if the currently selected or hovered row is an expandable task.
    func canToggleSelectedOrHoveredTaskExpansion() -> Bool {
        let rows = groupedRows
        let idx = selectedRowIndex ?? hoveredRowIndex
        guard let idx, idx < rows.count else { return false }
        if case .task = rows[idx] {
            return true
        }
        return false
    }

    /// Load expanded content (links + annotations) for a task.
    func loadExpandedContent(for taskUUID: String) {
        // Mark as loading with timestamp for delayed indicator
        taskExpandedData[taskUUID] = TaskExpandedContent(isLoading: true, loadingStartedAt: Date())

        Task {
            do {
                // Load both detail (for annotations) and external links in parallel
                async let detailTask = apiClient.fetchTaskDetail(taskUUID: taskUUID)
                async let linksTask = apiClient.fetchExternalLinks(taskUUID: taskUUID)

                let detail = try await detailTask
                let links = try await linksTask

                taskExpandedData[taskUUID] = TaskExpandedContent(
                    isLoading: false,
                    links: links,
                    annotations: detail.annotations,
                    errorMessage: nil
                )
            } catch {
                taskExpandedData[taskUUID] = TaskExpandedContent(
                    isLoading: false,
                    links: [],
                    annotations: [],
                    errorMessage: error.localizedDescription
                )
            }
        }
    }
}
