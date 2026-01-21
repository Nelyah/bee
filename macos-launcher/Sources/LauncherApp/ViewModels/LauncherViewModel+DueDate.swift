import Foundation

/// Extension for due date editing functionality.
extension LauncherViewModel {
    // MARK: - Due Date Editing Methods

    /// Begin editing the due date field.
    ///
    /// Initializes the date picker with the current due date, or a sensible default
    /// (next hour, rounded) if no due date is set.
    func startEditingDueDate() {
        guard let task = selectedTask else { return }

        // Initialize date picker with current due date or default
        if let dueDateString = task.dateDue,
           let existingDate = RelativeDateFormatter.date(from: dueDateString) {
            dueDateEditSelection = existingDate
        } else {
            // Default to next hour, rounded
            let calendar = Calendar.current
            let now = Date()
            var components = calendar.dateComponents([.year, .month, .day, .hour], from: now)
            components.hour = (components.hour ?? 0) + 1
            components.minute = 0
            components.second = 0
            dueDateEditSelection = calendar.date(from: components) ?? now
        }

        detailEditingState = .editingDueDate
    }

    /// Cancel editing the due date.
    func cancelEditingDueDate() {
        detailEditingState = .none
    }

    /// Submit the edited due date to the backend.
    func submitDueDateEdit() {
        guard let task = selectedTask else { return }

        isSubmittingDueDate = true

        Task {
            defer {
                Task { @MainActor in
                    self.isSubmittingDueDate = false
                }
            }

            do {
                // Format date as ISO8601 string
                let isoFormatter = ISO8601DateFormatter()
                isoFormatter.formatOptions = [.withInternetDateTime]
                let dateString = isoFormatter.string(from: dueDateEditSelection)

                let properties: JSONValue = .object(["date_due": .string(dateString)])
                let filter: JSONValue = .object([
                    "type": .string("UuidFilter"),
                    "value": .object(["uuid": .string(task.uuid)]),
                ])

                _ = try await apiClient.runAction(
                    action: "modify",
                    properties: properties,
                    filter: filter
                )

                await MainActor.run {
                    detailEditingState = .none
                    showToast(message: "Due date updated", icon: .success)

                    // Update the local task
                    updateLocalTaskDueDate(task: task, newDueDate: dateString)

                    // Refresh the detail view
                    loadTaskDetail(taskUUID: task.uuid)
                }
            } catch {
                _ = await MainActor.run {
                    showToast(message: "Failed to update due date", icon: .warning)
                }
            }
        }
    }

    /// Clear the due date (set to nil).
    func clearDueDate() {
        guard let task = selectedTask else { return }

        isSubmittingDueDate = true

        Task {
            defer {
                Task { @MainActor in
                    self.isSubmittingDueDate = false
                }
            }

            do {
                let properties: JSONValue = .object(["date_due": .null])
                let filter: JSONValue = .object([
                    "type": .string("UuidFilter"),
                    "value": .object(["uuid": .string(task.uuid)]),
                ])

                _ = try await apiClient.runAction(
                    action: "modify",
                    properties: properties,
                    filter: filter
                )

                await MainActor.run {
                    detailEditingState = .none
                    showToast(message: "Due date cleared", icon: .success)

                    // Update the local task
                    updateLocalTaskDueDate(task: task, newDueDate: nil)

                    // Refresh the detail view
                    loadTaskDetail(taskUUID: task.uuid)
                }
            } catch {
                _ = await MainActor.run {
                    showToast(message: "Failed to clear due date", icon: .warning)
                }
            }
        }
    }

    /// Apply a quick date action to the current selection.
    ///
    /// This updates `dueDateEditSelection` to the calculated date for the action.
    /// The user still needs to submit or the popover handles auto-submit.
    func applyQuickDueDateAction(_ action: QuickDueDateAction) {
        dueDateEditSelection = action.date()
    }

    /// Update a task's due date in the local tasks array.
    func updateLocalTaskDueDate(task: ApiTask, newDueDate: String?) {
        if let idx = tasks.firstIndex(where: { $0.uuid == task.uuid }) {
            tasks[idx] = ApiTask(
                dbId: task.dbId,
                uuid: task.uuid,
                status: task.status,
                summary: task.summary,
                project: task.project,
                tags: task.tags,
                dateCreated: task.dateCreated,
                dateCompleted: task.dateCompleted,
                dateDue: newDueDate,
                datePlanned: task.datePlanned,
                urgency: task.urgency
            )
        }
    }
}
