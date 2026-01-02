@testable import LauncherApp
import SnapshotTesting
import SwiftUI
import XCTest

/// Snapshot tests for CompletionMenuView to catch visual regressions.
///
/// These tests capture the rendered appearance of the completion menu in various states.
final class CompletionMenuSnapshotTests: SnapshotTestCase {
    // MARK: - Basic States

    func testCompletionMenuDefault() {
        let items = [
            CompletionItem(value: "project:backend", count: 12),
            CompletionItem(value: "project:frontend", count: 8),
            CompletionItem(value: "project:mobile", count: 5),
        ]
        let view = CompletionMenuView(
            items: items,
            selectedIndex: 0,
            currentValue: nil,
            onSelect: { _ in }
        )

        assertViewSnapshot(view, size: TestSizes.completionMenu)
    }

    func testCompletionMenuWithSelectedMiddleItem() {
        let items = [
            CompletionItem(value: "status:pending", count: nil),
            CompletionItem(value: "status:in_progress", count: nil),
            CompletionItem(value: "status:completed", count: nil),
        ]
        let view = CompletionMenuView(
            items: items,
            selectedIndex: 1,
            currentValue: nil,
            onSelect: { _ in }
        )

        assertViewSnapshot(view, size: TestSizes.completionMenu)
    }

    func testCompletionMenuWithSelectedLastItem() {
        let items = [
            CompletionItem(value: "tag:urgent", count: 3),
            CompletionItem(value: "tag:work", count: 15),
            CompletionItem(value: "tag:personal", count: 7),
        ]
        let view = CompletionMenuView(
            items: items,
            selectedIndex: 2,
            currentValue: nil,
            onSelect: { _ in }
        )

        assertViewSnapshot(view, size: TestSizes.completionMenu)
    }

    // MARK: - Item Variations

    func testCompletionMenuWithoutCounts() {
        let items = [
            CompletionItem(value: "priority:high", count: nil),
            CompletionItem(value: "priority:medium", count: nil),
            CompletionItem(value: "priority:low", count: nil),
        ]
        let view = CompletionMenuView(
            items: items,
            selectedIndex: 0,
            currentValue: nil,
            onSelect: { _ in }
        )

        assertViewSnapshot(view, size: TestSizes.completionMenu)
    }

    func testCompletionMenuSingleItem() {
        let items = [
            CompletionItem(value: "only-suggestion", count: 42),
        ]
        let view = CompletionMenuView(
            items: items,
            selectedIndex: 0,
            currentValue: nil,
            onSelect: { _ in }
        )

        assertViewSnapshot(view, size: CGSize(width: 300, height: 60))
    }

    func testCompletionMenuManyItems() {
        let items = (1 ... 8).map { index in
            CompletionItem(value: "item-\(index)", count: index * 5)
        }
        let view = CompletionMenuView(
            items: items,
            selectedIndex: 3,
            currentValue: nil,
            onSelect: { _ in }
        )

        // Larger height for more items
        assertViewSnapshot(view, size: CGSize(width: 300, height: 280))
    }

    // MARK: - Text Variations

    func testCompletionMenuLongValues() {
        let items = [
            CompletionItem(value: "project:very-long-project-name-here", count: 100),
            CompletionItem(value: "tag:another-extremely-long-tag-value", count: 50),
        ]
        let view = CompletionMenuView(
            items: items,
            selectedIndex: 0,
            currentValue: nil,
            onSelect: { _ in }
        )

        assertViewSnapshot(view, size: CGSize(width: 350, height: 100))
    }

    func testCompletionMenuShortValues() {
        let items = [
            CompletionItem(value: "a", count: 1),
            CompletionItem(value: "bb", count: 22),
            CompletionItem(value: "ccc", count: 333),
        ]
        let view = CompletionMenuView(
            items: items,
            selectedIndex: 1,
            currentValue: nil,
            onSelect: { _ in }
        )

        assertViewSnapshot(view, size: CGSize(width: 200, height: 120))
    }

    // MARK: - CompletionRow Tests

    func testCompletionRowSelected() {
        let item = CompletionItem(value: "selected-item", count: 25)
        let view = CompletionRow(item: item, isSelected: true, isCurrentValue: false)

        assertViewSnapshot(view, size: CGSize(width: 250, height: 36))
    }

    func testCompletionRowUnselected() {
        let item = CompletionItem(value: "unselected-item", count: 10)
        let view = CompletionRow(item: item, isSelected: false, isCurrentValue: false)

        assertViewSnapshot(view, size: CGSize(width: 250, height: 36))
    }

    func testCompletionRowWithoutCount() {
        let item = CompletionItem(value: "no-count-item", count: nil)
        let view = CompletionRow(item: item, isSelected: false, isCurrentValue: false)

        assertViewSnapshot(view, size: CGSize(width: 250, height: 36))
    }
}
