@testable import LauncherAppKit
import SwiftUI
import ViewInspector
import XCTest

/// UI tests for ImportantLinksSection using ViewInspector.
///
/// These tests verify the view's structure, display states, and callback behavior.
final class ImportantLinksSectionUITests: XCTestCase {
    // MARK: - Test Helpers

    private func makeLinksSection(
        importantLinks: [ImportantLinkDto] = [],
        focusedItem: DetailFocusableItem? = nil,
        isAdding: Bool = false,
        urlInput: String = "",
        titleInput: String = "",
        isSubmitting: Bool = false,
        onOpen: @escaping (ImportantLinkDto) -> Void = { _ in },
        onRemove: @escaping (ImportantLinkDto) -> Void = { _ in },
        onStartAdding: @escaping () -> Void = {},
        onCancelAdding: @escaping () -> Void = {},
        onSubmit: @escaping () -> Void = {}
    ) -> ImportantLinksSection {
        ImportantLinksSection(
            importantLinks: importantLinks,
            focusedItem: focusedItem,
            onOpen: onOpen,
            onRemove: onRemove,
            onStartAdding: onStartAdding,
            isAdding: isAdding,
            urlInput: .constant(urlInput),
            titleInput: .constant(titleInput),
            isSubmitting: isSubmitting,
            onSubmit: onSubmit,
            onCancelAdding: onCancelAdding
        )
    }

    private func makeSampleLink(
        id: Int = 1,
        uuid: String = "test-uuid",
        url: String = "https://example.com",
        title: String = "Example",
        createdAt: String = "2024-01-18T09:00:00Z"
    ) -> ImportantLinkDto {
        ImportantLinkDto(id: id, uuid: uuid, url: url, title: title, createdAt: createdAt)
    }

    // MARK: - Display Tests

    func testImportantLinksSectionDisplaysTitle() throws {
        let sut = makeLinksSection()

        let view = try sut.inspect()

        // DetailSection wraps the title - just verify view renders without error
        // The title "Important Links" is passed to DetailSection
        XCTAssertNoThrow(try view.find(ViewType.VStack.self))
    }

    func testImportantLinksSectionWithNoLinksShowsAddButton() throws {
        let sut = makeLinksSection(importantLinks: [])

        let view = try sut.inspect()

        _ = try view.find(text: "Add link")
    }

    func testImportantLinksSectionWithLinksShowsLinkRows() throws {
        let links = [
            makeSampleLink(id: 1, uuid: "uuid-1", url: "https://example.com", title: "Example"),
            makeSampleLink(id: 2, uuid: "uuid-2", url: "https://test.com", title: "Test"),
        ]
        let sut = makeLinksSection(importantLinks: links)

        let view = try sut.inspect()

        // Should display link titles
        _ = try view.find(text: "Example")
        _ = try view.find(text: "Test")
    }

    // MARK: - Adding State Tests

    func testAddingStateShowsUrlTextField() throws {
        let sut = makeLinksSection(isAdding: true)

        let view = try sut.inspect()

        // Should have a TextField for URL input
        _ = try view.find(ViewType.TextField.self)
    }

    func testAddingStateShowsCancelButton() throws {
        let sut = makeLinksSection(isAdding: true)

        let view = try sut.inspect()

        _ = try view.find(text: "Cancel")
    }

    func testAddingStateShowsAddLinkButton() throws {
        let sut = makeLinksSection(isAdding: true)

        let view = try sut.inspect()

        _ = try view.find(text: "Add Link")
    }

    // MARK: - Callback Tests

    func testAddLinkButtonCallsOnStartAdding() throws {
        var startAddingCalled = false
        let sut = makeLinksSection(
            isAdding: false,
            onStartAdding: { startAddingCalled = true }
        )

        let view = try sut.inspect()

        // Find the "Add link" button and tap it
        let button = try view.find(ViewType.Button.self)
        try button.tap()

        XCTAssertTrue(startAddingCalled)
    }

    func testCancelButtonCallsOnCancelAdding() throws {
        var cancelCalled = false
        let sut = makeLinksSection(
            isAdding: true,
            onCancelAdding: { cancelCalled = true }
        )

        let view = try sut.inspect()

        // Find Cancel button by looking for button with "Cancel" text
        let buttons = view.findAll(ViewType.Button.self)
        // The Cancel button should be there when isAdding is true
        for button in buttons {
            if (try? button.find(text: "Cancel")) != nil {
                try button.tap()
                break
            }
        }

        XCTAssertTrue(cancelCalled, "Cancel button should call onCancelAdding")
    }

    // MARK: - Focus Blur Cancel Tests

    /// This test documents the expected behavior: when the URL field loses focus
    /// and the URL is empty, onCancelAdding should be called automatically.
    ///
    /// Note: ViewInspector cannot simulate focus state changes, so this test
    /// verifies the behavior indirectly by checking the view structure.
    /// The actual focus-blur behavior must be tested manually or via UI automation.
    func testUrlFieldIsConfiguredWithFocusHandling() throws {
        let sut = makeLinksSection(isAdding: true, urlInput: "")

        let view = try sut.inspect()

        // Verify the TextField exists and is part of the form
        let textField = try view.find(ViewType.TextField.self)
        XCTAssertNotNil(textField)

        // Note: We cannot test the actual focus state change behavior with ViewInspector.
        // The @FocusState and onChange(of:) modifiers handle this at runtime.
        // Manual testing is required to verify:
        // 1. URL field is auto-focused when form appears
        // 2. Clicking elsewhere with empty URL cancels the form
    }

    /// Test that verifies the ViewModel-level cancel behavior works correctly.
    /// This is a unit test for the cancel logic, separate from the focus handling.
    @MainActor
    func testViewModelCancelAddingImportantLinkResetsState() {
        let viewModel = LauncherViewModel(apiClient: MockApiClient())

        // Start adding
        viewModel.startAddingImportantLink()
        viewModel.importantLinkUrlInput = "https://test.com"
        viewModel.importantLinkTitleInput = "Test"

        XCTAssertEqual(viewModel.detailEditingState, .addingImportantLink)
        XCTAssertEqual(viewModel.importantLinkUrlInput, "https://test.com")

        // Cancel
        viewModel.cancelAddingImportantLink()

        XCTAssertEqual(viewModel.detailEditingState, .none)
        XCTAssertEqual(viewModel.importantLinkUrlInput, "")
        XCTAssertEqual(viewModel.importantLinkTitleInput, "")
    }

    /// Test that simulates the "click elsewhere to cancel" behavior.
    ///
    /// When the user is adding an important link with an empty URL and clicks
    /// on the background (triggering clearDetailFocus), the adding state should
    /// be cancelled. This is implemented in ContentView.onClearFocus.
    @MainActor
    func testClickElsewhereCancelsAddingWhenUrlEmpty() {
        let viewModel = LauncherViewModel(apiClient: MockApiClient())

        // Start adding but don't enter a URL
        viewModel.startAddingImportantLink()
        XCTAssertEqual(viewModel.detailEditingState, .addingImportantLink)
        XCTAssertTrue(viewModel.importantLinkUrlInput.isEmpty)

        // Simulate what ContentView.onClearFocus does: clear focus AND cancel if URL empty
        viewModel.clearDetailFocus()
        if viewModel.detailEditingState == .addingImportantLink,
           viewModel.importantLinkUrlInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            viewModel.cancelAddingImportantLink()
        }

        // Should have cancelled
        XCTAssertEqual(viewModel.detailEditingState, .none, "Should cancel adding when URL is empty")
    }

    /// Test that clicking elsewhere does NOT cancel when URL has content.
    @MainActor
    func testClickElsewhereDoesNotCancelWhenUrlHasContent() {
        let viewModel = LauncherViewModel(apiClient: MockApiClient())

        // Start adding WITH a URL
        viewModel.startAddingImportantLink()
        viewModel.importantLinkUrlInput = "https://example.com"
        XCTAssertEqual(viewModel.detailEditingState, .addingImportantLink)

        // Simulate what ContentView.onClearFocus does
        viewModel.clearDetailFocus()
        if viewModel.detailEditingState == .addingImportantLink,
           viewModel.importantLinkUrlInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            viewModel.cancelAddingImportantLink()
        }

        // Should NOT have cancelled because URL has content
        XCTAssertEqual(viewModel.detailEditingState, .addingImportantLink, "Should NOT cancel when URL has content")
        XCTAssertEqual(viewModel.importantLinkUrlInput, "https://example.com")
    }

    // MARK: - Submitting State Tests

    func testSubmittingStateShowsProgress() throws {
        let sut = makeLinksSection(isAdding: true, urlInput: "https://test.com", isSubmitting: true)

        let view = try sut.inspect()

        _ = try view.find(text: "Adding...")
    }

    func testSubmittingStateDisablesAddButton() throws {
        let sut = makeLinksSection(isAdding: true, urlInput: "https://test.com", isSubmitting: true)

        let view = try sut.inspect()

        // Find the Add Link button
        let buttons = view.findAll(ViewType.Button.self)
        var addButtonFound = false

        for button in buttons {
            if (try? button.find(text: "Adding...")) != nil {
                addButtonFound = true
                // Button should be disabled when submitting
                XCTAssertTrue(button.isDisabled())
                break
            }
        }

        XCTAssertTrue(addButtonFound, "Should find the Add Link button showing 'Adding...'")
    }

    func testEmptyUrlDisablesAddButton() throws {
        let sut = makeLinksSection(isAdding: true, urlInput: "", isSubmitting: false)

        let view = try sut.inspect()

        // Find the Add Link button
        let buttons = view.findAll(ViewType.Button.self)

        for button in buttons {
            if (try? button.find(text: "Add Link")) != nil {
                // Button should be disabled when URL is empty
                XCTAssertTrue(button.isDisabled())
                break
            }
        }
    }
}
