enum TaskListCoordinator {
    static func moveSelection(tasks: [ApiTask], selectedIndex: Int?, delta: Int) -> Int? {
        guard !tasks.isEmpty else { return nil }
        let count = tasks.count
        if let current = selectedIndex {
            let next = (current + delta + count) % count
            return next
        }
        return delta >= 0 ? 0 : count - 1
    }

    static func syncSelection(tasks: [ApiTask], selectedIndex: Int?) -> Int? {
        guard let current = selectedIndex else { return nil }
        if tasks.isEmpty {
            return nil
        }
        if current >= tasks.count {
            return tasks.count - 1
        }
        return current
    }

    static func sortTasksByUrgency(_ items: [ApiTask]) -> [ApiTask] {
        items.sorted { compareByUrgency($0, $1) }
    }

    /// Compare two tasks by urgency (higher first, nil last), with UUID as tiebreaker.
    private static func compareByUrgency(_ lhs: ApiTask, _ rhs: ApiTask) -> Bool {
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

    static func selectedTask(tasks: [ApiTask], selectedIndex: Int?) -> ApiTask? {
        guard let index = selectedIndex, tasks.indices.contains(index) else { return nil }
        return tasks[index]
    }

    // MARK: - Grouped List Support

    /// Group tasks using the provided strategy.
    static func groupTasks(
        _ tasks: [ApiTask],
        using strategy: TaskGroupingStrategy,
        collapsedKeys: Set<String?>
    ) -> [GroupedListRow] {
        // If strategy doesn't show headers, return flat list sorted by urgency
        guard strategy.showsHeaders else {
            return sortTasksByUrgency(tasks).map { task in
                let flatIndex = tasks.firstIndex(where: { $0.uuid == task.uuid }) ?? 0
                return .task(GroupedTask(task: task, flatIndex: flatIndex, groupKey: nil))
            }
        }

        // Group tasks by key(s) - a task can belong to multiple groups
        var groups: [String?: [(Int, ApiTask)]] = [:]
        for (index, task) in tasks.enumerated() {
            for key in strategy.groupKeys(for: task) {
                groups[key, default: []].append((index, task))
            }
        }

        // Sort group keys using the strategy
        let sortedKeys = groups.keys.sorted { strategy.compare($0, $1) < 0 }

        // Build rows, sorting tasks within each group by urgency
        var rows: [GroupedListRow] = []
        for key in sortedKeys {
            // Skip entire group (header + tasks) if a parent is collapsed
            if strategy.isParentCollapsed(key, collapsedKeys: collapsedKeys) {
                continue
            }

            // Check if this group itself is directly collapsed
            let isCollapsed = collapsedKeys.contains(key)
            rows.append(.header(GroupHeader(
                key: key,
                displayName: strategy.displayName(for: key),
                isCollapsed: isCollapsed
            )))
            if !isCollapsed, let groupTasks = groups[key] {
                // Sort tasks within this group by urgency
                let sortedGroupTasks = groupTasks.sorted { lhs, rhs in
                    compareByUrgency(lhs.1, rhs.1)
                }
                for (flatIndex, task) in sortedGroupTasks {
                    rows.append(.task(GroupedTask(task: task, flatIndex: flatIndex, groupKey: key)))
                }
            }
        }
        return rows
    }

    /// Move selection in grouped view, including headers.
    /// Clamps to bounds (no wrap-around).
    static func moveGroupedSelection(
        rows: [GroupedListRow],
        currentRowIndex: Int?,
        delta: Int
    ) -> Int? {
        guard !rows.isEmpty else { return nil }

        if let current = currentRowIndex {
            let next = current + delta
            // Clamp to bounds instead of wrapping
            return max(0, min(next, rows.count - 1))
        }
        // Initial selection: first row if moving down, last row if moving up
        return delta >= 0 ? 0 : rows.count - 1
    }
}
