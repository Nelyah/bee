import Foundation
@testable import LauncherAppKit
import XCTest

final class RelativeDateFormatterTests: XCTestCase {
    func testYesterdayUsesCalendarDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let now = Date(timeIntervalSince1970: 1_704_998_400) // 2024-01-11T00:00:00Z
        let yesterday = "2024-01-10T23:50:00Z"

        let result = RelativeDateFormatter.description(for: yesterday, now: now, calendar: calendar)

        XCTAssertEqual(result, "yesterday")
    }

    func testTodayUsesCalendarDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let now = Date(timeIntervalSince1970: 1_704_998_400) // 2024-01-11T00:00:00Z
        let today = "2024-01-11T12:00:00Z"

        let result = RelativeDateFormatter.description(for: today, now: now, calendar: calendar)

        XCTAssertEqual(result, "today")
    }

    // MARK: - Short Description Tests

    func testShortDescriptionToday() {
        // Create a date string for "now"
        let formatter = ISO8601DateFormatter()
        let now = Date()
        let todayString = formatter.string(from: now)

        let result = RelativeDateFormatter.shortDescription(for: todayString)
        XCTAssertEqual(result, "today")
    }

    func testShortDescriptionDaysAgo() {
        let formatter = ISO8601DateFormatter()
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        let dateString = formatter.string(from: twoDaysAgo)

        let result = RelativeDateFormatter.shortDescription(for: dateString)
        XCTAssertEqual(result, "2d")
    }

    func testShortDescriptionWeeksAgo() {
        let formatter = ISO8601DateFormatter()
        let twoWeeksAgo = Calendar.current.date(byAdding: .weekOfYear, value: -2, to: Date())!
        let dateString = formatter.string(from: twoWeeksAgo)

        let result = RelativeDateFormatter.shortDescription(for: dateString)
        XCTAssertEqual(result, "2w")
    }

    func testShortDescriptionMonthsAgo() {
        let formatter = ISO8601DateFormatter()
        let threeMonthsAgo = Calendar.current.date(byAdding: .month, value: -3, to: Date())!
        let dateString = formatter.string(from: threeMonthsAgo)

        let result = RelativeDateFormatter.shortDescription(for: dateString)
        XCTAssertEqual(result, "3mo")
    }

    func testShortDescriptionYearsAgo() {
        let formatter = ISO8601DateFormatter()
        let twoYearsAgo = Calendar.current.date(byAdding: .year, value: -2, to: Date())!
        let dateString = formatter.string(from: twoYearsAgo)

        let result = RelativeDateFormatter.shortDescription(for: dateString)
        XCTAssertEqual(result, "2y")
    }

    func testShortDescriptionInvalidDate() {
        let result = RelativeDateFormatter.shortDescription(for: "invalid-date")
        XCTAssertEqual(result, "-")
    }

    func testShortDescriptionFutureDate() {
        let formatter = ISO8601DateFormatter()
        let threeDaysFromNow = Calendar.current.date(byAdding: .day, value: 3, to: Date())!
        let dateString = formatter.string(from: threeDaysFromNow)

        let result = RelativeDateFormatter.shortDescription(for: dateString)
        // Result could be "in 2d" or "in 3d" depending on time of day
        XCTAssertTrue(result.hasPrefix("in ") && result.hasSuffix("d"))
    }
}
