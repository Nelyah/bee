import Foundation

// MARK: - Grouping Methods

extension LauncherViewModel {
    /// Computed grouped rows for display.
    var groupedRows: [GroupedListRow] {
        TaskListCoordinator.groupTasks(tasks, using: groupingStrategy, collapsedKeys: collapsedGroups)
    }

    /// Toggle collapse for a group.
    func toggleGroupCollapse(_ key: String?) {
        if collapsedGroups.contains(key) {
            collapsedGroups.remove(key)
        } else {
            collapsedGroups.insert(key)
        }
        saveCollapsedState()
    }

    /// Toggle collapse for the currently selected or hovered header. Returns true if toggled.
    func toggleSelectedOrHoveredGroupCollapse() -> Bool {
        let rows = groupedRows
        // Prefer selected row (keyboard navigation), fall back to hovered (mouse)
        let idx = selectedRowIndex ?? hoveredRowIndex
        guard let idx,
              idx < rows.count,
              case let .header(header) = rows[idx]
        else {
            return false
        }
        toggleGroupCollapse(header.key)
        return true
    }

    func canToggleSelectedOrHoveredGroupCollapse() -> Bool {
        let rows = groupedRows
        let idx = selectedRowIndex ?? hoveredRowIndex
        guard let idx, idx < rows.count else { return false }
        if case .header = rows[idx] {
            return true
        }
        return false
    }

    func saveCollapsedState() {
        let keys = collapsedGroups.compactMap { $0 }
        UserDefaults.standard.set(keys, forKey: UserDefaultsKeys.collapsedGroups)
        UserDefaults.standard.set(collapsedGroups.contains(nil), forKey: UserDefaultsKeys.collapsedNilGroup)
    }

    func loadCollapsedState() {
        let keys = UserDefaults.standard.stringArray(forKey: UserDefaultsKeys.collapsedGroups) ?? []
        let includesNil = UserDefaults.standard.bool(forKey: UserDefaultsKeys.collapsedNilGroup)
        collapsedGroups = Set(keys.map { Optional($0) })
        if includesNil { collapsedGroups.insert(nil) }
    }

    /// Set the grouping strategy and persist the selection.
    func setGroupingStrategy(_ option: GroupByOption) {
        // Clear collapsed state - keys won't match new strategy
        collapsedGroups.removeAll()

        groupingStrategy = option.makeStrategy()

        // Persist selection
        UserDefaults.standard.set(option.rawValue, forKey: UserDefaultsKeys.selectedGroupBy)

        // Clear old collapsed state persistence
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.collapsedGroups)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.collapsedNilGroup)

        // Close command palette after selection
        commandPalette.close()
    }

    /// Load the persisted grouping strategy.
    func loadGroupingStrategy() {
        let rawValue = UserDefaults.standard.string(forKey: UserDefaultsKeys.selectedGroupBy)
        let option = rawValue.flatMap { GroupByOption(rawValue: $0) } ?? .project
        groupingStrategy = option.makeStrategy()
    }
}
