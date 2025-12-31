import XCTest
@testable import LauncherApp

final class GroupingStrategyTests: XCTestCase {

    // MARK: - DueDateGroupingStrategy Tests

    func testDueDateBucketOverdue() {
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let strategy = DueDateGroupingStrategy(calendar: calendar, today: today)

        let task = makeTask(id: "a", dateDue: formatDate(yesterday))
        let key = strategy.groupKey(for: task)

        XCTAssertEqual(key, "overdue")
        XCTAssertEqual(strategy.displayName(for: key), "Overdue")
    }

    func testDueDateBucketToday() {
        let calendar = Calendar.current
        let today = Date()
        let strategy = DueDateGroupingStrategy(calendar: calendar, today: today)

        let task = makeTask(id: "a", dateDue: formatDate(today))
        let key = strategy.groupKey(for: task)

        XCTAssertEqual(key, "today")
        XCTAssertEqual(strategy.displayName(for: key), "Today")
    }

    func testDueDateBucketTomorrow() {
        let calendar = Calendar.current
        let today = Date()
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let strategy = DueDateGroupingStrategy(calendar: calendar, today: today)

        let task = makeTask(id: "a", dateDue: formatDate(tomorrow))
        let key = strategy.groupKey(for: task)

        XCTAssertEqual(key, "tomorrow")
        XCTAssertEqual(strategy.displayName(for: key), "Tomorrow")
    }

    func testDueDateBucketFuture() {
        let calendar = Calendar.current
        let today = Date()
        let nextWeek = calendar.date(byAdding: .day, value: 7, to: today)!
        let strategy = DueDateGroupingStrategy(calendar: calendar, today: today)

        let task = makeTask(id: "a", dateDue: formatDate(nextWeek))
        let key = strategy.groupKey(for: task)

        XCTAssertEqual(key, "future")
        XCTAssertEqual(strategy.displayName(for: key), "Future")
    }

    func testDueDateBucketNoDueDate() {
        let strategy = DueDateGroupingStrategy()

        let task = makeTask(id: "a", dateDue: nil)
        let key = strategy.groupKey(for: task)

        XCTAssertEqual(key, "noDueDate")
        XCTAssertEqual(strategy.displayName(for: key), "No Due Date")
    }

    func testDueDateCompareOrder() {
        let strategy = DueDateGroupingStrategy()

        // overdue < today
        XCTAssertLessThan(strategy.compare("overdue", "today"), 0)
        // today < tomorrow
        XCTAssertLessThan(strategy.compare("today", "tomorrow"), 0)
        // tomorrow < future
        XCTAssertLessThan(strategy.compare("tomorrow", "future"), 0)
        // future < noDueDate
        XCTAssertLessThan(strategy.compare("future", "noDueDate"), 0)
        // Same bucket
        XCTAssertEqual(strategy.compare("today", "today"), 0)
    }

    // MARK: - TagGroupingStrategy Tests

    func testTagGroupingFirstTag() {
        let strategy = TagGroupingStrategy()

        let task = makeTask(id: "a", tags: ["urgent", "work"])
        let key = strategy.groupKey(for: task)

        XCTAssertEqual(key, "urgent")
    }

    func testTagGroupingMultipleTags() {
        let strategy = TagGroupingStrategy()

        let task = makeTask(id: "a", tags: ["urgent", "work"])
        let keys = strategy.groupKeys(for: task)

        XCTAssertEqual(keys.count, 2)
        XCTAssertTrue(keys.contains("urgent"))
        XCTAssertTrue(keys.contains("work"))
    }

    func testTagGroupingNoTags() {
        let strategy = TagGroupingStrategy()

        let task = makeTask(id: "a", tags: [])
        let keys = strategy.groupKeys(for: task)

        XCTAssertEqual(keys, [nil])
        XCTAssertEqual(strategy.displayName(for: nil), "No Tags")
    }

    func testTagDisplayNameFormat() {
        let strategy = TagGroupingStrategy()

        XCTAssertEqual(strategy.displayName(for: "urgent"), "+urgent")
        XCTAssertEqual(strategy.displayName(for: nil), "No Tags")
    }

    func testTagCompareOrder() {
        let strategy = TagGroupingStrategy()

        // nil (No Tags) comes last
        XCTAssertGreaterThan(strategy.compare(nil, "urgent"), 0)
        // Alphabetical
        XCTAssertLessThan(strategy.compare("alpha", "beta"), 0)
        XCTAssertGreaterThan(strategy.compare("beta", "alpha"), 0)
        XCTAssertEqual(strategy.compare("same", "same"), 0)
    }

    // MARK: - NoGroupingStrategy Tests

    func testNoGroupingAllSameKey() {
        let strategy = NoGroupingStrategy()

        let task1 = makeTask(id: "a", project: "alpha")
        let task2 = makeTask(id: "b", project: "beta")

        XCTAssertNil(strategy.groupKey(for: task1))
        XCTAssertNil(strategy.groupKey(for: task2))
    }

    func testNoGroupingNoHeaders() {
        let strategy = NoGroupingStrategy()

        XCTAssertFalse(strategy.showsHeaders)
    }

    func testNoGroupingNeverCollapsed() {
        let strategy = NoGroupingStrategy()

        XCTAssertFalse(strategy.isCollapsed(nil, collapsedKeys: [nil]))
        XCTAssertFalse(strategy.isCollapsed("any", collapsedKeys: ["any"]))
    }

    // MARK: - Integration: TaskListCoordinator with Strategies

    func testGroupTasksWithTagStrategy() {
        let tasks = [
            makeTask(id: "a", tags: ["urgent", "work"]),
            makeTask(id: "b", tags: ["work"]),
            makeTask(id: "c", tags: [])
        ]

        let rows = TaskListCoordinator.groupTasks(
            tasks,
            using: TagGroupingStrategy(),
            collapsedKeys: []
        )

        // Should have headers for: urgent, work, No Tags (in alphabetical order, No Tags last)
        // Task "a" appears in both urgent and work groups
        let headers = rows.compactMap { row -> String? in
            if case .header(let h) = row { return h.displayName }
            return nil
        }

        XCTAssertTrue(headers.contains("No Tags"))
        XCTAssertTrue(headers.contains("+urgent"))
        XCTAssertTrue(headers.contains("+work"))

        // Verify "No Tags" is last
        XCTAssertEqual(headers.last, "No Tags")
    }

    func testGroupTasksWithNoGroupingStrategy() {
        let tasks = [
            makeTask(id: "a", urgency: 5, project: "alpha"),
            makeTask(id: "b", urgency: 10, project: "beta"),
            makeTask(id: "c", urgency: 1, project: nil)
        ]

        let rows = TaskListCoordinator.groupTasks(
            tasks,
            using: NoGroupingStrategy(),
            collapsedKeys: []
        )

        // Should be all tasks, no headers
        XCTAssertEqual(rows.count, 3)
        for row in rows {
            if case .header = row {
                XCTFail("NoGroupingStrategy should not produce headers")
            }
        }

        // Should be sorted by urgency (highest first)
        let taskIds = rows.compactMap { row -> String? in
            if case .task(let t) = row { return t.task.uuid }
            return nil
        }
        XCTAssertEqual(taskIds, ["b", "a", "c"])
    }

    func testGroupTasksWithDueDateStrategy() {
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        let tasks = [
            makeTask(id: "a", dateDue: formatDate(yesterday)),
            makeTask(id: "b", dateDue: formatDate(today)),
            makeTask(id: "c", dateDue: formatDate(tomorrow)),
            makeTask(id: "d", dateDue: nil)
        ]

        let strategy = DueDateGroupingStrategy(calendar: calendar, today: today)
        let rows = TaskListCoordinator.groupTasks(
            tasks,
            using: strategy,
            collapsedKeys: []
        )

        let headers = rows.compactMap { row -> String? in
            if case .header(let h) = row { return h.displayName }
            return nil
        }

        XCTAssertEqual(headers, ["Overdue", "Today", "Tomorrow", "No Due Date"])
    }
}

// MARK: - Test Helpers

private func makeTask(
    id: String,
    urgency: Int? = nil,
    project: String? = nil,
    tags: [String] = [],
    dateDue: String? = nil
) -> ApiTask {
    ApiTask(
        dbId: nil,
        uuid: id,
        status: "pending",
        summary: "Task \(id)",
        project: project,
        tags: tags,
        dateCreated: "2024-01-01T00:00:00Z",
        dateCompleted: nil,
        dateDue: dateDue,
        urgency: urgency
    )
}

private func formatDate(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.string(from: date)
}
