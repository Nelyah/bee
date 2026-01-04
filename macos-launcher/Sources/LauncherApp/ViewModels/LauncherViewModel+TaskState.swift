import Foundation

// MARK: - Task State Actions

@MainActor
extension LauncherViewModel {
    func handleTaskStateChange(_ action: TaskStateAction, taskUUID: String) {
        closeCommandPalette()
        Task {
            await performTaskStateChange(action, taskUUID: taskUUID)
        }
    }

    private func performTaskStateChange(_ action: TaskStateAction, taskUUID: String) async {
        // Build filter for this specific task (typetag format)
        let filter: JSONValue = .object([
            "type": .string("UuidFilter"),
            "value": .object(["uuid": .string(taskUUID)]),
        ])

        do {
            _ = try await apiClient.runAction(
                action: action.apiAction,
                properties: nil,
                filter: filter
            )
            showToast(message: action.successMessage, icon: .success)

            // For delete/complete, remove the task from the local list and clear selection
            if action == .delete || action == .complete {
                tasks.removeAll { $0.uuid == taskUUID }
                selectedIndex = nil
                // Clear detail view if showing this task
                if taskDetailState.taskUUID == taskUUID {
                    taskDetailState = TaskDetailState()
                }
            } else {
                // For status changes (start/stop), update the task in the list
                if let idx = tasks.firstIndex(where: { $0.uuid == taskUUID }) {
                    let task = tasks[idx]
                    let newStatus = action == .start ? "active" : "pending"
                    tasks[idx] = ApiTask(
                        dbId: task.dbId,
                        uuid: task.uuid,
                        status: newStatus,
                        summary: task.summary,
                        project: task.project,
                        tags: task.tags,
                        dateCreated: task.dateCreated,
                        dateCompleted: task.dateCompleted,
                        dateDue: task.dateDue,
                        urgency: task.urgency
                    )
                    // Refresh detail view if showing this task
                    if taskDetailState.taskUUID == taskUUID {
                        loadTaskDetail(taskUUID: taskUUID)
                    }
                }
            }
        } catch {
            showToast(message: "Failed: \(error.localizedDescription)", icon: .warning)
        }
    }
}

// MARK: - TaskStateAction Enum

enum TaskStateAction: String {
    case complete
    case delete
    case start
    case stop

    var apiAction: String {
        switch self {
        case .complete: "done"
        case .delete: "delete"
        case .start: "start"
        case .stop: "stop"
        }
    }

    var successMessage: String {
        switch self {
        case .complete: "Task marked complete"
        case .delete: "Task deleted"
        case .start: "Task started"
        case .stop: "Task set to pending"
        }
    }
}
