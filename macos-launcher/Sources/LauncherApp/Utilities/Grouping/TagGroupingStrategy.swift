import Foundation

/// Groups tasks by tags. Tasks appear in all their tag groups (duplicates allowed).
struct TagGroupingStrategy: TaskGroupingStrategy {
    func groupKey(for task: ApiTask) -> String? {
        task.tags.first
    }

    /// Returns all tags for a task, allowing it to appear in multiple groups.
    func groupKeys(for task: ApiTask) -> [String?] {
        task.tags.isEmpty ? [nil] : task.tags.map { $0 }
    }

    func displayName(for key: String?) -> String {
        key.map { "+\($0)" } ?? "No Tags"
    }

    func compare(_ lhs: String?, _ rhs: String?) -> Int {
        // nil (No Tags) comes last
        switch (lhs, rhs) {
        case (nil, nil): return 0
        case (nil, _): return 1
        case (_, nil): return -1
        case let (l?, r?):
            let result = l.localizedCaseInsensitiveCompare(r)
            switch result {
            case .orderedAscending: return -1
            case .orderedDescending: return 1
            case .orderedSame: return 0
            }
        }
    }
}
