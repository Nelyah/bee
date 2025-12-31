import Foundation

/// Groups tasks by due date bucket: overdue, today, tomorrow, future, or no due date.
struct DueDateGroupingStrategy: TaskGroupingStrategy {
    /// Due date buckets for grouping.
    enum Bucket: String, CaseIterable {
        case overdue
        case today
        case tomorrow
        case future
        case noDueDate

        var displayName: String {
            switch self {
            case .overdue: return "Overdue"
            case .today: return "Today"
            case .tomorrow: return "Tomorrow"
            case .future: return "Future"
            case .noDueDate: return "No Due Date"
            }
        }

        var sortOrder: Int {
            switch self {
            case .overdue: return 0
            case .today: return 1
            case .tomorrow: return 2
            case .future: return 3
            case .noDueDate: return 4
            }
        }
    }

    private let calendar: Calendar
    private let today: Date

    init(calendar: Calendar = .current, today: Date? = nil) {
        self.calendar = calendar
        self.today = today ?? Date()
    }

    func groupKey(for task: ApiTask) -> String? {
        guard let dateStr = task.dateDue else {
            return Bucket.noDueDate.rawValue
        }

        guard let dueDate = parseDate(dateStr) else {
            return Bucket.noDueDate.rawValue
        }

        let daysDifference = calendar.dateComponents([.day], from: calendar.startOfDay(for: today), to: calendar.startOfDay(for: dueDate)).day ?? 0

        if daysDifference < 0 {
            return Bucket.overdue.rawValue
        } else if daysDifference == 0 {
            return Bucket.today.rawValue
        } else if daysDifference == 1 {
            return Bucket.tomorrow.rawValue
        } else {
            return Bucket.future.rawValue
        }
    }

    func displayName(for key: String?) -> String {
        guard let key = key, let bucket = Bucket(rawValue: key) else {
            return "Unknown"
        }
        return bucket.displayName
    }

    func compare(_ lhs: String?, _ rhs: String?) -> Int {
        let lhsOrder = lhs.flatMap { Bucket(rawValue: $0)?.sortOrder } ?? Int.max
        let rhsOrder = rhs.flatMap { Bucket(rawValue: $0)?.sortOrder } ?? Int.max
        return lhsOrder - rhsOrder
    }

    private func parseDate(_ dateString: String) -> Date? {
        // Try ISO8601 with fractional seconds first
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: dateString) {
            return date
        }

        // Try without fractional seconds
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: dateString) {
            return date
        }

        // Try date-only format (YYYY-MM-DD)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        return dateFormatter.date(from: dateString)
    }
}
