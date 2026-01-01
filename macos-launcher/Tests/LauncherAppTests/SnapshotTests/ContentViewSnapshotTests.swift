@testable import LauncherApp
import SnapshotTesting
import SwiftUI
import XCTest

/// Snapshot tests for ContentView in various states.
///
/// Tests the root application view including mode switching,
/// overlays, and full window appearance.
@MainActor
final class ContentViewSnapshotTests: SnapshotTestCase {
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

    // MARK: - List Mode

    func testListModeDefault() {
        viewModel.mode = .list
        viewModel.tasks = []
        let view = makeContentView()
        assertViewSnapshot(view, size: TestSizes.contentView)
    }

    func testListModeWithTasks() {
        viewModel.mode = .list
        viewModel.tasks = MockApiClient.sampleTasks
        let view = makeContentView()
        assertViewSnapshot(view, size: TestSizes.contentView)
    }

    func testListModeWithSearchInput() {
        viewModel.mode = .list
        viewModel.tasks = MockApiClient.sampleTasks
        viewModel.input = "list +work"
        viewModel.tokens = [
            TokenSpan(tokenType: .wordString, literal: "list", start: 0, end: 4),
            TokenSpan(tokenType: .blank, literal: " ", start: 4, end: 5),
            TokenSpan(tokenType: .tagPlusPrefix, literal: "+", start: 5, end: 6),
            TokenSpan(tokenType: .wordString, literal: "work", start: 6, end: 10),
        ]
        viewModel.actionName = "list"
        let view = makeContentView()
        assertViewSnapshot(view, size: TestSizes.contentView)
    }

    // MARK: - Detail Mode

    func testDetailModeWithTask() {
        viewModel.tasks = MockApiClient.sampleTasks
        viewModel.selectedIndex = 0
        viewModel.mode = .detail
        viewModel.taskDetailState = TaskDetailState(
            isLoading: false,
            taskUUID: MockApiClient.sampleTasks[0].uuid,
            detail: MockApiClient.sampleTaskDetail
        )
        viewModel.externalLinksState = ExternalLinksState(
            isLoading: false,
            taskUUID: MockApiClient.sampleTasks[0].uuid,
            links: MockApiClient.sampleExternalLinks
        )
        let view = makeContentView()
        assertViewSnapshot(view, size: CGSize(width: 800, height: 600))
    }

    func testDetailModeLoading() {
        viewModel.tasks = MockApiClient.sampleTasks
        viewModel.selectedIndex = 0
        viewModel.mode = .detail
        viewModel.taskDetailState = TaskDetailState(isLoading: true)
        let view = makeContentView()
        assertViewSnapshot(view, size: TestSizes.contentView)
    }

    // MARK: - Toasts

    func testWithToasts() {
        viewModel.mode = .list
        viewModel.tasks = MockApiClient.sampleTasks
        viewModel.toasts = [
            ToastMessage(id: UUID(), message: "Branch copied to clipboard", icon: .success),
        ]
        let view = makeContentView()
        assertViewSnapshot(view, size: TestSizes.contentView)
    }

    func testWithMultipleToasts() {
        viewModel.mode = .list
        viewModel.tasks = MockApiClient.sampleTasks
        viewModel.toasts = [
            ToastMessage(id: UUID(), message: "Task completed!", icon: .success),
            ToastMessage(id: UUID(), message: "Syncing links...", icon: .gitlab),
        ]
        let view = makeContentView()
        assertViewSnapshot(view, size: TestSizes.contentView)
    }

    // MARK: - Command Palette

    func testWithCommandPaletteOpen() {
        viewModel.mode = .list
        viewModel.tasks = MockApiClient.sampleTasks
        // Open command palette using the proper method
        viewModel.openCommandPalette()
        let view = makeContentView()
        assertViewSnapshot(view, size: TestSizes.contentView)
    }

    // MARK: - Hint Bar States

    func testWithInsertModeHints() {
        viewModel.mode = .list
        viewModel.tasks = MockApiClient.sampleTasks
        viewModel.isInsertMode = true
        let view = makeContentView()
        assertViewSnapshot(view, size: TestSizes.contentView)
    }

    func testWithNormalModeHints() {
        viewModel.mode = .list
        viewModel.tasks = MockApiClient.sampleTasks
        viewModel.isInsertMode = false
        let view = makeContentView()
        assertViewSnapshot(view, size: TestSizes.contentView)
    }

    func testWithDetailModeHints() {
        viewModel.tasks = MockApiClient.sampleTasks
        viewModel.selectedIndex = 0
        viewModel.mode = .detail
        viewModel.taskDetailState = TaskDetailState(
            isLoading: false,
            taskUUID: MockApiClient.sampleTasks[0].uuid,
            detail: MockApiClient.sampleTaskDetail
        )
        viewModel.externalLinksState = ExternalLinksState(
            isLoading: false,
            taskUUID: MockApiClient.sampleTasks[0].uuid,
            links: []
        )
        let view = makeContentView()
        assertViewSnapshot(view, size: TestSizes.contentView)
    }

    // MARK: - Helper

    private func makeContentView() -> some View {
        ContentView(viewModel: viewModel)
            .frame(width: 680, height: 440)
    }
}
