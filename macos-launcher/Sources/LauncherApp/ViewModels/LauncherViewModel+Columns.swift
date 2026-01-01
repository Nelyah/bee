import Foundation

// MARK: - Column Customization Methods

extension LauncherViewModel {
    /// Toggle sort on a column. Cycle: urgency (default) → ascending → descending → urgency.
    ///
    /// When sortState is nil, the list is sorted by urgency (default).
    /// Clicking a column starts ascending sort, then descending, then back to urgency.
    func toggleSort(for column: String) {
        if let current = sortState, current.column == column {
            // Same column - cycle through: ascending → descending → urgency (nil)
            if current.direction == .ascending {
                sortState = ColumnSortState(column: column, direction: .descending)
            } else {
                // Was descending, go back to urgency
                sortState = nil
            }
        } else {
            // Different column or was nil (urgency) - start with ascending
            sortState = ColumnSortState(column: column, direction: .ascending)
        }
    }

    /// Get the current sort direction for a column, or nil if not sorted by this column.
    func sortDirection(for column: String) -> ColumnSortDirection? {
        guard let state = sortState, state.column == column else {
            return nil
        }
        return state.direction
    }

    /// Initialize column configs from the current report.
    func initializeColumnConfigs(from config: ReportConfig?) {
        guard let config else {
            // Default columns if no config
            columnConfigs = [
                ColumnConfig(key: "id", displayName: "ID", width: nil),
                ColumnConfig(key: "summary", displayName: "Summary", width: nil),
                ColumnConfig(key: "status", displayName: "Status", width: nil),
                ColumnConfig(key: "urgency", displayName: "Urgency", width: nil),
            ]
            return
        }

        // Build configs from report columns
        columnConfigs = zip(config.columns, config.columnNames).map { key, name in
            ColumnConfig(key: key, displayName: name, width: nil)
        }
    }

    // MARK: - Column Resizing

    /// Track the starting width when a resize drag begins.
    private static var resizeStartWidths: [String: CGFloat] = [:]

    /// Update a column's width during a resize drag.
    /// - Parameters:
    ///   - column: The column key being resized
    ///   - delta: The drag translation delta from the start position
    func resizeColumn(_ column: String, delta: CGFloat) {
        guard let index = columnConfigs.firstIndex(where: { $0.key == column }) else { return }

        // Store starting width on first call
        if LauncherViewModel.resizeStartWidths[column] == nil {
            LauncherViewModel.resizeStartWidths[column] = columnConfigs[index].effectiveWidth
        }

        let startWidth = LauncherViewModel.resizeStartWidths[column] ?? columnConfigs[index].effectiveWidth
        let minWidth = ColumnConfig.minimumWidth(for: column)
        let newWidth = max(minWidth, startWidth + delta)

        // Update the config with the new width
        columnConfigs[index].width = newWidth
    }

    /// Call when resize drag ends to clear stored state.
    func finishResizing(_ column: String) {
        LauncherViewModel.resizeStartWidths.removeValue(forKey: column)
    }

    // MARK: - Column Add/Remove

    /// Add a column to the end of the column list.
    func addColumn(_ definition: ColumnDefinition) {
        // Don't add if already present
        guard !columnConfigs.contains(where: { $0.key == definition.rawValue }) else { return }

        let newConfig = definition.toConfig()

        // Always add at the end
        columnConfigs.append(newConfig)

        // Close command palette after action
        commandPalette.close()
    }

    /// Remove a column from the column list.
    ///
    /// Summary column cannot be removed.
    func removeColumn(_ key: String) {
        // Prevent removing summary column
        guard key != "summary" else { return }

        columnConfigs.removeAll { $0.key == key }

        // Close command palette after action
        commandPalette.close()
    }

    // MARK: - Column Reordering

    /// Move a column to a new position.
    ///
    /// - Parameters:
    ///   - key: The key of the column to move
    ///   - targetIndex: The index to move the column to
    func reorderColumn(_ key: String, to targetIndex: Int) {
        guard let sourceIndex = columnConfigs.firstIndex(where: { $0.key == key }) else { return }
        guard targetIndex >= 0, targetIndex < columnConfigs.count else { return }
        guard sourceIndex != targetIndex else { return }

        let column = columnConfigs.remove(at: sourceIndex)

        // Adjust target index if source was before target
        let adjustedIndex = sourceIndex < targetIndex ? targetIndex - 1 : targetIndex
        columnConfigs.insert(column, at: min(adjustedIndex, columnConfigs.count))
    }

    // MARK: - Task Comparison

    /// Compare two tasks based on the current sort state.
    /// Returns true if lhs should come before rhs.
    func compareTasks(_ lhs: ApiTask, _ rhs: ApiTask) -> Bool {
        guard let state = sortState else {
            // Default: sort by urgency descending
            return compareByUrgency(lhs, rhs)
        }

        let ascending = state.direction == .ascending
        let result = compareByColumn(lhs, rhs, column: state.column)

        return ascending ? result : !result
    }

    /// Compare two tasks by urgency (higher first, nil last).
    private func compareByUrgency(_ lhs: ApiTask, _ rhs: ApiTask) -> Bool {
        switch (lhs.urgency, rhs.urgency) {
        case let (lhsUrgency?, rhsUrgency?):
            if lhsUrgency == rhsUrgency {
                return lhs.uuid < rhs.uuid
            }
            return lhsUrgency > rhsUrgency
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            return lhs.uuid < rhs.uuid
        }
    }

    /// Compare two tasks by a specific column (ascending).
    /// Uses UUID as tiebreaker for stability.
    private func compareByColumn(_ lhs: ApiTask, _ rhs: ApiTask, column: String) -> Bool {
        switch column {
        case "id":
            // Sort by database ID
            return compareOptional(lhs.dbId, rhs.dbId, tiebreaker: lhs.uuid < rhs.uuid)
        case "uuid":
            return lhs.uuid < rhs.uuid
        case "status":
            if lhs.status == rhs.status {
                return lhs.uuid < rhs.uuid
            }
            return lhs.status < rhs.status
        case "summary":
            let lhsSummary = lhs.summary.lowercased()
            let rhsSummary = rhs.summary.lowercased()
            if lhsSummary == rhsSummary {
                return lhs.uuid < rhs.uuid
            }
            return lhsSummary < rhsSummary
        case "project":
            return compareOptionalStrings(lhs.project, rhs.project, tiebreaker: lhs.uuid < rhs.uuid)
        case "tags":
            // Sort by first tag alphabetically
            let lhsTag = lhs.tags.first?.lowercased()
            let rhsTag = rhs.tags.first?.lowercased()
            return compareOptionalStrings(lhsTag, rhsTag, tiebreaker: lhs.uuid < rhs.uuid)
        case "date_created":
            // Dates are ISO strings, so string comparison works
            if lhs.dateCreated == rhs.dateCreated {
                return lhs.uuid < rhs.uuid
            }
            return lhs.dateCreated < rhs.dateCreated
        case "date_completed":
            return compareOptionalStrings(lhs.dateCompleted, rhs.dateCompleted, tiebreaker: lhs.uuid < rhs.uuid)
        case "date_due":
            return compareOptionalStrings(lhs.dateDue, rhs.dateDue, tiebreaker: lhs.uuid < rhs.uuid)
        case "urgency":
            // For explicit urgency column sort, use ascending logic
            return compareOptional(lhs.urgency, rhs.urgency, tiebreaker: lhs.uuid < rhs.uuid)
        default:
            // Unknown column - fall back to urgency
            return compareByUrgency(lhs, rhs)
        }
    }

    /// Compare optional values, with nil sorting last.
    private func compareOptional<T: Comparable>(_ lhs: T?, _ rhs: T?, tiebreaker: Bool) -> Bool {
        switch (lhs, rhs) {
        case let (l?, r?):
            if l == r {
                return tiebreaker
            }
            return l < r
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            return tiebreaker
        }
    }

    /// Compare optional strings case-insensitively, with nil sorting last.
    private func compareOptionalStrings(_ lhs: String?, _ rhs: String?, tiebreaker: Bool) -> Bool {
        switch (lhs?.lowercased(), rhs?.lowercased()) {
        case let (l?, r?):
            if l == r {
                return tiebreaker
            }
            return l < r
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            return tiebreaker
        }
    }
}
