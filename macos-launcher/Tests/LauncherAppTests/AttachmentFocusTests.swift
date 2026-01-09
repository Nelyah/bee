import AppKit
@testable import LauncherApp
import XCTest

// MARK: - Attachment Focus Tests

@MainActor
final class AttachmentFocusTests: XCTestCase {
    private var viewModel: LauncherViewModel!

    override func setUp() {
        super.setUp()
        viewModel = LauncherViewModel(apiClient: MockApiClient())
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    // MARK: - Build Focusable Items Tests

    func testBuildDetailFocusableItemsIncludesAttachments() {
        setupDetailModeWithAttachments()

        let attachmentItems = viewModel.detailFocusableItems.filter {
            if case .attachment = $0 { return true }
            return false
        }

        XCTAssertEqual(attachmentItems.count, 1, "Should include 1 attachment from sampleTaskDetail")
    }

    func testBuildDetailFocusableItemsIncludesAddAttachmentButton() {
        setupDetailModeWithAttachments()

        let addButtonItems = viewModel.detailFocusableItems.filter {
            if case .addAttachmentButton = $0 { return true }
            return false
        }

        XCTAssertEqual(addButtonItems.count, 1, "Should include add attachment button")
    }

    func testAttachmentAppearsAfterDueDate() {
        setupDetailModeWithAttachments()

        // Find indices
        let dueDateIndex = viewModel.detailFocusableItems.firstIndex {
            if case .dueDate = $0 { return true }
            return false
        }
        let attachmentIndex = viewModel.detailFocusableItems.firstIndex {
            if case .attachment = $0 { return true }
            return false
        }

        guard let dd = dueDateIndex, let att = attachmentIndex else {
            XCTFail("Both dueDate and attachment should be in focusable items")
            return
        }

        XCTAssertGreaterThan(att, dd, "Attachment should appear after due date")
    }

    // MARK: - Keyboard Navigation Tests

    func testCanNavigateToAttachmentWithJKey() {
        setupDetailModeWithAttachments()

        // Register targets using the new coordinate-based system
        let attachment = MockApiClient.sampleAttachment
        viewModel.navigationRegistry.register(
            .taskName("Test"),
            frame: CGRect(x: 0, y: 0, width: 100, height: 30)
        )
        viewModel.navigationRegistry.register(
            .attachment(attachment),
            frame: CGRect(x: 0, y: 40, width: 100, height: 30)
        )
        viewModel.navigationRegistry.focusFirst()

        // Navigate down to attachment
        let result = viewModel.handleDetailModeAction(.navigate(.down))

        XCTAssertTrue(result)
        if case .attachment = viewModel.navigationRegistry.focusedItem {
            // Success
        } else {
            XCTFail(
                "Focused item should be attachment, got: \(String(describing: viewModel.navigationRegistry.focusedItem))"
            )
        }
    }

    // MARK: - Select Attachment Tests

    func testSelectAttachmentFocusesOnItem() {
        setupDetailModeWithAttachments()
        let attachment = MockApiClient.sampleAttachment

        // Register the attachment in the navigation registry (simulating view registration)
        viewModel.navigationRegistry.register(
            .attachment(attachment),
            frame: CGRect(x: 0, y: 100, width: 200, height: 30)
        )

        viewModel.selectAttachment(attachment)

        // Verify the attachment is now focused via the registry
        XCTAssertEqual(viewModel.navigationRegistry.focusedId, "attachment-\(attachment.id)")
    }

    func testSelectAttachmentActivatesKeyboardNavigation() {
        setupDetailModeWithAttachments()
        let attachment = MockApiClient.sampleAttachment

        // Register the attachment first
        viewModel.navigationRegistry.register(
            .attachment(attachment),
            frame: CGRect(x: 0, y: 100, width: 200, height: 30)
        )

        viewModel.selectAttachment(attachment)

        XCTAssertTrue(viewModel.navigationRegistry.isNavigationActive, "Should activate keyboard navigation")
    }

    func testSelectAttachmentShowsFocusRing() {
        setupDetailModeWithAttachments()
        let attachment = MockApiClient.sampleAttachment

        // Register the attachment first
        viewModel.navigationRegistry.register(
            .attachment(attachment),
            frame: CGRect(x: 0, y: 100, width: 200, height: 30)
        )

        viewModel.selectAttachment(attachment)

        // focusedDetailItem should now return the attachment
        guard case let .attachment(focused) = viewModel.focusedDetailItem else {
            XCTFail("focusedDetailItem should be attachment after selection")
            return
        }
        XCTAssertEqual(focused.id, attachment.id)
    }

    // MARK: - Async Loading Tests

    func testLoadTaskDetailRebuildsDetailFocusableItems() async throws {
        setupDetailMode()
        viewModel.buildDetailFocusableItems()

        // Before loading, there should be no attachments
        let attachmentsBefore = viewModel.detailFocusableItems.filter {
            if case .attachment = $0 { return true }
            return false
        }
        XCTAssertEqual(attachmentsBefore.count, 0, "Should have no attachments before load")

        // Load task detail (async)
        viewModel.loadTaskDetail(taskUUID: viewModel.tasks[0].uuid)

        // Wait for async load to complete
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // After loading, should have attachments
        let attachmentsAfter = viewModel.detailFocusableItems.filter {
            if case .attachment = $0 { return true }
            return false
        }
        XCTAssertGreaterThan(attachmentsAfter.count, 0, "Should have attachments after load")
    }

    // MARK: - Deselect Tests

    func testClearDetailFocusDeactivatesKeyboardNavigation() {
        setupDetailModeWithAttachments()
        let attachment = MockApiClient.sampleAttachment

        // Register and select an attachment
        viewModel.navigationRegistry.register(
            .attachment(attachment),
            frame: CGRect(x: 0, y: 100, width: 200, height: 30)
        )
        viewModel.selectAttachment(attachment)
        XCTAssertTrue(viewModel.navigationRegistry.isNavigationActive, "Should be active after selection")

        // Clear focus (simulates clicking outside)
        viewModel.clearDetailFocus()

        XCTAssertFalse(viewModel.navigationRegistry.isNavigationActive, "Should deactivate after clearing focus")
    }

    func testClearDetailFocusClearsFocusedItem() {
        setupDetailModeWithAttachments()
        let attachment = MockApiClient.sampleAttachment

        // Register and select an attachment
        viewModel.navigationRegistry.register(
            .attachment(attachment),
            frame: CGRect(x: 0, y: 100, width: 200, height: 30)
        )
        viewModel.selectAttachment(attachment)
        XCTAssertNotNil(viewModel.focusedDetailItem, "Should have focused item after selection")

        // Clear focus
        viewModel.clearDetailFocus()

        XCTAssertNil(viewModel.focusedDetailItem, "Should have no focused item after clearing")
    }

    // MARK: - Helpers

    private func setupDetailMode() {
        viewModel.tasks = MockApiClient.sampleTasks
        viewModel.selectedIndex = 0
        viewModel.mode = .detail
    }

    private func setupDetailModeWithAttachments() {
        setupDetailMode()
        viewModel.taskDetailState = TaskDetailState(
            isLoading: false,
            taskUUID: viewModel.tasks[0].uuid,
            detail: MockApiClient.sampleTaskDetail,
            errorMessage: nil
        )
        viewModel.buildDetailFocusableItems()
    }
}
