import Foundation

/// Represents a single entry in the navigation stack.
/// Each entry captures enough context to restore the view state when navigating back.
enum NavigationEntry: Equatable {
    /// Task list view - always the root of the navigation stack
    case taskList

    /// Task detail view
    /// - Parameters:
    ///   - uuid: The task UUID being viewed
    ///   - previousSelectedIndex: The selectedIndex before navigating here (used to restore list selection on pop)
    case taskDetail(uuid: String, previousSelectedIndex: Int?)

    /// Project overview view
    case projectOverview

    /// Convert to LauncherMode for rendering
    var mode: LauncherMode {
        switch self {
        case .taskList:
            .list
        case .taskDetail:
            .detail
        case .projectOverview:
            .projectOverview
        }
    }

    /// Whether this entry represents a detail view for a specific task
    func isDetailFor(uuid: String) -> Bool {
        if case let .taskDetail(entryUuid, _) = self {
            return entryUuid == uuid
        }
        return false
    }

    /// Extract the task UUID if this is a task detail entry
    var taskUUID: String? {
        if case let .taskDetail(uuid, _) = self {
            return uuid
        }
        return nil
    }
}
