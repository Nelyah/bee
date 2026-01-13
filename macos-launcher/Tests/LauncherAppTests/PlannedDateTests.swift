@testable import LauncherAppKit
import XCTest

/// Tests for planned date feature across the application.
final class PlannedDateTests: XCTestCase {
    // MARK: - DetailFocusableItem Tests

    func testPlannedDateFocusableItemId() {
        let item = DetailFocusableItem.plannedDate("2024-01-18T09:00:00Z")
        XCTAssertEqual(item.id, "plannedDate")
    }

    func testPlannedDateFocusableItemIdWithNil() {
        let item = DetailFocusableItem.plannedDate(nil)
        XCTAssertEqual(item.id, "plannedDate")
    }

    func testPlannedDateCopyValueWithDate() {
        let item = DetailFocusableItem.plannedDate("2024-01-18T09:00:00Z")
        XCTAssertEqual(item.copyValue, "2024-01-18T09:00:00Z")
    }

    func testPlannedDateCopyValueWithNil() {
        let item = DetailFocusableItem.plannedDate(nil)
        XCTAssertEqual(item.copyValue, "")
    }

    func testPlannedDateCopyLabel() {
        let item = DetailFocusableItem.plannedDate("2024-01-18T09:00:00Z")
        XCTAssertEqual(item.copyLabel, "Planned date")
    }

    func testPlannedDateOpenURLIsNil() {
        let item = DetailFocusableItem.plannedDate("2024-01-18T09:00:00Z")
        XCTAssertNil(item.openURL)
    }

    func testPlannedDateEquatable() {
        let item1 = DetailFocusableItem.plannedDate("2024-01-18T09:00:00Z")
        let item2 = DetailFocusableItem.plannedDate("2024-01-18T09:00:00Z")
        let item3 = DetailFocusableItem.plannedDate("2024-01-19T09:00:00Z")
        let item4 = DetailFocusableItem.plannedDate(nil)

        XCTAssertEqual(item1, item2)
        XCTAssertNotEqual(item1, item3)
        XCTAssertNotEqual(item1, item4)
    }

    func testPlannedDateIdentifiable() {
        let item = DetailFocusableItem.plannedDate("2024-01-18T09:00:00Z")
        // Should be usable in SwiftUI ForEach
        XCTAssertFalse(item.id.isEmpty)
    }

    // MARK: - Due Date vs Planned Date Comparison

    func testDueDateAndPlannedDateAreDifferentFocusItems() {
        let dueDate = DetailFocusableItem.dueDate("2024-01-20T17:00:00Z")
        let plannedDate = DetailFocusableItem.plannedDate("2024-01-18T09:00:00Z")

        XCTAssertNotEqual(dueDate.id, plannedDate.id)
        XCTAssertNotEqual(dueDate, plannedDate)
    }

    func testDueDateCopyLabelDifferentFromPlannedDate() {
        let dueDate = DetailFocusableItem.dueDate("2024-01-20T17:00:00Z")
        let plannedDate = DetailFocusableItem.plannedDate("2024-01-18T09:00:00Z")

        XCTAssertEqual(dueDate.copyLabel, "Due date")
        XCTAssertEqual(plannedDate.copyLabel, "Planned date")
    }
}

// MARK: - Column Configuration Tests

final class PlannedDateColumnTests: XCTestCase {
    func testDatePlannedColumnExists() {
        let column = ColumnDefinition.datePlanned
        XCTAssertEqual(column.rawValue, "date_planned")
    }

    func testDatePlannedDisplayName() {
        let column = ColumnDefinition.datePlanned
        XCTAssertEqual(column.displayName, "Planned")
    }

    func testDatePlannedIcon() {
        let column = ColumnDefinition.datePlanned
        XCTAssertEqual(column.icon, "calendar")
    }

    func testDatePlannedDefaultWidth() {
        // defaultWidth is a static method on ColumnConfig, not ColumnDefinition
        let width = ColumnConfig.defaultWidth(for: ColumnDefinition.datePlanned.rawValue)
        XCTAssertEqual(width, 80)
    }

    func testDatePlannedAllColumnsContainsIt() {
        XCTAssertTrue(ColumnDefinition.allCases.contains(.datePlanned))
    }

    func testDateDueAndDatePlannedHaveDifferentRawValues() {
        XCTAssertNotEqual(ColumnDefinition.dateDue.rawValue, ColumnDefinition.datePlanned.rawValue)
    }
}

// MARK: - QuickDueDateAction Reusability Tests

/// Tests that QuickDueDateAction works correctly for both due dates and planned dates.
/// The action logic is shared between both features.
final class QuickDueDateActionPlannedDateTests: XCTestCase {
    var calendar: Calendar!
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

    func testTodayActionCanBeUsedForPlannedDate() {
        // Verifying the action produces valid dates for planned date usage
        let action = QuickDueDateAction.today
        let result = action.date(from: fixedNow, calendar: calendar)

        // The date should be valid and in the future (or current time)
        XCTAssertTrue(result >= calendar.startOfDay(for: fixedNow))
    }

    func testTomorrowActionCanBeUsedForPlannedDate() {
        let action = QuickDueDateAction.tomorrow
        let result = action.date(from: fixedNow, calendar: calendar)

        // Tomorrow at 9 AM
        let components = calendar.dateComponents([.day, .hour], from: result)
        XCTAssertEqual(components.day, 16)
        XCTAssertEqual(components.hour, 9)
    }

    func testNextWeekActionCanBeUsedForPlannedDate() {
        let action = QuickDueDateAction.nextWeek
        let result = action.date(from: fixedNow, calendar: calendar)

        // Next Monday
        let components = calendar.dateComponents([.weekday], from: result)
        XCTAssertEqual(components.weekday, 2) // Monday
    }

    func testAllActionsProduceValidDates() {
        for action in QuickDueDateAction.allActions {
            let result = action.date(from: fixedNow, calendar: calendar)
            XCTAssertNotNil(result, "Action \(action.label) should produce a valid date")
        }
    }
}
