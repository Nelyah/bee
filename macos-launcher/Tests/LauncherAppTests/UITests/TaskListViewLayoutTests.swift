@testable import LauncherApp
import SwiftUI
import XCTest

// MARK: - Test Wrapper View

/// A wrapper view that measures TaskListView's intrinsic content width.
///
/// Uses `fixedSize()` to let the content expand to its natural size,
/// then measures that size. This reveals if the content wants to be
/// wider than the intended container.
private struct IntrinsicWidthTestView: View {
    @ObservedObject var viewModel: LauncherViewModel
    let onIntrinsicWidthCapture: (CGFloat) -> Void

    var body: some View {
        // Let TaskListView expand to its intrinsic/natural width
        TaskListView(viewModel: viewModel, completion: viewModel.completion)
            .fixedSize(horizontal: true, vertical: false)
            .frame(height: 400)
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            DispatchQueue.main.async {
                                onIntrinsicWidthCapture(geometry.size.width)
                            }
                        }
                }
            )
    }
}

// MARK: - Layout Tests

/// Layout tests for TaskListView that verify the search bar stays within container bounds.
///
/// These tests use GeometryReader to capture actual rendered dimensions and verify
/// that the view layout adapts correctly to container constraints.
@MainActor
final class TaskListViewLayoutTests: XCTestCase {
    // MARK: - Test Setup

    private var viewModel: LauncherViewModel!
    private var mockApiClient: MockApiClient!

    override func setUp() async throws {
        try await super.setUp()
        mockApiClient = MockApiClient()
        viewModel = LauncherViewModel(apiClient: mockApiClient)
        viewModel.reportConfig = MockApiClient.sampleConfig.report
        viewModel.availableReports = MockApiClient.sampleConfig.reports
    }

    override func tearDown() async throws {
        viewModel = nil
        mockApiClient = nil
        try await super.tearDown()
    }

    // MARK: - Layout Regression Tests

    /// Regression test: Search bar should not exceed container width when columns have large custom widths.
    ///
    /// **Bug:** When columns have large fixed widths (e.g., 400px) and the window is smaller,
    /// the search bar expands beyond the visible bounds.
    ///
    /// **Expected behavior:** Search bar should stay within the container width.
    func testSearchBarWidthWithWideColumns() async throws {
        // GIVEN: Column configs with a very wide column (400px)
        viewModel.columnConfigs = [
            ColumnConfig(key: "id", displayName: "ID", width: 100),
            ColumnConfig(key: "summary", displayName: "Summary", width: nil), // flex
            ColumnConfig(key: "date_created", displayName: "Created", width: 400), // WIDE
        ]
        viewModel.tasks = [
            TestHelpers.makeTask(id: "1", summary: "Test task"),
        ]

        // WHEN: Measure the intrinsic width (what TaskListView wants to be)
        let desiredContainerWidth: CGFloat = 400
        var intrinsicWidth: CGFloat = 0

        let expectation = XCTestExpectation(description: "Intrinsic width captured")

        let testView = IntrinsicWidthTestView(viewModel: viewModel) { width in
            intrinsicWidth = width
            expectation.fulfill()
        }

        // Host the view to trigger layout
        let hostingController = NSHostingController(rootView: testView)
        hostingController.view.frame = NSRect(x: 0, y: 0, width: 1000, height: 400)

        // Force layout
        hostingController.view.layoutSubtreeIfNeeded()

        // Wait for geometry to be captured
        await fulfillment(of: [expectation], timeout: 2.0)

        // THEN: The intrinsic width should NOT exceed the desired container width
        // This test FAILS before the fix because the view expands to ~660px
        XCTAssertLessThanOrEqual(
            intrinsicWidth,
            desiredContainerWidth,
            """
            LAYOUT BUG: TaskListView intrinsic width (\(intrinsicWidth)) exceeds container (\(desiredContainerWidth)).

            When columns have large fixed widths (400px), TaskListView's search bar expands
            to accommodate them, extending beyond the visible window bounds.

            Expected: Search bar constrained to container width.
            Actual: Search bar expands to match column content width.
            """
        )
    }

    /// Verifies search bar layout when total column widths exceed container.
    func testSearchBarLayoutWhenColumnsExceedContainer() async throws {
        // GIVEN: Multiple wide columns that together exceed container (total: 800px)
        viewModel.columnConfigs = [
            ColumnConfig(key: "id", displayName: "ID", width: 150),
            ColumnConfig(key: "status", displayName: "Status", width: 150),
            ColumnConfig(key: "summary", displayName: "Summary", width: 300),
            ColumnConfig(key: "tags", displayName: "Tags", width: 200),
        ]
        viewModel.tasks = [
            TestHelpers.makeTask(id: "1", summary: "Test task"),
        ]

        // WHEN: Measure intrinsic width
        let desiredContainerWidth: CGFloat = 500
        var intrinsicWidth: CGFloat = 0

        let expectation = XCTestExpectation(description: "Intrinsic width captured")

        let testView = IntrinsicWidthTestView(viewModel: viewModel) { width in
            intrinsicWidth = width
            expectation.fulfill()
        }

        let hostingController = NSHostingController(rootView: testView)
        hostingController.view.frame = NSRect(x: 0, y: 0, width: 1000, height: 400)
        hostingController.view.layoutSubtreeIfNeeded()

        await fulfillment(of: [expectation], timeout: 2.0)

        // THEN: The intrinsic width should NOT exceed the desired container width
        // This test FAILS before the fix because the view expands to ~674px
        XCTAssertLessThanOrEqual(
            intrinsicWidth,
            desiredContainerWidth,
            """
            LAYOUT BUG: TaskListView intrinsic width (\(intrinsicWidth)) exceeds container (\(desiredContainerWidth)).

            Total column widths (800px) cause TaskListView to expand beyond container (500px).
            Expected: Search bar constrained to container, columns scroll if needed.
            Actual: Entire TaskListView expands to fit column widths.
            """
        )
    }
}
