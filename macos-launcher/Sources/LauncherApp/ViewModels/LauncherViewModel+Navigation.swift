import Foundation

// MARK: - Navigation Stack Methods

extension LauncherViewModel {
    /// Whether back navigation is possible (more than just root in stack)
    var canNavigateBack: Bool {
        navigationStack.canGoBack
    }

    /// Navigate back to the previous view in the navigation stack.
    /// - Returns: true if navigation occurred, false if already at root
    @discardableResult
    func navigateBack() -> Bool {
        guard let popped = navigationStack.pop() else {
            return false
        }

        let destination = navigationStack.current

        switch destination {
        case .taskList:
            // Returning to list - restore selection from the popped entry
            if case let .taskDetail(_, previousIndex) = popped {
                selectedIndex = previousIndex
            }
            navigationRegistry.deactivateNavigation()
            taskDetailState = TaskDetailState()
            externalLinksState = ExternalLinksState()

        case let .taskDetail(uuid, _):
            // Returning to a previous task detail
            restoreTaskDetail(uuid: uuid)

        case .projectOverview:
            // Returning to project overview - just update mode (via stack sync)
            break
        }

        return true
    }

    /// Push a task detail onto the navigation stack and load it.
    /// - Parameter uuid: The UUID of the task to navigate to
    func pushTaskDetail(uuid: String) {
        // Capture current selectedIndex before changing it
        let entry = NavigationEntry.taskDetail(
            uuid: uuid,
            previousSelectedIndex: selectedIndex
        )
        navigationStack.push(entry)

        // Load the task
        loadTaskForNavigation(uuid: uuid)
    }

    /// Push project overview onto the navigation stack.
    func pushProjectOverview() {
        navigationStack.push(.projectOverview)
        Task {
            await loadProjectOverview()
        }
    }

    /// Navigate to root (task list), clearing all history.
    func navigateToRoot() {
        navigationStack.reset()
        navigationRegistry.deactivateNavigation()
        taskDetailState = TaskDetailState()
        externalLinksState = ExternalLinksState()
    }

    // MARK: - Private Helpers

    /// Load task detail data for navigation (used by pushTaskDetail)
    private func loadTaskForNavigation(uuid: String) {
        // Find task index
        if let index = tasks.firstIndex(where: { $0.uuid == uuid }) {
            selectedIndex = index
        }

        loadTaskDetail(taskUUID: uuid)
        loadExternalLinks(taskUUID: uuid)
        navigationRegistry.clearAll()
        buildDetailFocusableItems()
    }

    /// Restore a task detail view when navigating back.
    /// If the task is no longer available, recursively navigate back.
    private func restoreTaskDetail(uuid: String) {
        guard let index = tasks.firstIndex(where: { $0.uuid == uuid }) else {
            // Task no longer in current view - show message and continue popping
            showToast(message: "Task no longer visible", icon: .warning)
            navigationStack.removeEntriesForTask(uuid: uuid)

            // Navigate to whatever is now current
            if case let .taskDetail(nextUuid, _) = navigationStack.current {
                restoreTaskDetail(uuid: nextUuid)
            }
            return
        }

        selectedIndex = index
        loadTaskDetail(taskUUID: uuid)
        loadExternalLinks(taskUUID: uuid)
        navigationRegistry.clearAll()
        buildDetailFocusableItems()
    }

    // MARK: - Test Helpers

    #if DEBUG
        /// Set mode directly for testing purposes.
        /// This bypasses the navigation stack and should only be used in tests.
        func setModeForTesting(_ newMode: LauncherMode) {
            switch newMode {
            case .list:
                navigationStack.reset()
            case .detail:
                // For detail mode, we need a task UUID.
                // If no task is selected but tasks exist, auto-select the first one.
                if selectedIndex == nil, !tasks.isEmpty {
                    selectedIndex = 0
                }
                if let task = selectedTask {
                    navigationStack.push(.taskDetail(uuid: task.uuid, previousSelectedIndex: selectedIndex))
                } else {
                    // For tests that need detail mode without a real task, push a dummy entry
                    navigationStack.push(.taskDetail(uuid: "test-dummy-uuid", previousSelectedIndex: nil))
                }
            case .projectOverview:
                navigationStack.push(.projectOverview)
            }
        }
    #endif
}
