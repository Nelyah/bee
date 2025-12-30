import Foundation

/// Protocol for different task grouping strategies.
protocol TaskGroupingStrategy {
    /// Extract the grouping key from a task.
    func groupKey(for task: ApiTask) -> String?

    /// Display name for a group key (nil key = ungrouped items).
    func displayName(for key: String?) -> String

    /// Sort order for groups (keys). Return negative to sort before, positive after, zero for equal.
    func compare(_ lhs: String?, _ rhs: String?) -> Int

    /// Check if a key or any of its ancestors is collapsed.
    func isCollapsed(_ key: String?, collapsedKeys: Set<String?>) -> Bool

    /// Check if any ancestor (parent) of this key is collapsed.
    /// Returns false for the key itself - only checks parents.
    func isParentCollapsed(_ key: String?, collapsedKeys: Set<String?>) -> Bool
}

/// Groups tasks by their project field.
struct ProjectGroupingStrategy: TaskGroupingStrategy {
    func groupKey(for task: ApiTask) -> String? {
        task.project
    }

    func displayName(for key: String?) -> String {
        key ?? "No Project"
    }

    func compare(_ lhs: String?, _ rhs: String?) -> Int {
        // nil (No Project) comes first
        switch (lhs, rhs) {
        case (nil, nil): return 0
        case (nil, _): return -1 // No Project first
        case (_, nil): return 1
        case let (l?, r?):
            let result = l.localizedCaseInsensitiveCompare(r)
            switch result {
            case .orderedAscending: return -1
            case .orderedDescending: return 1
            case .orderedSame: return 0
            }
        }
    }

    func isCollapsed(_ key: String?, collapsedKeys: Set<String?>) -> Bool {
        guard let key = key else {
            // nil key = "No Project", just check direct collapse
            return collapsedKeys.contains(nil)
        }

        // Check if this exact key is collapsed
        if collapsedKeys.contains(key) {
            return true
        }

        // Check if any parent is collapsed
        return isParentCollapsed(key, collapsedKeys: collapsedKeys)
    }

    func isParentCollapsed(_ key: String?, collapsedKeys: Set<String?>) -> Bool {
        guard let key = key else {
            // nil key ("No Project") has no parent
            return false
        }

        // Check if any parent is collapsed (for hierarchical projects like "work.client1")
        var components = key.split(separator: ".").map(String.init)
        while components.count > 1 {
            components.removeLast()
            let parentKey = components.joined(separator: ".")
            if collapsedKeys.contains(parentKey) {
                return true
            }
        }

        return false
    }
}
