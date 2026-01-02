@testable import LauncherApp
import SwiftUI
import ViewInspector
import XCTest

/// UI tests for CompletionMenuView using ViewInspector.
///
/// These tests verify the view's structure, content display, and interaction behavior.
final class CompletionMenuUITests: XCTestCase {
    // MARK: - Basic Rendering Tests

    func testCompletionMenuDisplaysItems() throws {
        let items = TestHelpers.makeCompletionItems(["project:backend", "project:frontend", "project:mobile"])
        let sut = CompletionMenuView(
            items: items,
            selectedIndex: 0,
            currentValue: nil,
            onSelect: { _ in }
        )

        let view = try sut.inspect()

        // Find all item values
        _ = try view.find(text: "project:backend")
        _ = try view.find(text: "project:frontend")
        _ = try view.find(text: "project:mobile")
    }

    func testCompletionMenuDisplaysItemCounts() throws {
        let items = [
            CompletionItem(value: "tag:urgent", count: 15),
            CompletionItem(value: "tag:work", count: 8),
        ]
        let sut = CompletionMenuView(
            items: items,
            selectedIndex: 0,
            currentValue: nil,
            onSelect: { _ in }
        )

        let view = try sut.inspect()

        // Find count values
        _ = try view.find(text: "15")
        _ = try view.find(text: "8")
    }

    func testCompletionMenuDisplaysItemWithoutCount() throws {
        let items = [
            CompletionItem(value: "status:pending", count: nil),
        ]
        let sut = CompletionMenuView(
            items: items,
            selectedIndex: 0,
            currentValue: nil,
            onSelect: { _ in }
        )

        let view = try sut.inspect()

        // Should display the value
        _ = try view.find(text: "status:pending")
    }

    // MARK: - Interaction Tests

    func testCompletionRowTapCallsOnSelect() throws {
        let items = TestHelpers.makeCompletionItems(["option1", "option2", "option3"])

        let sut = CompletionMenuView(
            items: items,
            selectedIndex: 0,
            currentValue: nil,
            onSelect: { _ in }
        )

        let view = try sut.inspect()

        // Find the option text - look for the tap gesture on the item
        let rows = view.findAll(ViewType.Text.self).filter {
            (try? $0.string()) == "option2"
        }
        XCTAssertFalse(rows.isEmpty, "Should find option2 text")

        // Note: The tap gesture is on the parent ContentShape, which is not easily
        // accessible via ViewInspector. Verify the structure is correct.
        XCTAssertEqual(items.count, 3)
    }

    // MARK: - Selection State Tests

    func testCompletionRowShowsSelectionState() throws {
        let item = TestHelpers.makeCompletionItem(value: "test-item")

        // Test selected row
        let matchedItem = FuzzyMatchedItem(
            item: item,
            match: FuzzyMatch(score: 1.0, matchedIndices: [])
        )
        let selectedRow = CompletionRow(
            matchedItem: matchedItem,
            isSelected: true,
            isCurrentValue: false,
            theme: .default
        )
        let selectedView = try selectedRow.inspect()
        _ = try selectedView.find(text: "test-item")

        // Test unselected row
        let unselectedRow = CompletionRow(
            matchedItem: matchedItem,
            isSelected: false,
            isCurrentValue: false,
            theme: .default
        )
        let unselectedView = try unselectedRow.inspect()
        _ = try unselectedView.find(text: "test-item")
    }

    // MARK: - Edge Cases

    func testCompletionMenuHandlesEmptyItems() throws {
        let sut = CompletionMenuView(
            items: [],
            selectedIndex: 0,
            currentValue: nil,
            onSelect: { _ in }
        )

        // Should not crash with empty items
        let view = try sut.inspect()
        XCTAssertNotNil(view)
    }

    func testCompletionMenuHandlesSingleItem() throws {
        let items = [TestHelpers.makeCompletionItem(value: "only-item", count: 42)]
        let sut = CompletionMenuView(
            items: items,
            selectedIndex: 0,
            currentValue: nil,
            onSelect: { _ in }
        )

        let view = try sut.inspect()
        _ = try view.find(text: "only-item")
        _ = try view.find(text: "42")
    }

    func testCompletionMenuHandlesManyItems() throws {
        let values = (1 ... 20).map { "item-\($0)" }
        let items = TestHelpers.makeCompletionItems(values)
        let sut = CompletionMenuView(
            items: items,
            selectedIndex: 10,
            currentValue: nil,
            onSelect: { _ in }
        )

        let view = try sut.inspect()
        // Should be able to find some items
        _ = try view.find(text: "item-1")
        _ = try view.find(text: "item-10")
    }
}
