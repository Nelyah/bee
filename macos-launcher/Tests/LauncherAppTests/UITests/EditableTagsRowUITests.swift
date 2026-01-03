@testable import LauncherApp
import SwiftUI
import ViewInspector
import XCTest

/// UI tests for EditableTagsRow using ViewInspector.
///
/// These tests verify the view's structure, display states, and callback behavior.
final class EditableTagsRowUITests: XCTestCase {
    // MARK: - Test Helpers

    private func makeTagsRow(
        tags: [String] = ["hobby", "work"],
        selectedTagIndex: Int? = nil,
        isAddingTag: Bool = false,
        isSubmitting: Bool = false,
        onSelectTagIndex: @escaping (Int?) -> Void = { _ in },
        onStartAdding: @escaping () -> Void = {},
        onCancelAdding: @escaping () -> Void = {},
        onSelectCompletion: @escaping (CompletionItem) -> Void = { _ in },
        onRemoveTag: @escaping (String) -> Void = { _ in }
    ) -> EditableTagsRow {
        EditableTagsRow(
            tags: tags,
            selectedTagIndex: selectedTagIndex,
            isAddingTag: isAddingTag,
            tagAddQuery: .constant(""),
            allTagCompletions: [
                CompletionItem(value: "urgent", count: 5),
                CompletionItem(value: "review", count: 3),
            ],
            isSubmitting: isSubmitting,
            onSelectTagIndex: onSelectTagIndex,
            onStartAdding: onStartAdding,
            onCancelAdding: onCancelAdding,
            onSelectCompletion: onSelectCompletion,
            onRemoveTag: onRemoveTag
        )
    }

    // MARK: - Display Tests

    func testEditableTagsRowDisplaysLabel() throws {
        let sut = makeTagsRow()

        let view = try sut.inspect()

        _ = try view.find(text: "Tags")
    }

    func testEditableTagsRowDisplaysAllTags() throws {
        let sut = makeTagsRow(tags: ["hobby", "work", "urgent"])

        let view = try sut.inspect()

        _ = try view.find(text: "hobby")
        _ = try view.find(text: "work")
        _ = try view.find(text: "urgent")
    }

    func testEditableTagsRowWithEmptyTagsShowsAddTagText() throws {
        let sut = makeTagsRow(tags: [])

        let view = try sut.inspect()

        // When empty, should show "Add tag" text
        _ = try view.find(text: "Add tag")
    }

    func testEditableTagsRowWithTagsShowsPlusButton() throws {
        let sut = makeTagsRow(tags: ["hobby"])

        let view = try sut.inspect()

        // When tags exist, should have a plus button (but not the "Add tag" text)
        let buttons = view.findAll(ViewType.Button.self)
        // Should have at least 2 buttons: one for the tag removal and one for add
        XCTAssertGreaterThanOrEqual(buttons.count, 2)
    }

    // MARK: - Callback Tests

    func testEditableTagsRowRemoveCallsOnRemoveTag() throws {
        var removedTag: String?
        let sut = makeTagsRow(
            tags: ["hobby", "work"],
            onRemoveTag: { tag in removedTag = tag }
        )

        let view = try sut.inspect()

        // Find and tap the first TagChip's remove button
        // TagChips are in the FlowLayout, each with a Button
        let buttons = view.findAll(ViewType.Button.self)
        // First button should be the remove button for "hobby" tag
        try buttons.first?.tap()

        XCTAssertEqual(removedTag, "hobby")
    }

    func testEditableTagsRowAddButtonCallsOnStartAdding() throws {
        var startAddingCalled = false
        let sut = makeTagsRow(
            tags: [],
            onStartAdding: { startAddingCalled = true }
        )

        let view = try sut.inspect()

        // Find the add button (should be the only one when no tags exist)
        let button = try view.find(ViewType.Button.self)
        try button.tap()

        XCTAssertTrue(startAddingCalled)
    }

    // MARK: - State Tests

    func testEditableTagsRowAddingStateShowsCompletionField() throws {
        let sut = makeTagsRow(tags: ["hobby"], isAddingTag: true)

        let view = try sut.inspect()

        // Should contain a CompletionField when adding - verify by checking for TextField
        // The CompletionField contains a TextField, so we can find that instead
        _ = try view.find(ViewType.TextField.self)
    }

    func testEditableTagsRowNotAddingShowsPlusButton() throws {
        let sut = makeTagsRow(tags: ["hobby"], isAddingTag: false)

        let view = try sut.inspect()

        // When not adding, should have buttons (tag remove buttons + add button)
        // but no TextField (CompletionField)
        let buttons = view.findAll(ViewType.Button.self)
        XCTAssertGreaterThanOrEqual(buttons.count, 1)
    }
}
