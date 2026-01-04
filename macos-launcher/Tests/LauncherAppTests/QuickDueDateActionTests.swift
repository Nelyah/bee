@testable import LauncherApp
import XCTest

/// Tests for QuickDueDateAction date calculations.
///
/// These tests use fixed dates to ensure deterministic results,
/// avoiding issues with tests running at different times of day.
final class QuickDueDateActionTests: XCTestCase {
    // A fixed calendar for testing (using the user's current calendar settings)
    var calendar: Calendar!
    // A fixed "now" for consistent test results
    var fixedNow: Date!

    override func setUp() {
        super.setUp()
        calendar = Calendar.current
        // Wednesday, January 15, 2025 at 10:00 AM
        var components = DateComponents()
        components.year = 2025
        components.month = 1
        components.day = 15
        components.hour = 10
        components.minute = 0
        components.second = 0
        fixedNow = calendar.date(from: components)!
    }

    // MARK: - Today Action

    func testTodayAction_beforeFivePM_returnsFivePM() {
        // Given: It's 10:00 AM on January 15, 2025
        let action = QuickDueDateAction.today

        // When
        let result = action.date(from: fixedNow, calendar: calendar)

        // Then: Should return 5:00 PM today
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: result)
        XCTAssertEqual(components.year, 2025)
        XCTAssertEqual(components.month, 1)
        XCTAssertEqual(components.day, 15)
        XCTAssertEqual(components.hour, 17)
        XCTAssertEqual(components.minute, 0)
    }

    func testTodayAction_afterFivePM_returnsRoundedCurrentTime() {
        // Given: It's 6:23 PM on January 15, 2025
        var lateComponents = DateComponents()
        lateComponents.year = 2025
        lateComponents.month = 1
        lateComponents.day = 15
        lateComponents.hour = 18
        lateComponents.minute = 23
        let lateNow = calendar.date(from: lateComponents)!

        let action = QuickDueDateAction.today

        // When
        let result = action.date(from: lateNow, calendar: calendar)

        // Then: Should return rounded to next 15 minutes (6:30 PM)
        let resultComponents = calendar.dateComponents([.hour, .minute], from: result)
        XCTAssertEqual(resultComponents.hour, 18)
        XCTAssertEqual(resultComponents.minute, 30)
    }

    // MARK: - Tomorrow Action

    func testTomorrowAction_returnsNineAMTomorrow() {
        // Given
        let action = QuickDueDateAction.tomorrow

        // When
        let result = action.date(from: fixedNow, calendar: calendar)

        // Then: Should return 9:00 AM tomorrow (January 16)
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: result)
        XCTAssertEqual(components.year, 2025)
        XCTAssertEqual(components.month, 1)
        XCTAssertEqual(components.day, 16)
        XCTAssertEqual(components.hour, 9)
        XCTAssertEqual(components.minute, 0)
    }

    // MARK: - Next Weekday Action

    func testNextWeekdayAction_returnsSevenDaysLater() {
        // Given: It's Wednesday, January 15, 2025
        let action = QuickDueDateAction.nextWeekday

        // When
        let result = action.date(from: fixedNow, calendar: calendar)

        // Then: Should return Wednesday, January 22 at 9:00 AM
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .weekday], from: result)
        XCTAssertEqual(components.year, 2025)
        XCTAssertEqual(components.month, 1)
        XCTAssertEqual(components.day, 22)
        XCTAssertEqual(components.hour, 9)
        XCTAssertEqual(components.minute, 0)
        XCTAssertEqual(components.weekday, 4) // Wednesday
    }

    // MARK: - Next Week (Next Monday) Action

    func testNextWeekAction_fromWednesday_returnsNextMonday() {
        // Given: It's Wednesday, January 15, 2025
        let action = QuickDueDateAction.nextWeek

        // When
        let result = action.date(from: fixedNow, calendar: calendar)

        // Then: Should return Monday, January 20 at 9:00 AM
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .weekday], from: result)
        XCTAssertEqual(components.year, 2025)
        XCTAssertEqual(components.month, 1)
        XCTAssertEqual(components.day, 20)
        XCTAssertEqual(components.hour, 9)
        XCTAssertEqual(components.minute, 0)
        XCTAssertEqual(components.weekday, 2) // Monday
    }

    func testNextWeekAction_fromMonday_returnsFollowingMonday() {
        // Given: It's Monday, January 13, 2025
        var mondayComponents = DateComponents()
        mondayComponents.year = 2025
        mondayComponents.month = 1
        mondayComponents.day = 13
        mondayComponents.hour = 10
        mondayComponents.minute = 0
        let monday = calendar.date(from: mondayComponents)!

        let action = QuickDueDateAction.nextWeek

        // When
        let result = action.date(from: monday, calendar: calendar)

        // Then: Should return Monday, January 20 (not the same day)
        let components = calendar.dateComponents([.year, .month, .day, .weekday], from: result)
        XCTAssertEqual(components.year, 2025)
        XCTAssertEqual(components.month, 1)
        XCTAssertEqual(components.day, 20)
        XCTAssertEqual(components.weekday, 2) // Monday
    }

    func testNextWeekAction_fromSunday_returnsTomorrowMonday() {
        // Given: It's Sunday, January 19, 2025
        var sundayComponents = DateComponents()
        sundayComponents.year = 2025
        sundayComponents.month = 1
        sundayComponents.day = 19
        sundayComponents.hour = 10
        sundayComponents.minute = 0
        let sunday = calendar.date(from: sundayComponents)!

        let action = QuickDueDateAction.nextWeek

        // When
        let result = action.date(from: sunday, calendar: calendar)

        // Then: Should return Monday, January 20 (tomorrow)
        let components = calendar.dateComponents([.year, .month, .day, .weekday], from: result)
        XCTAssertEqual(components.year, 2025)
        XCTAssertEqual(components.month, 1)
        XCTAssertEqual(components.day, 20)
        XCTAssertEqual(components.weekday, 2) // Monday
    }

    // MARK: - In One Week Action

    func testInOneWeekAction_returnsSevenDaysLater() {
        // Given: It's Wednesday, January 15, 2025
        let action = QuickDueDateAction.inOneWeek

        // When
        let result = action.date(from: fixedNow, calendar: calendar)

        // Then: Should return Wednesday, January 22 at 9:00 AM
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: result)
        XCTAssertEqual(components.year, 2025)
        XCTAssertEqual(components.month, 1)
        XCTAssertEqual(components.day, 22)
        XCTAssertEqual(components.hour, 9)
        XCTAssertEqual(components.minute, 0)
    }

    // MARK: - Label Tests

    func testLabel_today() {
        XCTAssertEqual(QuickDueDateAction.today.label, "Today")
    }

    func testLabel_tomorrow() {
        XCTAssertEqual(QuickDueDateAction.tomorrow.label, "Tomorrow")
    }

    func testLabel_nextWeek() {
        XCTAssertEqual(QuickDueDateAction.nextWeek.label, "Next Week")
    }

    func testLabel_inOneWeek() {
        XCTAssertEqual(QuickDueDateAction.inOneWeek.label, "+1 Week")
    }

    func testLabel_nextWeekday_includesWeekdayName() {
        // Note: This test depends on the current day, but we verify it has "Next" prefix
        let label = QuickDueDateAction.nextWeekday.label
        XCTAssertTrue(label.hasPrefix("Next "))
        // The weekday abbreviation should be 3 characters
        let weekdayPart = String(label.dropFirst(5))
        XCTAssertTrue(weekdayPart.count >= 2 && weekdayPart.count <= 4)
    }

    // MARK: - All Actions

    func testAllActions_containsAllCases() {
        let allActions = QuickDueDateAction.allActions
        XCTAssertEqual(allActions.count, 5)
        XCTAssertTrue(allActions.contains(.today))
        XCTAssertTrue(allActions.contains(.tomorrow))
        XCTAssertTrue(allActions.contains(.nextWeekday))
        XCTAssertTrue(allActions.contains(.nextWeek))
        XCTAssertTrue(allActions.contains(.inOneWeek))
    }
}
