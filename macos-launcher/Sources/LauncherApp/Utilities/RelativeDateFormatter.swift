import Foundation

enum RelativeDateFormatter {
    static func description(for isoDate: String, now: Date = Date(), calendar: Calendar = .current) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: isoDate) {
            return description(for: date, now: now, calendar: calendar)
        }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: isoDate) {
            return description(for: date, now: now, calendar: calendar)
        }
        return isoDate
    }

    private static func description(for date: Date, now: Date, calendar: Calendar) -> String {
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
