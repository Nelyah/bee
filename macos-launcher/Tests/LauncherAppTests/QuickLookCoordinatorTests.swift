import AppKit
@testable import LauncherAppKit
import QuickLookUI
import XCTest

/// Tests for QuickLookCoordinator which manages Quick Look preview panel.
final class QuickLookCoordinatorTests: XCTestCase {
    // MARK: - Data Source Tests

    func testNumberOfPreviewItemsReturnsOneWhenURLIsSet() {
        let coordinator = QuickLookCoordinator()
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.pdf")

        coordinator.previewURL = tempURL

        // Create a mock panel to test the data source
        let panel = QLPreviewPanel.shared()!
        let count = coordinator.numberOfPreviewItems(in: panel)

        XCTAssertEqual(count, 1, "Should return 1 when URL is set")
    }

    func testNumberOfPreviewItemsReturnsZeroWhenURLIsNil() {
        let coordinator = QuickLookCoordinator()
        coordinator.previewURL = nil

        let panel = QLPreviewPanel.shared()!
        let count = coordinator.numberOfPreviewItems(in: panel)

        XCTAssertEqual(count, 0, "Should return 0 when URL is nil")
    }

    func testPreviewItemReturnsCorrectURL() {
        let coordinator = QuickLookCoordinator()
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("document.pdf")

        coordinator.previewURL = tempURL

        let panel = QLPreviewPanel.shared()!
        let item = coordinator.previewPanel(panel, previewItemAt: 0) as? URL

        XCTAssertEqual(item, tempURL, "Should return the preview URL")
    }

    func testPreviewItemReturnsNilForInvalidIndex() {
        let coordinator = QuickLookCoordinator()
        coordinator.previewURL = nil

        let panel = QLPreviewPanel.shared()!
        let item = coordinator.previewPanel(panel, previewItemAt: 0)

        XCTAssertNil(item, "Should return nil when no URL is set")
    }
}
