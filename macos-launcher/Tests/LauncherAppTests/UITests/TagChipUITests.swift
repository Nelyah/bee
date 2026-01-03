@testable import LauncherApp
import SwiftUI
import ViewInspector
import XCTest

/// UI tests for TagChip using ViewInspector.
///
/// These tests verify the view's structure, content display, and callback behavior.
final class TagChipUITests: XCTestCase {
    // MARK: - Display Tests

    func testTagChipDisplaysTagName() throws {
        let sut = TagChip(tag: "hobby", isSelected: false, onRemove: {})

        let view = try sut.inspect()

        _ = try view.find(text: "hobby")
    }

    func testTagChipContainsRemoveButton() throws {
        let sut = TagChip(tag: "work", isSelected: false, onRemove: {})

        let view = try sut.inspect()

        // The chip should contain a button for removal
        _ = try view.find(ViewType.Button.self)
    }

    func testTagChipContainsXmarkIcon() throws {
        let sut = TagChip(tag: "urgent", isSelected: false, onRemove: {})

        let view = try sut.inspect()

        // Should contain the xmark icon
        _ = try view.find(ViewType.Image.self)
    }

    // MARK: - Callback Tests

    func testTagChipRemoveButtonCallsOnRemove() throws {
        var removeCalled = false
        let sut = TagChip(tag: "test", isSelected: false, onRemove: { removeCalled = true })

        let view = try sut.inspect()
        let button = try view.find(ViewType.Button.self)
        try button.tap()

        XCTAssertTrue(removeCalled)
    }

    // MARK: - Selection State Tests

    func testTagChipSelectedStateDoesNotAffectContent() throws {
        let normalChip = TagChip(tag: "test", isSelected: false, onRemove: {})
        let selectedChip = TagChip(tag: "test", isSelected: true, onRemove: {})

        // Both should display the same text
        _ = try normalChip.inspect().find(text: "test")
        _ = try selectedChip.inspect().find(text: "test")

        // Both should have a button
        _ = try normalChip.inspect().find(ViewType.Button.self)
        _ = try selectedChip.inspect().find(ViewType.Button.self)
    }
}
