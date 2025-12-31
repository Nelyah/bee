import Foundation

/// Displays tasks as a flat list without group headers.
struct NoGroupingStrategy: TaskGroupingStrategy {
    var showsHeaders: Bool { false }

    func groupKey(for task: ApiTask) -> String? {
        nil
    }

    func displayName(for key: String?) -> String {
        "Tasks"
    }

    func compare(_ lhs: String?, _ rhs: String?) -> Int {
        0
    }

    func isCollapsed(_ key: String?, collapsedKeys: Set<String?>) -> Bool {
        false
    }
}
