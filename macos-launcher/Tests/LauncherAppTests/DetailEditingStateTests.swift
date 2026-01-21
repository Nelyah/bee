@testable import LauncherAppKit
import XCTest

/// Tests for the DetailEditingState enum and related ViewModel behavior.
///
/// These tests verify:
/// - Enum properties and equality
/// - State transitions via start*/cancel* methods
/// - Escape key handling for all editing states
/// - Computed properties like editingAnnotationId
@MainActor
final class DetailEditingStateTests: XCTestCase {
    // MARK: - Enum Property Tests

    func testIsEditingPropertyReturnsCorrectValues() {
        // Test all enum cases return correct isEditing values
        XCTAssertFalse(DetailEditingState.none.isEditing)
        XCTAssertTrue(DetailEditingState.addingAnnotation.isEditing)
        XCTAssertTrue(DetailEditingState.editingAnnotation(id: "test-id").isEditing)
        XCTAssertTrue(DetailEditingState.editingTaskName.isEditing)
        XCTAssertTrue(DetailEditingState.editingProject.isEditing)
        XCTAssertTrue(DetailEditingState.addingTag.isEditing)
        XCTAssertTrue(DetailEditingState.editingDueDate.isEditing)
        XCTAssertTrue(DetailEditingState.editingPlannedDate.isEditing)
        XCTAssertTrue(DetailEditingState.addingImportantLink.isEditing)
    }

    func testEquatableWithAssociatedValue() {
        // Test that associated values are compared correctly
        let state1 = DetailEditingState.editingAnnotation(id: "annotation-1")
        let state2 = DetailEditingState.editingAnnotation(id: "annotation-1")
        let state3 = DetailEditingState.editingAnnotation(id: "annotation-2")

        XCTAssertEqual(state1, state2, "Same annotation ID should be equal")
        XCTAssertNotEqual(state1, state3, "Different annotation IDs should not be equal")
    }

    // MARK: - State Transition Tests

    func testMutualExclusivity() {
        // Verify that setting a new editing state replaces the old one
        let viewModel = LauncherViewModel()

        viewModel.detailEditingState = .addingAnnotation
        XCTAssertEqual(viewModel.detailEditingState, .addingAnnotation)

        // Setting a different state replaces the previous one
        viewModel.detailEditingState = .editingTaskName
        XCTAssertEqual(viewModel.detailEditingState, .editingTaskName)
        XCTAssertNotEqual(viewModel.detailEditingState, .addingAnnotation)

        // Only one state can be active at a time (type-level guarantee)
        viewModel.detailEditingState = .editingProject
        XCTAssertTrue(viewModel.detailEditingState.isEditing)
        XCTAssertEqual(viewModel.detailEditingState, .editingProject)
    }

    func testTransitionToNoneResetsIsEditing() {
        let viewModel = LauncherViewModel()

        // Start in an editing state
        viewModel.detailEditingState = .addingAnnotation
        XCTAssertTrue(viewModel.detailEditingState.isEditing)

        // Transition to .none
        viewModel.detailEditingState = .none
        XCTAssertFalse(viewModel.detailEditingState.isEditing)
    }

    // MARK: - Start Method Tests

    func testStartEditingMethodsSetsCorrectState() {
        let viewModel = LauncherViewModel()
        viewModel.tasks = [makeTask(id: "test-uuid")]
        viewModel.selectedIndex = 0
        viewModel.setModeForTesting(.detail)

        // Test startAddingAnnotation
        viewModel.startAddingAnnotation()
        XCTAssertEqual(viewModel.detailEditingState, .addingAnnotation)

        // Reset and test startEditingTaskName
        viewModel.detailEditingState = .none
        viewModel.startEditingTaskName()
        XCTAssertEqual(viewModel.detailEditingState, .editingTaskName)

        // Reset and test startEditingProject
        viewModel.detailEditingState = .none
        viewModel.startEditingProject()
        XCTAssertEqual(viewModel.detailEditingState, .editingProject)

        // Reset and test startAddingTag
        viewModel.detailEditingState = .none
        viewModel.startAddingTag()
        XCTAssertEqual(viewModel.detailEditingState, .addingTag)

        // Reset and test startEditingDueDate
        viewModel.detailEditingState = .none
        viewModel.startEditingDueDate()
        XCTAssertEqual(viewModel.detailEditingState, .editingDueDate)

        // Reset and test startEditingPlannedDate
        viewModel.detailEditingState = .none
        viewModel.startEditingPlannedDate()
        XCTAssertEqual(viewModel.detailEditingState, .editingPlannedDate)

        // Reset and test startAddingImportantLink
        viewModel.detailEditingState = .none
        viewModel.startAddingImportantLink()
        XCTAssertEqual(viewModel.detailEditingState, .addingImportantLink)
    }

    // MARK: - Cancel Method Tests

    func testCancelMethodsResetStateToNone() {
        let viewModel = LauncherViewModel()
        viewModel.tasks = [makeTask(id: "test-uuid")]
        viewModel.selectedIndex = 0
        viewModel.setModeForTesting(.detail)

        // Test cancelAddingAnnotation
        viewModel.detailEditingState = .addingAnnotation
        viewModel.cancelAddingAnnotation()
        XCTAssertEqual(viewModel.detailEditingState, .none)

        // Test cancelEditingTaskName
        viewModel.detailEditingState = .editingTaskName
        viewModel.cancelEditingTaskName()
        XCTAssertEqual(viewModel.detailEditingState, .none)

        // Test cancelEditingProject
        viewModel.detailEditingState = .editingProject
        viewModel.cancelEditingProject()
        XCTAssertEqual(viewModel.detailEditingState, .none)

        // Test cancelAddingTag
        viewModel.detailEditingState = .addingTag
        viewModel.cancelAddingTag()
        XCTAssertEqual(viewModel.detailEditingState, .none)

        // Test cancelEditingDueDate
        viewModel.detailEditingState = .editingDueDate
        viewModel.cancelEditingDueDate()
        XCTAssertEqual(viewModel.detailEditingState, .none)

        // Test cancelEditingPlannedDate
        viewModel.detailEditingState = .editingPlannedDate
        viewModel.cancelEditingPlannedDate()
        XCTAssertEqual(viewModel.detailEditingState, .none)

        // Test cancelAddingImportantLink
        viewModel.detailEditingState = .addingImportantLink
        viewModel.cancelAddingImportantLink()
        XCTAssertEqual(viewModel.detailEditingState, .none)
    }

    // MARK: - Escape Handler Tests

    func testEscapeHandlesAllEditingStates() {
        let viewModel = LauncherViewModel()
        viewModel.tasks = [makeTask(id: "test-uuid")]
        viewModel.selectedIndex = 0
        viewModel.setModeForTesting(.detail)

        // Test each editing state is handled by escape
        let editingStates: [DetailEditingState] = [
            .addingAnnotation,
            .editingAnnotation(id: "test-id"),
            .editingTaskName,
            .editingProject,
            .addingTag,
            .editingDueDate,
            .editingPlannedDate,
            .addingImportantLink,
        ]

        for state in editingStates {
            viewModel.detailEditingState = state
            let result = viewModel.handleEscape()
            XCTAssertTrue(result, "handleEscape should return true for \(state)")
            XCTAssertEqual(viewModel.detailEditingState, .none, "State should be .none after escape from \(state)")
        }
    }

    // MARK: - Computed Property Tests

    func testEditingAnnotationIdComputedProperty() {
        let viewModel = LauncherViewModel()

        // When not editing an annotation, should return nil
        viewModel.detailEditingState = .none
        XCTAssertNil(viewModel.editingAnnotationId)

        viewModel.detailEditingState = .addingAnnotation
        XCTAssertNil(viewModel.editingAnnotationId)

        viewModel.detailEditingState = .editingTaskName
        XCTAssertNil(viewModel.editingAnnotationId)

        // When editing an annotation, should return the ID
        viewModel.detailEditingState = .editingAnnotation(id: "annotation-123")
        XCTAssertEqual(viewModel.editingAnnotationId, "annotation-123")

        viewModel.detailEditingState = .editingAnnotation(id: "different-id")
        XCTAssertEqual(viewModel.editingAnnotationId, "different-id")
    }
}

/// Build a minimal ApiTask for tests.
private func makeTask(id: String) -> ApiTask {
    TestHelpers.makeTask(id: id)
}
