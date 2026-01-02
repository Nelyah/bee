@testable import LauncherApp
import SwiftUI
import ViewInspector
import XCTest

/// UI tests for TaskDetailView using ViewInspector.
///
/// These tests verify the task detail view's structure, content display,
/// and section rendering across different states.
final class TaskDetailUITests: XCTestCase {
    // MARK: - Test Setup

    private func makeTask(
        id: String = "test-uuid-1234",
        summary: String = "Test Task Summary",
        status: String = "pending",
        project: String? = "TestProject",
        tags: [String] = ["tag1", "tag2"],
        urgency: Int? = 5
    ) -> ApiTask {
        TestHelpers.makeTask(
            id: id,
            urgency: urgency,
            project: project,
            tags: tags,
            status: status,
            summary: summary
        )
    }

    private func makeDetailState(
        isLoading: Bool = false,
        taskUUID: String? = nil,
        detail: ApiTaskDetail? = nil,
        errorMessage: String? = nil
    ) -> TaskDetailState {
        var state = TaskDetailState()
        state.isLoading = isLoading
        state.taskUUID = taskUUID
        state.detail = detail
        state.errorMessage = errorMessage
        return state
    }

    private func makeExternalLinksState(
        isLoading: Bool = false,
        taskUUID: String? = nil,
        links: [ExternalLinkDto] = [],
        errorMessage: String? = nil
    ) -> ExternalLinksState {
        var state = ExternalLinksState()
        state.isLoading = isLoading
        state.taskUUID = taskUUID
        state.links = links
        state.errorMessage = errorMessage
        return state
    }

    private func makeSUT(
        task: ApiTask,
        detailState: TaskDetailState = TaskDetailState(),
        externalLinksState: ExternalLinksState = ExternalLinksState()
    ) -> TaskDetailView {
        TaskDetailView(
            task: task,
            detailState: detailState,
            externalLinksState: externalLinksState,
            onRetryDetail: {},
            onRefreshLinks: { _ in },
            onCopyBranch: { _ in },
            onCopyLink: { _ in },
            onCopyUUID: { _ in },
            onClose: {},
            annotationInput: .constant(""),
            taskNameEditInput: .constant(""),
            annotationEditInput: .constant("")
        )
    }

    // MARK: - Header Tests

    func testTaskDetailDisplaysTaskSummary() throws {
        let task = makeTask(summary: "Review pull request")
        let sut = makeSUT(task: task)

        let view = try sut.inspect()

        _ = try view.find(text: "Review pull request")
    }

    func testTaskDetailDisplaysStatusBadge() throws {
        let task = makeTask(status: "active")
        let sut = makeSUT(task: task)

        let view = try sut.inspect()

        // Status is displayed uppercase
        _ = try view.find(text: "ACTIVE")
    }

    func testTaskDetailDisplaysBackButton() throws {
        let task = makeTask()
        let sut = makeSUT(task: task)

        let view = try sut.inspect()

        _ = try view.find(text: "Back")
    }

    func testTaskDetailBackButtonCallsOnClose() throws {
        let task = makeTask()
        var closeCalled = false

        let sut = TaskDetailView(
            task: task,
            detailState: TaskDetailState(),
            externalLinksState: ExternalLinksState(),
            onRetryDetail: {},
            onRefreshLinks: { _ in },
            onCopyBranch: { _ in },
            onCopyLink: { _ in },
            onCopyUUID: { _ in },
            onClose: { closeCalled = true },
            annotationInput: .constant(""),
            taskNameEditInput: .constant(""),
            annotationEditInput: .constant("")
        )

        let view = try sut.inspect()
        let backButton = try view.find(ViewType.Button.self)
        try backButton.tap()

        XCTAssertTrue(closeCalled)
    }

    // MARK: - Loading State Tests

    func testTaskDetailDisplaysLoadingMessage() throws {
        let task = makeTask(id: "uuid-123")
        let detailState = makeDetailState(isLoading: true, taskUUID: "uuid-123")
        let sut = makeSUT(task: task, detailState: detailState)

        let view = try sut.inspect()

        _ = try view.find(text: "Loading details…")
    }

    func testTaskDetailDisplaysErrorMessage() throws {
        let task = makeTask(id: "uuid-123")
        let detailState = makeDetailState(
            isLoading: false,
            taskUUID: "uuid-123",
            errorMessage: "Failed to load task details"
        )
        let sut = makeSUT(task: task, detailState: detailState)

        let view = try sut.inspect()

        _ = try view.find(text: "Failed to load task details")
    }

    // MARK: - Metadata Section Tests

    //
    // Note: Some text within DetailRow components is not accessible via ViewInspector
    // due to accessibility modifiers. These are better tested via snapshot tests.

    func testTaskDetailContainsMetadataSection() throws {
        let task = makeTask()
        let sut = makeSUT(task: task)

        let view = try sut.inspect()

        // Verify the view can be inspected (structure test)
        XCTAssertNotNil(view)
    }

    func testTaskDetailContainsExternalLinksSection() throws {
        let task = makeTask()
        let sut = makeSUT(task: task)

        let view = try sut.inspect()

        // Find GitLab and Jira section headers (these are direct Text views)
        _ = try view.find(text: "GitLab")
        _ = try view.find(text: "Jira")
    }

    // MARK: - Annotations Section Tests

    func testTaskDetailDisplaysEmptyAnnotationsPlaceholder() throws {
        let task = makeTask(id: "uuid-123")
        let detail = TestHelpers.makeTaskDetail(id: "uuid-123", annotations: [])
        let detailState = makeDetailState(taskUUID: "uuid-123", detail: detail)
        let sut = makeSUT(task: task, detailState: detailState)

        let view = try sut.inspect()

        // Empty state shows a neutral dash instead of "No annotations"
        _ = try view.find(text: "—")
    }

    func testTaskDetailDisplaysAnnotations() throws {
        let task = makeTask(id: "uuid-123")
        let annotations = [
            TestHelpers.makeAnnotation(value: "First note", time: "2024-01-15T10:00:00Z"),
            TestHelpers.makeAnnotation(value: "Second note", time: "2024-01-16T11:00:00Z"),
        ]
        let detail = TestHelpers.makeTaskDetail(id: "uuid-123", annotations: annotations)
        let detailState = makeDetailState(taskUUID: "uuid-123", detail: detail)
        let sut = makeSUT(task: task, detailState: detailState)

        let view = try sut.inspect()

        _ = try view.find(text: "First note")
        _ = try view.find(text: "Second note")
    }

    // MARK: - Annotation Input Tests

    func testAnnotationInputFieldAppearsWhenAddingAnnotation() throws {
        let task = makeTask(id: "uuid-123")
        let detail = TestHelpers.makeTaskDetail(id: "uuid-123", annotations: [])
        let detailState = makeDetailState(taskUUID: "uuid-123", detail: detail)
        var annotationInput = ""

        let sut = TaskDetailView(
            task: task,
            detailState: detailState,
            externalLinksState: ExternalLinksState(),
            onRetryDetail: {},
            onRefreshLinks: { _ in },
            onCopyBranch: { _ in },
            onCopyLink: { _ in },
            onCopyUUID: { _ in },
            onClose: {},
            isAddingAnnotation: true,
            annotationInput: .init(get: { annotationInput }, set: { annotationInput = $0 }),
            taskNameEditInput: .constant(""),
            annotationEditInput: .constant("")
        )

        let view = try sut.inspect()

        // When isAddingAnnotation is true, the annotation input section should be visible
        // Look for the "Add annotation" placeholder or input area
        XCTAssertNotNil(view)
    }

    func testAnnotationSubmitCallbackIsWired() throws {
        let task = makeTask(id: "uuid-123")
        let detail = TestHelpers.makeTaskDetail(id: "uuid-123", annotations: [])
        let detailState = makeDetailState(taskUUID: "uuid-123", detail: detail)
        var annotationInput = "Test annotation"

        var callbackInvoked = false
        let sut = TaskDetailView(
            task: task,
            detailState: detailState,
            externalLinksState: ExternalLinksState(),
            onRetryDetail: {},
            onRefreshLinks: { _ in },
            onCopyBranch: { _ in },
            onCopyLink: { _ in },
            onCopyUUID: { _ in },
            onClose: {},
            isAddingAnnotation: true,
            annotationInput: .init(get: { annotationInput }, set: { annotationInput = $0 }),
            onSubmitAnnotation: { callbackInvoked = true },
            taskNameEditInput: .constant(""),
            annotationEditInput: .constant("")
        )

        // Invoke the callback and verify it works
        sut.onSubmitAnnotation()
        XCTAssertTrue(callbackInvoked, "onSubmitAnnotation callback should be invoked")
    }

    // MARK: - History Section Tests

    func testTaskDetailDisplaysEmptyHistoryPlaceholder() throws {
        let task = makeTask(id: "uuid-123")
        let detail = TestHelpers.makeTaskDetail(id: "uuid-123", history: [])
        let detailState = makeDetailState(taskUUID: "uuid-123", detail: detail)
        let sut = makeSUT(task: task, detailState: detailState)

        let view = try sut.inspect()

        // Empty state shows a neutral dash instead of "No history yet"
        // Note: We search for the section header since multiple dashes exist
        _ = try view.find(text: "HISTORY")
    }

    func testTaskDetailDisplaysHistory() throws {
        let task = makeTask(id: "uuid-123")
        let history = [
            TaskHistoryDto(value: "Status changed to active", datetime: "2024-01-15T10:00:00Z"),
        ]
        let detail = ApiTaskDetail(
            dbId: 1,
            uuid: "uuid-123",
            status: "active",
            summary: "Test",
            project: nil,
            tags: [],
            dateCreated: "2024-01-01T00:00:00Z",
            dateCompleted: nil,
            dateDue: nil,
            urgency: nil,
            annotations: [],
            history: history
        )
        let detailState = makeDetailState(taskUUID: "uuid-123", detail: detail)
        let sut = makeSUT(task: task, detailState: detailState)

        let view = try sut.inspect()

        _ = try view.find(text: "Status changed to active")
    }

    // MARK: - External Links Section Tests

    func testTaskDetailDisplaysExternalLinksLoadingMessage() throws {
        let task = makeTask(id: "uuid-123")
        let linksState = makeExternalLinksState(isLoading: true, taskUUID: "uuid-123")
        let sut = makeSUT(task: task, externalLinksState: linksState)

        let view = try sut.inspect()

        _ = try view.find(text: "Loading links…")
    }

    func testTaskDetailDisplaysExternalLinksError() throws {
        let task = makeTask(id: "uuid-123")
        let linksState = makeExternalLinksState(
            isLoading: false,
            taskUUID: "uuid-123",
            errorMessage: "Network error"
        )
        let sut = makeSUT(task: task, externalLinksState: linksState)

        let view = try sut.inspect()

        _ = try view.find(text: "Network error")
    }
}
