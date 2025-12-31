import Foundation
@testable import LauncherApp
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
}
