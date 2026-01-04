import Foundation

/// Quick action options for setting a due date with common time presets.
///
/// Each action calculates a target date based on the current time, making it easy
/// for users to quickly set common due dates without manual date picking.
enum QuickDueDateAction: Equatable {
    /// Today at 5pm (or current time if past 5pm).
    case today

    /// Tomorrow at 9am.
    case tomorrow

    /// Next occurrence of the current weekday (e.g., "Next Wednesday").
    /// Always at least 7 days away to avoid confusion with "tomorrow".
    case nextWeekday

    /// Next Monday at 9am.
    case nextWeek

    /// Same day of the week, +7 days at 9am.
    case inOneWeek

    /// The display label for the action button.
    ///
    /// For `nextWeekday`, this dynamically shows the weekday name (e.g., "Next Wed").
    var label: String {
        switch self {
        case .today:
            return "Today"
        case .tomorrow:
            return "Tomorrow"
        case .nextWeekday:
            let calendar = Calendar.current
            let weekday = calendar.component(.weekday, from: Date())
            let formatter = DateFormatter()
            // Short weekday name (e.g., "Wed")
            let weekdayName = formatter.shortWeekdaySymbols[weekday - 1]
            return "Next \(weekdayName)"
        case .nextWeek:
            return "Next Week"
        case .inOneWeek:
            return "+1 Week"
        }
    }

    /// All actions in display order.
    static var allActions: [QuickDueDateAction] {
        [.today, .tomorrow, .nextWeekday, .nextWeek, .inOneWeek]
    }

    /// Calculates the target date for this action.
    ///
    /// - Parameters:
    ///   - now: The current date/time (defaults to now).
    ///   - calendar: The calendar to use for calculations (defaults to current).
    /// - Returns: The calculated due date.
    func date(from now: Date = Date(), calendar: Calendar = .current) -> Date {
        switch self {
        case .today:
            todayDate(from: now, calendar: calendar)
        case .tomorrow:
            tomorrowDate(from: now, calendar: calendar)
        case .nextWeekday:
            nextWeekdayDate(from: now, calendar: calendar)
        case .nextWeek:
            nextMondayDate(from: now, calendar: calendar)
        case .inOneWeek:
            inOneWeekDate(from: now, calendar: calendar)
        }
    }

    // MARK: - Private Date Calculations

    /// Today at 5pm, or current time if past 5pm.
    private func todayDate(from now: Date, calendar: Calendar) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = 17
        components.minute = 0
        components.second = 0

        let fivePM = calendar.date(from: components) ?? now

        // If it's already past 5pm, return current time rounded to next 15 minutes
        if now >= fivePM {
            return roundToNext15Minutes(now, calendar: calendar)
        }

        return fivePM
    }

    /// Tomorrow at 9am.
    private func tomorrowDate(from now: Date, calendar: Calendar) -> Date {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        var components = calendar.dateComponents([.year, .month, .day], from: tomorrow)
        components.hour = 9
        components.minute = 0
        components.second = 0
        return calendar.date(from: components) ?? tomorrow
    }

    /// Next occurrence of the current weekday, at least 7 days away, at 9am.
    ///
    /// For example, if today is Wednesday, this returns next Wednesday.
    private func nextWeekdayDate(from now: Date, calendar: Calendar) -> Date {
        // Add 7 days to get the same weekday next week
        let nextWeek = calendar.date(byAdding: .day, value: 7, to: now) ?? now
        var components = calendar.dateComponents([.year, .month, .day], from: nextWeek)
        components.hour = 9
        components.minute = 0
        components.second = 0
        return calendar.date(from: components) ?? nextWeek
    }

    /// Next Monday at 9am.
    private func nextMondayDate(from now: Date, calendar: Calendar) -> Date {
        let currentWeekday = calendar.component(.weekday, from: now)
        // weekday: 1 = Sunday, 2 = Monday, ..., 7 = Saturday
        // Calculate days until next Monday
        let daysUntilMonday = if currentWeekday == 2 {
            // Today is Monday, go to next Monday
            7
        } else if currentWeekday == 1 {
            // Sunday -> Monday is tomorrow
            1
        } else {
            // Tuesday(3) through Saturday(7)
            // Days until Monday = 9 - currentWeekday
            // e.g., Wednesday(4) -> 9-4 = 5 days
            9 - currentWeekday
        }

        let nextMonday = calendar.date(byAdding: .day, value: daysUntilMonday, to: now) ?? now
        var components = calendar.dateComponents([.year, .month, .day], from: nextMonday)
        components.hour = 9
        components.minute = 0
        components.second = 0
        return calendar.date(from: components) ?? nextMonday
    }

    /// Same time next week (+7 days) at 9am.
    private func inOneWeekDate(from now: Date, calendar: Calendar) -> Date {
        let nextWeek = calendar.date(byAdding: .day, value: 7, to: now) ?? now
        var components = calendar.dateComponents([.year, .month, .day], from: nextWeek)
        components.hour = 9
        components.minute = 0
        components.second = 0
        return calendar.date(from: components) ?? nextWeek
    }

    /// Rounds a date to the next 15-minute interval.
    private func roundToNext15Minutes(_ date: Date, calendar: Calendar) -> Date {
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let minute = components.minute ?? 0
        let roundedMinute = ((minute / 15) + 1) * 15

        if roundedMinute >= 60 {
            components.minute = 0
            components.hour = (components.hour ?? 0) + 1
        } else {
            components.minute = roundedMinute
        }
        components.second = 0

        return calendar.date(from: components) ?? date
    }
}
