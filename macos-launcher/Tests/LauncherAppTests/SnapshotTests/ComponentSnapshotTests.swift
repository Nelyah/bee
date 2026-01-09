@testable import LauncherAppKit
import SnapshotTesting
import SwiftUI
import XCTest

/// Snapshot tests for reusable UI components.
///
/// These tests capture visual snapshots of smaller, reusable components
/// to ensure consistent styling and catch visual regressions.
final class ComponentSnapshotTests: SnapshotTestCase {
    // MARK: - ToastView Tests

    func testToastViewSuccess() {
        let toast = ToastMessage(message: "Task completed successfully", icon: .success)
        let view = ToastView(toast: toast)

        assertViewSnapshot(view, size: CGSize(width: 300, height: 50))
    }

    func testToastViewWarning() {
        let toast = ToastMessage(message: "Unable to connect to server", icon: .warning)
        let view = ToastView(toast: toast)

        assertViewSnapshot(view, size: CGSize(width: 300, height: 50))
    }

    func testToastViewLongMessage() {
        let toast = ToastMessage(
            message: "This is a longer error message that might wrap to multiple lines in the toast notification",
            icon: .warning
        )
        let view = ToastView(toast: toast)

        assertViewSnapshot(view, size: CGSize(width: 350, height: 70))
    }

    // MARK: - BottomHintBar Tests

    func testBottomHintBarWithHints() {
        let leftHints = [
            BottomHint(key: "↑↓", label: "Navigate"),
            BottomHint(key: "⏎", label: "Select"),
        ]
        let rightHints = [
            BottomHint(key: "⌘K", label: "Commands"),
            BottomHint(key: "esc", label: "Close"),
        ]

        let view = BottomHintBar(leftHints: leftHints, rightHints: rightHints, onAction: { _ in })

        assertViewSnapshot(view, size: CGSize(width: 600, height: BottomHintBar.height))
    }

    func testBottomHintBarEmpty() {
        let view = BottomHintBar(leftHints: [], rightHints: [], onAction: { _ in })

        assertViewSnapshot(view, size: CGSize(width: 600, height: BottomHintBar.height))
    }

    func testBottomHintBarLeftOnly() {
        let leftHints = [
            BottomHint(key: "j/k", label: "Move"),
            BottomHint(key: "g", label: "Go to"),
        ]

        let view = BottomHintBar(leftHints: leftHints, rightHints: [], onAction: { _ in })

        assertViewSnapshot(view, size: CGSize(width: 600, height: BottomHintBar.height))
    }

    // MARK: - GroupHeaderRow Tests

    func testGroupHeaderRowCollapsed() {
        let header = GroupHeader(key: "in_progress", displayName: "In Progress", taskCount: 4, isCollapsed: true)
        let view = GroupHeaderRow(header: header, isSelected: false)

        assertViewSnapshot(view, size: CGSize(width: 600, height: 40))
    }

    func testGroupHeaderRowExpanded() {
        let header = GroupHeader(key: "completed", displayName: "Completed Today", taskCount: 7, isCollapsed: false)
        let view = GroupHeaderRow(header: header, isSelected: false)

        assertViewSnapshot(view, size: CGSize(width: 600, height: 40))
    }

    func testGroupHeaderRowHovered() {
        let header = GroupHeader(key: "pending", displayName: "Pending", taskCount: 12, isCollapsed: false)
        let view = GroupHeaderRow(header: header, isSelected: false, initialHovered: true)

        assertViewSnapshot(view, size: CGSize(width: 600, height: 40))
    }

    func testGroupHeaderRowSelected() {
        let header = GroupHeader(key: "blocked", displayName: "Blocked", taskCount: 2, isCollapsed: true)
        let view = GroupHeaderRow(header: header, isSelected: true)

        assertViewSnapshot(view, size: CGSize(width: 600, height: 40))
    }

    // MARK: - DetailRow Tests

    func testDetailRowBasic() {
        let view = DetailRow(label: "Project", value: "Backend API", helpText: nil)

        assertViewSnapshot(view, size: CGSize(width: 400, height: 30))
    }

    func testDetailRowLongValue() {
        let view = DetailRow(
            label: "Description",
            value: "This is a very long description that should wrap properly within the detail row component",
            helpText: nil
        )

        assertViewSnapshot(view, size: CGSize(width: 400, height: 60))
    }

    func testDetailRowWithHelpText() {
        let view = DetailRow(
            label: "UUID",
            value: "abc123...",
            helpText: "abc123-def456-ghi789-jkl012"
        )

        assertViewSnapshot(view, size: CGSize(width: 400, height: 30))
    }

    // MARK: - CopyableDetailRow Tests

    func testCopyableDetailRowBasic() {
        let view = CopyableDetailRow(
            label: "UUID",
            value: "...12345678",
            fullValue: "abc-def-12345678",
            onCopy: { _ in }
        )

        assertViewSnapshot(view, size: CGSize(width: 400, height: 36))
    }

    func testCopyableDetailRowLongValue() {
        let view = CopyableDetailRow(
            label: "UUID",
            value: "abc-def-ghi-jkl-mno-pqr-stu-vwx-yz0-123-456",
            fullValue: "abc-def-ghi-jkl-mno-pqr-stu-vwx-yz0-123-456-789",
            onCopy: { _ in }
        )

        assertViewSnapshot(view, size: CGSize(width: 400, height: 60))
    }

    // MARK: - LinkStatusBadge Tests

    func testLinkStatusBadgePending() {
        let view = LinkStatusBadge(state: .pending, timestamp: nil)

        assertViewSnapshot(view, size: CGSize(width: 100, height: 24))
    }

    func testLinkStatusBadgeSynced() {
        let view = LinkStatusBadge(state: .synced(Date()), timestamp: "2024-01-15T10:30:00Z")

        assertViewSnapshot(view, size: CGSize(width: 150, height: 24))
    }

    func testLinkStatusBadgeStale() {
        // Create a date from 2 days ago
        let staleDate = Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date()
        let view = LinkStatusBadge(state: .stale(staleDate), timestamp: nil)

        // Wider to fit "Last synced 2d ago" text
        assertViewSnapshot(view, size: CGSize(width: 180, height: 24))
    }

    func testLinkStatusBadgeError() {
        let view = LinkStatusBadge(state: .error("Connection timeout"), timestamp: nil)

        assertViewSnapshot(view, size: CGSize(width: 100, height: 24))
    }

    // MARK: - AttachmentRow Tests

    func testAttachmentRowDefault() {
        let attachment = TaskAttachmentDto(
            id: 1,
            uuid: "attach-001",
            filename: "design-spec.pdf",
            mimeType: "application/pdf",
            sizeBytes: 245_760,
            createdAt: "2024-01-17T14:30:00Z"
        )

        let view = AttachmentRow(
            attachment: attachment,
            isFocused: false,
            isConfirmingDelete: false,
            onSelect: {},
            onOpen: {},
            onDelete: {},
            onConfirmDelete: {},
            onCancelDelete: {}
        )

        assertViewSnapshot(view, size: CGSize(width: 350, height: 36))
    }

    func testAttachmentRowFocused() {
        let attachment = TaskAttachmentDto(
            id: 1,
            uuid: "attach-001",
            filename: "design-spec.pdf",
            mimeType: "application/pdf",
            sizeBytes: 245_760,
            createdAt: "2024-01-17T14:30:00Z"
        )

        let view = AttachmentRow(
            attachment: attachment,
            isFocused: true,
            isConfirmingDelete: false,
            onSelect: {},
            onOpen: {},
            onDelete: {},
            onConfirmDelete: {},
            onCancelDelete: {}
        )

        assertViewSnapshot(view, size: CGSize(width: 350, height: 36))
    }
}
