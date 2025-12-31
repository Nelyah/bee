import Foundation

/// A row in a grouped task list - either a section header or a task.
enum GroupedListRow: Identifiable {
    case header(GroupHeader)
    case task(GroupedTask)

    var id: String {
        switch self {
        case let .header(h): "header-\(h.id)"
        case let .task(t): t.id
        }
    }
}

/// A group header with collapse state.
struct GroupHeader: Identifiable {
    /// The grouping key (nil for "ungrouped" items).
    let key: String?
    /// What to show in the UI.
    let displayName: String
    /// Whether this group is collapsed.
    var isCollapsed: Bool

    var id: String { key ?? "__none__" }
}

/// A task with its position in the original flat array.
struct GroupedTask: Identifiable {
    let task: ApiTask
    /// Index in the original (non-grouped) task array.
    let flatIndex: Int
    /// The group key this task belongs to (for unique ID when task appears in multiple groups).
    let groupKey: String?

    var id: String {
        let keyPart = groupKey ?? "__none__"
        return "\(keyPart)-task-\(task.uuid)"
    }
}
