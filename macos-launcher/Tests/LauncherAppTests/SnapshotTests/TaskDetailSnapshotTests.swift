@testable import LauncherAppKit
import SnapshotTesting
import SwiftUI
import XCTest

/// Snapshot tests for TaskDetailView to catch visual regressions.
///
/// These tests capture the rendered appearance of the task detail view
/// in various states and layouts.
final class TaskDetailSnapshotTests: SnapshotTestCase {
    // MARK: - Test Setup

    private func makeTask(
        id: String = "test-uuid-1234",
        summary: String = "Test Task Summary",
        status: String = "pending",
        project: String? = "TestProject",
        tags: [String] = ["tag1", "tag2"],
        urgency: Int? = 5,
        dateCreated: String = "2024-01-01T10:00:00Z",
        dateDue: String? = nil,
        dateCompleted: String? = nil
    ) -> ApiTask {
        ApiTask(
            dbId: 1,
            uuid: id,
            status: status,
            summary: summary,
            project: project,
            tags: tags,
            dateCreated: dateCreated,
            dateCompleted: dateCompleted,
            dateDue: dateDue,
            urgency: urgency
        )
    }

    private func makeDetailState(
        taskUUID: String,
        detail: ApiTaskDetail? = nil,
        isLoading: Bool = false,
        errorMessage: String? = nil
    ) -> TaskDetailState {
        var state = TaskDetailState()
        state.taskUUID = taskUUID
        state.detail = detail
        state.isLoading = isLoading
        state.errorMessage = errorMessage
        return state
    }

    private func makeExternalLinksState(
        taskUUID: String,
        links: [ExternalLinkDto] = [],
        isLoading: Bool = false,
        errorMessage: String? = nil
    ) -> ExternalLinksState {
        var state = ExternalLinksState()
        state.taskUUID = taskUUID
        state.links = links
        state.isLoading = isLoading
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
            annotationEditInput: .constant(""),
            projectEditInput: .constant(""),
            tagAddQuery: .constant(""),
            dueDateEditSelection: .constant(Date()),
            importantLinkUrlInput: .constant(""),
            importantLinkTitleInput: .constant("")
        )
    }

    // MARK: - Basic States

    func testTaskDetailDefault() {
        let task = makeTask(
            id: "uuid-123",
            summary: "Review pull request for authentication feature",
            status: "active",
            project: "backend-api",
            tags: ["code-review", "high-priority"]
        )
        let sut = makeSUT(task: task)

        assertViewSnapshot(sut, size: TestSizes.detailViewCompact)
    }

    func testTaskDetailWideLayout() {
        let task = makeTask(
            id: "uuid-123",
            summary: "Implement new dashboard widget",
            status: "pending",
            project: "frontend",
            tags: ["feature", "ui"]
        )
        let sut = makeSUT(task: task)

        assertViewSnapshot(sut, size: TestSizes.detailViewWide)
    }

    // MARK: - Loading States

    func testTaskDetailLoading() {
        let task = makeTask(id: "uuid-123", summary: "Loading task...")
        let detailState = makeDetailState(taskUUID: "uuid-123", isLoading: true)
        let linksState = makeExternalLinksState(taskUUID: "uuid-123", isLoading: true)
        let sut = makeSUT(task: task, detailState: detailState, externalLinksState: linksState)

        assertViewSnapshot(sut, size: TestSizes.detailViewCompact)
    }

    func testTaskDetailWithError() {
        let task = makeTask(id: "uuid-123", summary: "Task with error")
        let detailState = makeDetailState(
            taskUUID: "uuid-123",
            errorMessage: "Failed to load task details"
        )
        let sut = makeSUT(task: task, detailState: detailState)

        assertViewSnapshot(sut, size: TestSizes.detailViewCompact)
    }

    // MARK: - With Annotations

    func testTaskDetailWithAnnotations() {
        let task = makeTask(id: "uuid-123", summary: "Task with annotations")
        let annotations = [
            TaskAnnotationDto(value: "Waiting for QA feedback", time: "2024-01-16T14:30:00Z"),
            TaskAnnotationDto(value: "Initial implementation complete", time: "2024-01-15T10:00:00Z"),
            TaskAnnotationDto(value: "Started working on feature", time: "2024-01-14T09:00:00Z"),
        ]
        let detail = ApiTaskDetail(
            dbId: 1,
            uuid: "uuid-123",
            status: "active",
            summary: "Task with annotations",
            project: "TestProject",
            tags: [],
            dateCreated: "2024-01-14T08:00:00Z",
            dateCompleted: nil,
            dateDue: nil,
            urgency: nil,
            annotations: annotations,
            history: [],
            links: [],
            attachments: []
        )
        let detailState = makeDetailState(taskUUID: "uuid-123", detail: detail)
        let sut = makeSUT(task: task, detailState: detailState)

        assertViewSnapshot(sut, size: CGSize(width: 400, height: 700))
    }

    func testTaskDetailWithNoAnnotations() {
        let task = makeTask(id: "uuid-123", summary: "Task without annotations")
        let detail = TestHelpers.makeTaskDetail(
            id: "uuid-123",
            summary: "Task without annotations",
            annotations: [],
            history: []
        )
        let detailState = makeDetailState(taskUUID: "uuid-123", detail: detail)
        let sut = makeSUT(task: task, detailState: detailState)

        assertViewSnapshot(sut, size: TestSizes.detailViewCompact)
    }

    // MARK: - With History

    func testTaskDetailWithHistory() {
        let task = makeTask(id: "uuid-123", summary: "Task with history")
        let history = [
            TaskHistoryDto(value: "Status changed from 'pending' to 'active'", datetime: "2024-01-16T09:00:00Z"),
            TaskHistoryDto(value: "Added tag 'high-priority'", datetime: "2024-01-15T15:00:00Z"),
            TaskHistoryDto(value: "Task created", datetime: "2024-01-14T08:00:00Z"),
        ]
        let detail = ApiTaskDetail(
            dbId: 1,
            uuid: "uuid-123",
            status: "active",
            summary: "Task with history",
            project: nil,
            tags: [],
            dateCreated: "2024-01-14T08:00:00Z",
            dateCompleted: nil,
            dateDue: nil,
            urgency: nil,
            annotations: [],
            history: history,
            links: [],
            attachments: []
        )
        let detailState = makeDetailState(taskUUID: "uuid-123", detail: detail)
        let sut = makeSUT(task: task, detailState: detailState)

        assertViewSnapshot(sut, size: CGSize(width: 400, height: 700))
    }

    // MARK: - With External Links

    func testTaskDetailWithGitLabLinks() {
        let task = makeTask(id: "uuid-123", summary: "Task with GitLab MR")
        let links = [
            TestHelpers.makeGitLabMRLink(
                iid: 42,
                title: "Add authentication feature",
                state: "opened",
                comments: 12,
                sourceBranch: "feature/auth"
            ),
        ]
        let linksState = makeExternalLinksState(taskUUID: "uuid-123", links: links)
        let sut = makeSUT(task: task, externalLinksState: linksState)

        assertViewSnapshot(sut, size: TestSizes.detailViewCompact)
    }

    func testTaskDetailWithMultipleLinks() {
        let task = makeTask(id: "uuid-123", summary: "Task with multiple links")
        let links = [
            TestHelpers.makeGitLabMRLink(
                id: 1,
                iid: 42,
                title: "Main implementation",
                state: "merged"
            ),
            TestHelpers.makeGitLabMRLink(
                id: 2,
                iid: 43,
                title: "Follow-up fixes",
                state: "opened"
            ),
        ]
        let linksState = makeExternalLinksState(taskUUID: "uuid-123", links: links)
        let sut = makeSUT(task: task, externalLinksState: linksState)

        assertViewSnapshot(sut, size: CGSize(width: 400, height: 700))
    }

    func testTaskDetailWithLinksError() {
        let task = makeTask(id: "uuid-123", summary: "Task with links error")
        let linksState = makeExternalLinksState(
            taskUUID: "uuid-123",
            errorMessage: "Could not fetch external links"
        )
        let sut = makeSUT(task: task, externalLinksState: linksState)

        assertViewSnapshot(sut, size: TestSizes.detailViewCompact)
    }

    // MARK: - Status Variations

    func testTaskDetailPendingStatus() {
        let task = makeTask(id: "uuid-123", summary: "Pending task", status: "pending")
        let sut = makeSUT(task: task)

        assertViewSnapshot(sut, size: TestSizes.detailViewCompact)
    }

    func testTaskDetailActiveStatus() {
        let task = makeTask(id: "uuid-123", summary: "Active task", status: "active")
        let sut = makeSUT(task: task)

        assertViewSnapshot(sut, size: TestSizes.detailViewCompact)
    }

    func testTaskDetailCompletedStatus() {
        let task = makeTask(
            id: "uuid-123",
            summary: "Completed task",
            status: "completed",
            dateCompleted: "2024-01-18T16:30:00Z"
        )
        let sut = makeSUT(task: task)

        assertViewSnapshot(sut, size: TestSizes.detailViewCompact)
    }

    // MARK: - Content Variations

    func testTaskDetailWithNoProject() {
        let task = makeTask(id: "uuid-123", summary: "Task without project", project: nil)
        let sut = makeSUT(task: task)

        assertViewSnapshot(sut, size: TestSizes.detailViewCompact)
    }

    func testTaskDetailWithManyTags() {
        let task = makeTask(
            id: "uuid-123",
            summary: "Task with many tags",
            tags: ["backend", "api", "urgent", "refactor", "performance", "testing"]
        )
        let sut = makeSUT(task: task)

        assertViewSnapshot(sut, size: TestSizes.detailViewCompact)
    }

    func testTaskDetailWithLongSummary() {
        let task = makeTask(
            id: "uuid-123",
            // swiftlint:disable:next line_length
            summary: "This is a very long task summary that spans multiple lines and tests how the view handles wrapping of text content in the header section"
        )
        let sut = makeSUT(task: task)

        assertViewSnapshot(sut, size: TestSizes.detailViewCompact)
    }

    func testTaskDetailWithDueDate() {
        let task = makeTask(
            id: "uuid-123",
            summary: "Task with due date",
            dateDue: "2024-02-01T17:00:00Z"
        )
        let sut = makeSUT(task: task)

        assertViewSnapshot(sut, size: TestSizes.detailViewCompact)
    }

    func testTaskDetailWithHighUrgency() {
        let task = makeTask(
            id: "uuid-123",
            summary: "High urgency task",
            urgency: 15
        )
        let sut = makeSUT(task: task)

        assertViewSnapshot(sut, size: TestSizes.detailViewCompact)
    }

    // MARK: - Full Content

    func testTaskDetailFullContent() {
        let task = makeTask(
            id: "uuid-123",
            summary: "Complete feature implementation",
            status: "active",
            project: "main-app",
            tags: ["feature", "sprint-5"],
            urgency: 8,
            dateDue: "2024-02-15T17:00:00Z"
        )
        let annotations = [
            TaskAnnotationDto(value: "Code review requested", time: "2024-01-17T10:00:00Z"),
        ]
        let history = [
            TaskHistoryDto(value: "Status changed to active", datetime: "2024-01-16T09:00:00Z"),
        ]
        let detail = ApiTaskDetail(
            dbId: 1,
            uuid: "uuid-123",
            status: "active",
            summary: "Complete feature implementation",
            project: "main-app",
            tags: ["feature", "sprint-5"],
            dateCreated: "2024-01-14T08:00:00Z",
            dateCompleted: nil,
            dateDue: "2024-02-15T17:00:00Z",
            urgency: 8,
            annotations: annotations,
            history: history,
            links: [],
            attachments: []
        )
        let links = [
            TestHelpers.makeGitLabMRLink(
                iid: 99,
                title: "Feature implementation MR",
                state: "opened",
                comments: 5
            ),
        ]
        let detailState = makeDetailState(taskUUID: "uuid-123", detail: detail)
        let linksState = makeExternalLinksState(taskUUID: "uuid-123", links: links)
        let sut = makeSUT(task: task, detailState: detailState, externalLinksState: linksState)

        assertViewSnapshot(sut, size: CGSize(width: 500, height: 800))
    }
}
