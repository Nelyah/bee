struct TaskListCoordinator {
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
        items.sorted { lhs, rhs in
            switch (lhs.urgency, rhs.urgency) {
            case let (l?, r?):
                if l == r {
                    return lhs.uuid < rhs.uuid
                }
                return l > r
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return lhs.uuid < rhs.uuid
            }
        }
    }

    static func selectedTask(tasks: [ApiTask], selectedIndex: Int?) -> ApiTask? {
        guard let index = selectedIndex, tasks.indices.contains(index) else { return nil }
        return tasks[index]
    }
}
