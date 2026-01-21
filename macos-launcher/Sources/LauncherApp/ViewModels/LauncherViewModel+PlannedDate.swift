import Foundation

/// Extension for planned date editing functionality.
extension LauncherViewModel {
    // MARK: - Planned Date Editing Methods

    /// Begin editing the planned date field.
    ///
    /// Initializes the date picker with the current planned date, or a sensible default
    /// (next hour, rounded) if no planned date is set.
    func startEditingPlannedDate() {
        guard let task = selectedTask else { return }

        // Initialize date picker with current planned date or default
        if let plannedDateString = task.datePlanned,
           let existingDate = RelativeDateFormatter.date(from: plannedDateString) {
            plannedDateEditSelection = existingDate
        } else {
            // Default to next hour, rounded
            let calendar = Calendar.current
            let now = Date()
            var components = calendar.dateComponents([.year, .month, .day, .hour], from: now)
            components.hour = (components.hour ?? 0) + 1
            components.minute = 0
            components.second = 0
            plannedDateEditSelection = calendar.date(from: components) ?? now
        }

        detailEditingState = .editingPlannedDate
    }

    /// Cancel editing the planned date.
    func cancelEditingPlannedDate() {
        detailEditingState = .none
    }

    /// Submit the edited planned date to the backend.
    func submitPlannedDateEdit() {
        guard let task = selectedTask else { return }

        isSubmittingPlannedDate = true

        Task {
            defer {
                Task { @MainActor in
                    self.isSubmittingPlannedDate = false
                }
            }

            do {
                // Format date as ISO8601 string
                let isoFormatter = ISO8601DateFormatter()
                isoFormatter.formatOptions = [.withInternetDateTime]
                let dateString = isoFormatter.string(from: plannedDateEditSelection)

                let properties: JSONValue = .object(["date_planned": .string(dateString)])
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
                    showToast(message: "Planned date updated", icon: .success)

                    // Update the local task
                    updateLocalTaskPlannedDate(task: task, newPlannedDate: dateString)

                    // Refresh the detail view
                    loadTaskDetail(taskUUID: task.uuid)
                }
            } catch {
                _ = await MainActor.run {
                    showToast(message: "Failed to update planned date", icon: .warning)
                }
            }
        }
    }

    /// Clear the planned date (set to nil).
    func clearPlannedDate() {
        guard let task = selectedTask else { return }

        isSubmittingPlannedDate = true

        Task {
            defer {
                Task { @MainActor in
                    self.isSubmittingPlannedDate = false
                }
            }

            do {
                let properties: JSONValue = .object(["date_planned": .null])
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
                    showToast(message: "Planned date cleared", icon: .success)

                    // Update the local task
                    updateLocalTaskPlannedDate(task: task, newPlannedDate: nil)

                    // Refresh the detail view
                    loadTaskDetail(taskUUID: task.uuid)
                }
            } catch {
                _ = await MainActor.run {
                    showToast(message: "Failed to clear planned date", icon: .warning)
                }
            }
        }
    }

    /// Apply a quick date action to the current planned date selection.
    ///
    /// This updates `plannedDateEditSelection` to the calculated date for the action.
    /// The user still needs to submit or the popover handles auto-submit.
    func applyQuickPlannedDateAction(_ action: QuickDueDateAction) {
        plannedDateEditSelection = action.date()
    }

    /// Update a task's planned date in the local tasks array.
    func updateLocalTaskPlannedDate(task: ApiTask, newPlannedDate: String?) {
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
                dateDue: task.dateDue,
                datePlanned: newPlannedDate,
                urgency: task.urgency
            )
        }
    }
}
