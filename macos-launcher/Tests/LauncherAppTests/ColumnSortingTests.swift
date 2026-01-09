@testable import LauncherAppKit
import XCTest

/// Tests for column sorting functionality.
///
/// These tests verify that tasks are correctly sorted by different columns,
/// including proper case-insensitive string sorting and date ordering.
///
/// Note: These tests use `NoGroupingStrategy()` to test global column sorting
/// without interference from task grouping.
@MainActor
final class ColumnSortingTests: XCTestCase {
    // MARK: - Helper

    /// Create a ViewModel configured for sorting tests (no grouping).
    private func makeSortingViewModel() -> LauncherViewModel {
        let viewModel = LauncherViewModel(apiClient: MockApiClient())
        // Disable grouping so column sorting works globally
        viewModel.groupingStrategy = NoGroupingStrategy()
        return viewModel
    }

    // MARK: - Summary Column Tests

    func testSortBySummaryCaseInsensitiveAscending() {
        // This test verifies case-insensitive sorting where:
        // - "Analyze" should come before "API" (because "An" < "AP")
        // - Uppercase and lowercase should be interleaved alphabetically
        let viewModel = makeSortingViewModel()
        viewModel.tasks = [
            makeTask(id: "1", summary: "API endpoint"),
            makeTask(id: "2", summary: "feature request"),
            makeTask(id: "3", summary: "Analyze data"),
            makeTask(id: "4", summary: "integration test"),
            makeTask(id: "5", summary: "user feedback"),
            makeTask(id: "6", summary: "Analyze code"),
        ]

        // Set sort state to ascending by summary
        viewModel.sortState = ColumnSortState(column: "summary", direction: .ascending)

        // Wait for Combine pipeline to update groupedRows
        let expectation = XCTestExpectation(description: "Wait for groupedRows update")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        let sortedSummaries = viewModel.groupedRows.compactMap { row -> String? in
            guard case let .task(item) = row else { return nil }
            return item.task.summary
        }

        // Case-insensitive sort: "Analyze code" < "Analyze data" < "API endpoint" < "feature" < "integration" < "user"
        XCTAssertEqual(sortedSummaries, [
            "Analyze code",
            "Analyze data",
            "API endpoint",
            "feature request",
            "integration test",
            "user feedback",
        ])
    }

    func testSortBySummaryCaseInsensitiveDescending() {
        let viewModel = makeSortingViewModel()
        viewModel.tasks = [
            makeTask(id: "1", summary: "API endpoint"),
            makeTask(id: "2", summary: "feature request"),
            makeTask(id: "3", summary: "Analyze data"),
        ]

        viewModel.sortState = ColumnSortState(column: "summary", direction: .descending)

        let expectation = XCTestExpectation(description: "Wait for groupedRows update")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        let sortedSummaries = viewModel.groupedRows.compactMap { row -> String? in
            guard case let .task(item) = row else { return nil }
            return item.task.summary
        }

        // Descending: "feature" > "API" > "Analyze"
        XCTAssertEqual(sortedSummaries, [
            "feature request",
            "API endpoint",
            "Analyze data",
        ])
    }

    // MARK: - Status Column Tests

    func testSortByStatusAscending() {
        let viewModel = makeSortingViewModel()
        viewModel.tasks = [
            makeTask(id: "1", status: "pending"),
            makeTask(id: "2", status: "completed"),
            makeTask(id: "3", status: "active"),
            makeTask(id: "4", status: "blocked"),
        ]

        viewModel.sortState = ColumnSortState(column: "status", direction: .ascending)

        let expectation = XCTestExpectation(description: "Wait for groupedRows update")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        let sortedStatuses = viewModel.groupedRows.compactMap { row -> String? in
            guard case let .task(item) = row else { return nil }
            return item.task.status
        }

        XCTAssertEqual(sortedStatuses, ["active", "blocked", "completed", "pending"])
    }

    // MARK: - Project Column Tests

    func testSortByProjectCaseInsensitiveWithNilLast() {
        let viewModel = makeSortingViewModel()
        viewModel.tasks = [
            makeTask(id: "1", project: nil),
            makeTask(id: "2", project: "Work"),
            makeTask(id: "3", project: "personal"),
            makeTask(id: "4", project: "Hobby"),
        ]

        viewModel.sortState = ColumnSortState(column: "project", direction: .ascending)

        let expectation = XCTestExpectation(description: "Wait for groupedRows update")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Extract task IDs in sorted order to verify correct ordering
        let sortedIds = viewModel.groupedRows.compactMap { row -> String? in
            guard case let .task(item) = row else { return nil }
            return item.task.uuid
        }

        // Case-insensitive: "Hobby" < "personal" < "Work", nil last
        // Expected order: task 4 (Hobby), task 3 (personal), task 2 (Work), task 1 (nil)
        XCTAssertEqual(sortedIds, ["4", "3", "2", "1"])
    }

    // MARK: - Tags Column Tests

    func testSortByTagsFirstTagAlphabetically() {
        let viewModel = makeSortingViewModel()
        viewModel.tasks = [
            makeTask(id: "1", tags: ["work", "urgent"]),
            makeTask(id: "2", tags: ["home"]),
            makeTask(id: "3", tags: ["Work"]), // Same as "work" case-insensitive
            makeTask(id: "4", tags: []),
        ]

        viewModel.sortState = ColumnSortState(column: "tags", direction: .ascending)

        let expectation = XCTestExpectation(description: "Wait for groupedRows update")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        let sortedTasks = viewModel.groupedRows.compactMap { row -> String? in
            guard case let .task(item) = row else { return nil }
            return item.task.uuid
        }

        // home < Work/work (case-insensitive), empty tags last
        XCTAssertEqual(sortedTasks[0], "2") // home
        XCTAssertTrue(sortedTasks[1] == "1" || sortedTasks[1] == "3") // work/Work
        XCTAssertTrue(sortedTasks[2] == "1" || sortedTasks[2] == "3") // work/Work
        XCTAssertEqual(sortedTasks[3], "4") // empty tags
    }

    // MARK: - Date Column Tests

    func testSortByDateCreatedAscending() {
        let viewModel = makeSortingViewModel()
        viewModel.tasks = [
            makeTask(id: "1", dateCreated: "2024-03-15T00:00:00Z"),
            makeTask(id: "2", dateCreated: "2024-01-01T00:00:00Z"),
            makeTask(id: "3", dateCreated: "2024-02-20T00:00:00Z"),
        ]

        viewModel.sortState = ColumnSortState(column: "date_created", direction: .ascending)

        let expectation = XCTestExpectation(description: "Wait for groupedRows update")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        let sortedIds = viewModel.groupedRows.compactMap { row -> String? in
            guard case let .task(item) = row else { return nil }
            return item.task.uuid
        }

        XCTAssertEqual(sortedIds, ["2", "3", "1"]) // Jan < Feb < Mar
    }

    func testSortByDateDueWithNilLast() {
        let viewModel = makeSortingViewModel()
        viewModel.tasks = [
            makeTask(id: "1", dateDue: nil),
            makeTask(id: "2", dateDue: "2024-12-31"),
            makeTask(id: "3", dateDue: "2024-06-15"),
        ]

        viewModel.sortState = ColumnSortState(column: "date_due", direction: .ascending)

        let expectation = XCTestExpectation(description: "Wait for groupedRows update")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        let sortedIds = viewModel.groupedRows.compactMap { row -> String? in
            guard case let .task(item) = row else { return nil }
            return item.task.uuid
        }

        // June < December, nil last
        XCTAssertEqual(sortedIds, ["3", "2", "1"])
    }

    // MARK: - Urgency Column Tests

    func testSortByUrgencyAscending() {
        let viewModel = makeSortingViewModel()
        viewModel.tasks = [
            makeTask(id: "1", urgency: 5),
            makeTask(id: "2", urgency: nil),
            makeTask(id: "3", urgency: 10),
            makeTask(id: "4", urgency: 1),
        ]

        viewModel.sortState = ColumnSortState(column: "urgency", direction: .ascending)

        let expectation = XCTestExpectation(description: "Wait for groupedRows update")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        let sortedIds = viewModel.groupedRows.compactMap { row -> String? in
            guard case let .task(item) = row else { return nil }
            return item.task.uuid
        }

        // 1 < 5 < 10, nil last
        XCTAssertEqual(sortedIds, ["4", "1", "3", "2"])
    }

    // MARK: - UUID Column Tests

    func testSortByUuidAscending() {
        let viewModel = makeSortingViewModel()
        viewModel.tasks = [
            makeTask(id: "charlie"),
            makeTask(id: "alpha"),
            makeTask(id: "bravo"),
        ]

        viewModel.sortState = ColumnSortState(column: "uuid", direction: .ascending)

        let expectation = XCTestExpectation(description: "Wait for groupedRows update")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        let sortedIds = viewModel.groupedRows.compactMap { row -> String? in
            guard case let .task(item) = row else { return nil }
            return item.task.uuid
        }

        XCTAssertEqual(sortedIds, ["alpha", "bravo", "charlie"])
    }

    // MARK: - Default Sort (Urgency Descending)

    func testDefaultSortByUrgencyDescending() {
        let viewModel = makeSortingViewModel()
        viewModel.tasks = [
            makeTask(id: "1", urgency: 1),
            makeTask(id: "2", urgency: 10),
            makeTask(id: "3", urgency: 5),
        ]

        // No sortState means default urgency descending
        viewModel.sortState = nil

        let expectation = XCTestExpectation(description: "Wait for groupedRows update")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        let sortedIds = viewModel.groupedRows.compactMap { row -> String? in
            guard case let .task(item) = row else { return nil }
            return item.task.uuid
        }

        // Urgency descending: 10 > 5 > 1
        XCTAssertEqual(sortedIds, ["2", "3", "1"])
    }

    // MARK: - Toggle Sort Cycle Tests

    func testToggleSortCyclesAscendingDescendingDefault() {
        let viewModel = makeSortingViewModel()

        // Start with nil (default urgency sort)
        XCTAssertNil(viewModel.sortState)

        // First click: ascending
        viewModel.toggleSort(for: "summary")
        XCTAssertEqual(viewModel.sortState?.column, "summary")
        XCTAssertEqual(viewModel.sortState?.direction, .ascending)

        // Second click: descending
        viewModel.toggleSort(for: "summary")
        XCTAssertEqual(viewModel.sortState?.column, "summary")
        XCTAssertEqual(viewModel.sortState?.direction, .descending)

        // Third click: back to nil (urgency)
        viewModel.toggleSort(for: "summary")
        XCTAssertNil(viewModel.sortState)
    }

    func testToggleSortDifferentColumnStartsAscending() {
        let viewModel = makeSortingViewModel()

        // Set to descending on summary
        viewModel.sortState = ColumnSortState(column: "summary", direction: .descending)

        // Click different column: starts at ascending
        viewModel.toggleSort(for: "status")
        XCTAssertEqual(viewModel.sortState?.column, "status")
        XCTAssertEqual(viewModel.sortState?.direction, .ascending)
    }

    // MARK: - Real-World Scenario Tests

    /// Test the exact scenario from the screenshot: tasks with various summaries
    /// should sort alphabetically, with "API endpoint" coming before "for task".
    func testRealWorldSummarySortAscending() {
        let viewModel = makeSortingViewModel()

        // Tasks matching the screenshot - "for task #N" should come AFTER "feature"
        // because 'fo' > 'fe' alphabetically
        viewModel.tasks = [
            makeTask(id: "1", summary: "for task #116"),
            makeTask(id: "2", summary: "for task #292"),
            makeTask(id: "3", summary: "for task #84"),
            makeTask(id: "4", summary: "API endpoint for task #188"),
            makeTask(id: "5", summary: "code review for task #258"),
            makeTask(id: "6", summary: "database schema for task #197"),
            makeTask(id: "7", summary: "feature for task #177"),
            makeTask(id: "8", summary: "integration for task #270"),
            makeTask(id: "9", summary: "meeting notes for task #102"),
            makeTask(id: "10", summary: "report for task #223"),
            makeTask(id: "11", summary: "unit tests for task #128"),
        ]

        // Sort by summary ascending
        viewModel.sortState = ColumnSortState(column: "summary", direction: .ascending)

        let expectation = XCTestExpectation(description: "Wait for groupedRows update")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        let sortedSummaries = viewModel.groupedRows.compactMap { row -> String? in
            guard case let .task(item) = row else { return nil }
            return item.task.summary
        }

        // Correct alphabetical order (case-insensitive):
        // "API endpoint" < "code review" < "database schema" < "feature" < "for task" < "integration" < "meeting" <
        // "report" < "unit"
        XCTAssertEqual(sortedSummaries, [
            "API endpoint for task #188",
            "code review for task #258",
            "database schema for task #197",
            "feature for task #177",
            "for task #116",
            "for task #292",
            "for task #84",
            "integration for task #270",
            "meeting notes for task #102",
            "report for task #223",
            "unit tests for task #128",
        ])
    }

    /// Test sorting with default ProjectGroupingStrategy (real app behavior).
    /// All tasks with same project should still sort correctly by column.
    func testSortWithProjectGrouping() {
        // Use default ViewModel with ProjectGroupingStrategy
        let viewModel = LauncherViewModel(apiClient: MockApiClient())

        // All tasks have same project (nil), so they're in one group
        viewModel.tasks = [
            makeTask(id: "1", summary: "zebra"),
            makeTask(id: "2", summary: "alpha"),
            makeTask(id: "3", summary: "beta"),
        ]

        viewModel.sortState = ColumnSortState(column: "summary", direction: .ascending)

        let expectation = XCTestExpectation(description: "Wait for groupedRows update")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        let sortedSummaries = viewModel.groupedRows.compactMap { row -> String? in
            guard case let .task(item) = row else { return nil }
            return item.task.summary
        }

        // Even with grouping, tasks in same group should be sorted
        XCTAssertEqual(sortedSummaries, ["alpha", "beta", "zebra"])
    }

    /// Test that toggleSort via UI interaction triggers correct sorting.
    func testToggleSortTriggersSorting() {
        let viewModel = makeSortingViewModel()
        viewModel.tasks = [
            makeTask(id: "1", summary: "zebra"),
            makeTask(id: "2", summary: "alpha"),
            makeTask(id: "3", summary: "beta"),
        ]

        // Initially no sort state (urgency sort)
        XCTAssertNil(viewModel.sortState)

        // Click summary column header
        viewModel.toggleSort(for: "summary")

        let expectation = XCTestExpectation(description: "Wait for groupedRows update")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        let sortedSummaries = viewModel.groupedRows.compactMap { row -> String? in
            guard case let .task(item) = row else { return nil }
            return item.task.summary
        }

        // Should be ascending after first click
        XCTAssertEqual(viewModel.sortState?.direction, .ascending)
        XCTAssertEqual(sortedSummaries, ["alpha", "beta", "zebra"])
    }

    /// Test sorting with ProjectGroupingStrategy using exact screenshot data.
    /// This simulates real app behavior with tasks in the same project group.
    func testRealWorldSummarySortWithProjectGrouping() {
        // Use default ViewModel with ProjectGroupingStrategy (same as real app)
        let viewModel = LauncherViewModel(apiClient: MockApiClient())

        // Same data from user's screenshot - all tasks have nil project (same group)
        viewModel.tasks = [
            makeTask(id: "1", summary: "for task #116"),
            makeTask(id: "2", summary: "for task #292"),
            makeTask(id: "3", summary: "for task #84"),
            makeTask(id: "4", summary: "API endpoint for task #188"),
            makeTask(id: "5", summary: "code review for task #258"),
            makeTask(id: "6", summary: "database schema for task #197"),
            makeTask(id: "7", summary: "feature for task #177"),
        ]

        viewModel.sortState = ColumnSortState(column: "summary", direction: .ascending)

        let expectation = XCTestExpectation(description: "Wait for groupedRows update")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        let sortedSummaries = viewModel.groupedRows.compactMap { row -> String? in
            guard case let .task(item) = row else { return nil }
            return item.task.summary
        }

        // With all tasks in same project (nil), sorting should work correctly
        XCTAssertEqual(sortedSummaries, [
            "API endpoint for task #188",
            "code review for task #258",
            "database schema for task #197",
            "feature for task #177",
            "for task #116",
            "for task #292",
            "for task #84",
        ], "Tasks in same project group should be sorted alphabetically by summary")
    }

    /// Test sorting with tasks in DIFFERENT project groups.
    /// When grouping is enabled, tasks are sorted WITHIN each group, not globally.
    /// Groups themselves are sorted by project name.
    func testSortWithDifferentProjectGroups() {
        // Use default ViewModel with ProjectGroupingStrategy
        let viewModel = LauncherViewModel(apiClient: MockApiClient())

        // Tasks in different projects
        viewModel.tasks = [
            makeTask(id: "1", summary: "zebra", project: "ProjectA"),
            makeTask(id: "2", summary: "apple", project: "ProjectB"),
            makeTask(id: "3", summary: "banana", project: "ProjectA"),
            makeTask(id: "4", summary: "cherry", project: "ProjectB"),
        ]

        viewModel.sortState = ColumnSortState(column: "summary", direction: .ascending)

        let expectation = XCTestExpectation(description: "Wait for groupedRows update")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Extract summaries preserving group order
        let summaries = viewModel.groupedRows.compactMap { row -> String? in
            guard case let .task(item) = row else { return nil }
            return item.task.summary
        }

        // With ProjectGroupingStrategy:
        // - ProjectA comes before ProjectB (alphabetically)
        // - Within ProjectA: banana, zebra (sorted ascending)
        // - Within ProjectB: apple, cherry (sorted ascending)
        // So the order is: banana, zebra, apple, cherry
        // NOT: apple, banana, cherry, zebra (which would be global sort)
        XCTAssertEqual(
            summaries,
            ["banana", "zebra", "apple", "cherry"],
            "Tasks should be sorted within their project groups, not globally"
        )
    }

    /// Test sorting with NoGroupingStrategy produces global sort order.
    func testSortWithNoGroupingStrategy() {
        let viewModel = makeSortingViewModel() // Uses NoGroupingStrategy

        viewModel.tasks = [
            makeTask(id: "1", summary: "zebra", project: "ProjectA"),
            makeTask(id: "2", summary: "apple", project: "ProjectB"),
            makeTask(id: "3", summary: "banana", project: "ProjectA"),
            makeTask(id: "4", summary: "cherry", project: "ProjectB"),
        ]

        viewModel.sortState = ColumnSortState(column: "summary", direction: .ascending)

        let expectation = XCTestExpectation(description: "Wait for sortedTasks update")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // With NoGroupingStrategy, groupedRows contains only task rows (no headers)
        let sortedSummaries = viewModel.groupedRows.compactMap { row -> String? in
            guard case let .task(item) = row else { return nil }
            return item.task.summary
        }

        // With NoGroupingStrategy, tasks are sorted globally regardless of project
        XCTAssertEqual(
            sortedSummaries,
            ["apple", "banana", "cherry", "zebra"],
            "Without grouping, tasks should be sorted globally by summary"
        )
    }
}

// MARK: - Helper

private func makeTask(
    id: String,
    summary: String? = nil,
    status: String = "pending",
    project: String? = nil,
    tags: [String] = [],
    urgency: Int? = nil,
    dateCreated: String = "2024-01-01T00:00:00Z",
    dateDue: String? = nil
) -> ApiTask {
    TestHelpers.makeTask(
        id: id,
        urgency: urgency,
        project: project,
        tags: tags,
        dateDue: dateDue,
        status: status,
        summary: summary,
        dateCreated: dateCreated
    )
}
