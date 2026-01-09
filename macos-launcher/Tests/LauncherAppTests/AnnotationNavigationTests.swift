import AppKit
@testable import LauncherApp
import XCTest

/// Tests for annotation keyboard navigation in detail mode.
@MainActor
final class AnnotationNavigationTests: XCTestCase {
    private var viewModel: LauncherViewModel!

    override func setUp() {
        super.setUp()
        viewModel = LauncherViewModel(apiClient: MockApiClient())
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    // MARK: - Build Focusable Items

    func testBuildDetailFocusableItemsIncludesAnnotations() {
        setupDetailModeWithTaskDetail()

        let annotationCount = viewModel.detailFocusableItems.filter {
            if case .annotation = $0 { return true }
            return false
        }.count

        XCTAssertEqual(annotationCount, 1, "Should include 1 annotation from sampleTaskDetail")
    }

    // MARK: - Open Focused Item

    func testOpenFocusedStartsEditingWhenAnnotationFocused() {
        setupDetailModeWithTaskDetail()

        // Get the first annotation from the task detail
        guard let annotation = MockApiClient.sampleTaskDetail.annotations.first else {
            XCTFail("Sample task detail should have at least one annotation")
            return
        }

        // Clear existing registry and register the annotation
        viewModel.navigationRegistry.clearAll()
        let annotationItem = DetailFocusableItem.annotation(annotation)
        viewModel.navigationRegistry.register(
            annotationItem,
            frame: CGRect(x: 0, y: 0, width: 300, height: 30)
        )
        viewModel.navigationRegistry.focusOn(annotationItem)

        // Verify we're not editing yet
        XCTAssertNil(viewModel.editingAnnotationId, "Should not be editing yet")

        let result = viewModel.handleDetailModeAction(.openFocused)

        XCTAssertTrue(result)
        XCTAssertNotNil(viewModel.editingAnnotationId, "Enter on annotation should start editing")
        XCTAssertEqual(viewModel.editingAnnotationId, annotation.id, "Should be editing the focused annotation")
    }

    // MARK: - DetailFocusableItem Annotation Tests

    func testAnnotationItemCopyValue() {
        let annotation = TaskAnnotationDto(value: "Test annotation text", time: "2024-01-18T09:00:00Z")
        let item = DetailFocusableItem.annotation(annotation)
        XCTAssertEqual(item.copyValue, "Test annotation text")
    }

    func testAnnotationItemCopyLabel() {
        let annotation = TaskAnnotationDto(value: "Test", time: "2024-01-18T09:00:00Z")
        let item = DetailFocusableItem.annotation(annotation)
        XCTAssertEqual(item.copyLabel, "Annotation")
    }

    func testAnnotationItemId() {
        let annotation = TaskAnnotationDto(value: "Test", time: "2024-01-18T09:00:00Z")
        let item = DetailFocusableItem.annotation(annotation)
        XCTAssertEqual(item.id, "annotation-\(annotation.id)")
    }

    func testAnnotationItemOpenURLIsNil() {
        let annotation = TaskAnnotationDto(value: "Test", time: "2024-01-18T09:00:00Z")
        let item = DetailFocusableItem.annotation(annotation)
        XCTAssertNil(item.openURL, "Annotations should not have an openURL (they use Enter to edit)")
    }

    // MARK: - Helpers

    private func setupDetailModeWithTaskDetail() {
        viewModel.tasks = MockApiClient.sampleTasks
        viewModel.selectedIndex = 0
        viewModel.mode = .detail
        viewModel.taskDetailState = TaskDetailState(
            isLoading: false,
            taskUUID: viewModel.tasks[0].uuid,
            detail: MockApiClient.sampleTaskDetail,
            errorMessage: nil
        )
        viewModel.buildDetailFocusableItems()
    }
}
