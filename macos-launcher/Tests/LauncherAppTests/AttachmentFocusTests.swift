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
        viewModel.detailFocusedIndex = 0
        viewModel.detailKeyboardNavigationActive = true

        // Find attachment index
        guard let attachmentIndex = viewModel.detailFocusableItems.firstIndex(where: {
            if case .attachment = $0 { return true }
            return false
        }) else {
            XCTFail("Attachment should be in focusable items")
            return
        }

        // Navigate down to attachment
        for _ in 0 ..< attachmentIndex {
            viewModel.handleDetailModeAction(.moveFocus(1))
        }

        XCTAssertEqual(viewModel.detailFocusedIndex, attachmentIndex)
        if case .attachment = viewModel.focusedDetailItem {
            // Success
        } else {
            XCTFail("Focused item should be attachment, got: \(String(describing: viewModel.focusedDetailItem))")
        }
    }

    // MARK: - Select Attachment Tests

    func testSelectAttachmentSetsFocusIndex() {
        setupDetailModeWithAttachments()
        viewModel.detailFocusedIndex = 0
        viewModel.detailKeyboardNavigationActive = false

        let attachment = MockApiClient.sampleAttachment

        viewModel.selectAttachment(attachment)

        // Find expected index
        guard let expectedIndex = viewModel.detailFocusableItems.firstIndex(where: {
            if case let .attachment(a) = $0 {
                return a.id == attachment.id
            }
            return false
        }) else {
            XCTFail("Attachment should be in focusable items")
            return
        }

        XCTAssertEqual(viewModel.detailFocusedIndex, expectedIndex)
    }

    func testSelectAttachmentActivatesKeyboardNavigation() {
        setupDetailModeWithAttachments()
        viewModel.detailKeyboardNavigationActive = false

        let attachment = MockApiClient.sampleAttachment

        viewModel.selectAttachment(attachment)

        XCTAssertTrue(viewModel.detailKeyboardNavigationActive, "Should activate keyboard navigation")
    }

    func testSelectAttachmentShowsFocusRing() {
        setupDetailModeWithAttachments()
        viewModel.detailKeyboardNavigationActive = false

        let attachment = MockApiClient.sampleAttachment

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

        // Select an attachment
        let attachment = MockApiClient.sampleAttachment
        viewModel.selectAttachment(attachment)
        XCTAssertTrue(viewModel.detailKeyboardNavigationActive, "Should be active after selection")

        // Clear focus (simulates clicking outside)
        viewModel.clearDetailFocus()

        XCTAssertFalse(viewModel.detailKeyboardNavigationActive, "Should deactivate after clearing focus")
    }

    func testClearDetailFocusClearsFocusedItem() {
        setupDetailModeWithAttachments()

        // Select an attachment
        let attachment = MockApiClient.sampleAttachment
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
