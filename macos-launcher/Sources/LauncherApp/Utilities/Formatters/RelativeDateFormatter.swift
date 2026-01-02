import Foundation

enum RelativeDateFormatter {
    // MARK: - Cached Formatters (avoid allocating per-call)

    /// ISO8601 formatter with fractional seconds support
    private static let isoFormatterWithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    /// ISO8601 formatter without fractional seconds (fallback)
    private static let isoFormatterBasic: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func description(for isoDate: String, now: Date = Date(), calendar: Calendar = .current) -> String {
        if let date = date(from: isoDate) {
            return description(for: date, now: now, calendar: calendar)
        }
        return isoDate
    }

    static func date(from isoDate: String) -> Date? {
        // Try with fractional seconds first (more common), then fallback
        if let date = isoFormatterWithFractional.date(from: isoDate) {
            return date
        }
        return isoFormatterBasic.date(from: isoDate)
    }

    static func description(for date: Date, now: Date, calendar: Calendar) -> String {
        let dateStart = calendar.startOfDay(for: date)
        let nowStart = calendar.startOfDay(for: now)
        let days = calendar.dateComponents([.day], from: dateStart, to: nowStart).day ?? 0
        if days == 0 {
            return "today"
        } else if days == 1 {
            return "yesterday"
        } else if days == -1 {
            return "tomorrow"
        }

        let absDays = abs(days)
        if absDays >= 365 {
            let years = absDays / 365
            return days > 0 ? "\(years)y ago" : "in \(years)y"
        } else if absDays >= 30 {
            let months = absDays / 30
            return days > 0 ? "\(months)mo ago" : "in \(months)mo"
        } else if absDays >= 7 {
            let weeks = absDays / 7
            return days > 0 ? "\(weeks)w ago" : "in \(weeks)w"
        } else if days > 0 {
            return "\(days)d ago"
        } else {
            return "in \(absDays)d"
        }
    }
}
