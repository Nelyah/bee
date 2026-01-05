import Foundation

// MARK: - Multi-Select Operations

extension LauncherViewModel {
    /// Toggle multi-selection for the task at current cursor position,
    /// then move cursor down to the next task.
    /// Returns true if toggled (i.e., was on a task row, not header).
    func toggleMultiSelectAtCursor() -> Bool {
        guard let rowIndex = selectedRowIndex,
              rowIndex < groupedRows.count,
              case let .task(groupedTask) = groupedRows[rowIndex] else {
            return false
        }
        toggleMultiSelect(uuid: groupedTask.task.uuid)
        // Move to next task for rapid multi-selection
        moveSelection(delta: 1)
        return true
    }

    /// Toggle selection state for a specific task UUID.
    func toggleMultiSelect(uuid: String) {
        if selectedTaskUUIDs.contains(uuid) {
            selectedTaskUUIDs.remove(uuid)
        } else {
            selectedTaskUUIDs.insert(uuid)
        }
    }

    /// Clear all multi-selections.
    func clearMultiSelection() {
        selectedTaskUUIDs.removeAll()
    }

    /// Check if a task is multi-selected.
    func isMultiSelected(uuid: String) -> Bool {
        selectedTaskUUIDs.contains(uuid)
    }
}
