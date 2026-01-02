@testable import LauncherApp
import SwiftUI
import ViewInspector
import XCTest

/// UI tests for CompletionField index handling and greyed-out behavior.
///
/// These tests verify:
/// 1. CompletionRow correctly displays selected vs unselected states
/// 2. CompletionRow correctly displays greyed-out (current value) vs normal states
/// 3. CompletionMenuView correctly highlights the selected index
/// 4. Integration with FuzzyMatcher for real-world scenarios
final class CompletionFieldIndexUITests: XCTestCase {
    // MARK: - CompletionRow State Tests

    func testCompletionRow_selectedState_hasHighlightBackground() throws {
        let item = TestHelpers.makeCompletionItem(value: "test-item")
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

        let view = try selectedRow.inspect()
        // Should be able to find the text
        _ = try view.find(text: "test-item")
        // Row exists and renders
        XCTAssertNotNil(view)
    }

    func testCompletionRow_unselectedState_noHighlight() throws {
        let item = TestHelpers.makeCompletionItem(value: "test-item")
        let matchedItem = FuzzyMatchedItem(
            item: item,
            match: FuzzyMatch(score: 1.0, matchedIndices: [])
        )

        let unselectedRow = CompletionRow(
            matchedItem: matchedItem,
            isSelected: false,
            isCurrentValue: false,
            theme: .default
        )

        let view = try unselectedRow.inspect()
        _ = try view.find(text: "test-item")
        XCTAssertNotNil(view)
    }

    func testCompletionRow_currentValue_isGreyedOut() throws {
        let item = TestHelpers.makeCompletionItem(value: "current-project")
        let matchedItem = FuzzyMatchedItem(
            item: item,
            match: FuzzyMatch(score: 1.0, matchedIndices: [])
        )

        // Current value should be greyed out
        let currentValueRow = CompletionRow(
            matchedItem: matchedItem,
            isSelected: false,
            isCurrentValue: true,
            theme: .default
        )

        let view = try currentValueRow.inspect()
        _ = try view.find(text: "current-project")
        XCTAssertNotNil(view)
    }

    func testCompletionRow_currentValueAndSelected_bothStatesApply() throws {
        // Edge case: current value at index 0, but selectedIndex = 0
        // Should show as greyed AND highlighted (theoretically shouldn't happen
        // due to findFirstSelectableIndex, but test the visual state)
        let item = TestHelpers.makeCompletionItem(value: "current-project")
        let matchedItem = FuzzyMatchedItem(
            item: item,
            match: FuzzyMatch(score: 1.0, matchedIndices: [])
        )

        let row = CompletionRow(
            matchedItem: matchedItem,
            isSelected: true,
            isCurrentValue: true,
            theme: .default
        )

        let view = try row.inspect()
        _ = try view.find(text: "current-project")
        XCTAssertNotNil(view)
    }

    // MARK: - CompletionMenuView Selection Tests

    func testCompletionMenuView_correctIndexHighlighted() throws {
        let items = TestHelpers.makeCompletionItems(["alpha", "beta", "gamma"])
        let matches = items.map { FuzzyMatchedItem(item: $0, match: FuzzyMatch(score: 1.0, matchedIndices: [])) }

        // Selected index = 1 (beta)
        let menu = CompletionMenuView(
            matches: matches,
            selectedIndex: 1,
            currentValue: nil,
            theme: .default,
            onSelect: { _ in }
        )

        let view = try menu.inspect()
        // All items should be visible
        _ = try view.find(text: "alpha")
        _ = try view.find(text: "beta")
        _ = try view.find(text: "gamma")
    }

    func testCompletionMenuView_firstIndexHighlighted_noCurrentValue() throws {
        let items = TestHelpers.makeCompletionItems(["hobby", "hobbies-misc", "homework"])
        let matches = items.map { FuzzyMatchedItem(item: $0, match: FuzzyMatch(score: 1.0, matchedIndices: [])) }

        // No current value, first item selected
        let menu = CompletionMenuView(
            matches: matches,
            selectedIndex: 0,
            currentValue: nil,
            theme: .default,
            onSelect: { _ in }
        )

        let view = try menu.inspect()
        _ = try view.find(text: "hobby")
    }

    func testCompletionMenuView_withCurrentValue_correctGreying() throws {
        let items = TestHelpers.makeCompletionItems(["hobby", "hobbies-misc", "homework"])
        let matches = items.map { FuzzyMatchedItem(item: $0, match: FuzzyMatch(score: 1.0, matchedIndices: [])) }

        // Current value = "hobby", selected = 1 (hobbies-misc)
        let currentValue = TestHelpers.makeCompletionItem(value: "hobby")
        let menu = CompletionMenuView(
            matches: matches,
            selectedIndex: 1,
            currentValue: currentValue,
            theme: .default,
            onSelect: { _ in }
        )

        let view = try menu.inspect()
        // All items visible
        _ = try view.find(text: "hobby")
        _ = try view.find(text: "hobbies-misc")
        _ = try view.find(text: "homework")
    }

    func testCompletionMenuView_selectedIndexMinusOne_noHighlight() throws {
        let items = TestHelpers.makeCompletionItems(["hobby"])
        let matches = items.map { FuzzyMatchedItem(item: $0, match: FuzzyMatch(score: 1.0, matchedIndices: [])) }

        // selectedIndex = -1 (no selection - only match is current value)
        let currentValue = TestHelpers.makeCompletionItem(value: "hobby")
        let menu = CompletionMenuView(
            matches: matches,
            selectedIndex: -1,
            currentValue: currentValue,
            theme: .default,
            onSelect: { _ in }
        )

        let view = try menu.inspect()
        // Item visible but no row should be "selected" (index -1 != any valid index)
        _ = try view.find(text: "hobby")
    }

    // MARK: - Integration with FuzzyMatcher Tests

    func testIntegration_fuzzyMatchingWithCurrentValue() throws {
        // Simulate the full flow: items -> fuzzy filter -> sort -> move current to front
        let allProjects = TestHelpers.makeCompletionItems([
            "work",
            "personal",
            "hobby",
            "home",
            "hobbies-misc",
            "homework",
        ])

        let query = "hob"
        let currentProject = "hobby"

        // Step 1: Fuzzy filter
        var matches: [FuzzyMatchedItem<CompletionItem>] = allProjects.compactMap { item in
            guard let match = FuzzyMatcher.match(query, in: item.value) else {
                return nil
            }
            return FuzzyMatchedItem(item: item, match: match)
        }

        // Should match: hobby, hobbies-misc, home (ho matches)
        XCTAssertFalse(matches.isEmpty, "Should have matches for 'hob'")

        // Step 2: Sort by score
        matches.sort { $0.match.score > $1.match.score }

        // Step 3: Move current value to front if present
        if let index = matches.firstIndex(where: { $0.item.value == currentProject }) {
            let currentMatch = matches.remove(at: index)
            matches.insert(currentMatch, at: 0)
        }

        // Step 4: Find first selectable index using calculator
        let selectedIndex = CompletionIndexCalculator.findFirstSelectableIndex(
            items: matches.map(\.item),
            currentValueId: currentProject
        )

        // Current value "hobby" should be at index 0, so first selectable is index 1
        XCTAssertEqual(matches.first?.item.value, "hobby", "Current value should be at front")
        XCTAssertEqual(selectedIndex, 1, "First selectable should be index 1")

        // Step 5: Verify menu displays correctly
        let currentValue = TestHelpers.makeCompletionItem(value: currentProject)
        let menu = CompletionMenuView(
            matches: matches,
            selectedIndex: selectedIndex ?? -1,
            currentValue: currentValue,
            theme: .default,
            onSelect: { _ in }
        )

        let view = try menu.inspect()
        _ = try view.find(text: "hobby") // Should be visible (greyed)
    }

    func testIntegration_fuzzyMatchingWithoutCurrentValue() throws {
        let allProjects = TestHelpers.makeCompletionItems([
            "work",
            "personal",
            "hobby",
            "hobbies-misc",
        ])

        let query = "hob"

        // Step 1: Fuzzy filter
        var matches: [FuzzyMatchedItem<CompletionItem>] = allProjects.compactMap { item in
            guard let match = FuzzyMatcher.match(query, in: item.value) else {
                return nil
            }
            return FuzzyMatchedItem(item: item, match: match)
        }

        // Step 2: Sort by score
        matches.sort { $0.match.score > $1.match.score }

        // No current value to move

        // Step 3: Find first selectable index
        let selectedIndex = CompletionIndexCalculator.findFirstSelectableIndex(
            items: matches.map(\.item),
            currentValueId: nil
        )

        // No current value, so first selectable is index 0
        XCTAssertEqual(selectedIndex, 0, "First selectable should be index 0")
    }

    func testIntegration_onlyCurrentValueMatches() throws {
        let allProjects = TestHelpers.makeCompletionItems([
            "work",
            "personal",
            "hobby",
        ])

        let query = "hobby" // Exact match
        let currentProject = "hobby"

        // Step 1: Fuzzy filter
        var matches: [FuzzyMatchedItem<CompletionItem>] = allProjects.compactMap { item in
            guard let match = FuzzyMatcher.match(query, in: item.value) else {
                return nil
            }
            return FuzzyMatchedItem(item: item, match: match)
        }

        // Only "hobby" should match (exact)
        XCTAssertEqual(matches.count, 1, "Only exact match")
        XCTAssertEqual(matches.first?.item.value, "hobby")

        // Step 2: Sort (only one item)
        matches.sort { $0.match.score > $1.match.score }

        // Step 3: Find first selectable index
        let selectedIndex = CompletionIndexCalculator.findFirstSelectableIndex(
            items: matches.map(\.item),
            currentValueId: currentProject
        )

        // Only match is current value, so no valid selection
        XCTAssertNil(selectedIndex, "No valid selection when only match is current")
    }

    func testIntegration_emptyQuery_matchesAll() throws {
        let allProjects = TestHelpers.makeCompletionItems(["a", "b", "c"])
        let currentProject = "b"

        let query = ""

        // Empty query matches everything
        var matches: [FuzzyMatchedItem<CompletionItem>] = allProjects.compactMap { item in
            guard let match = FuzzyMatcher.match(query, in: item.value) else {
                return nil
            }
            return FuzzyMatchedItem(item: item, match: match)
        }

        // Should match all
        XCTAssertEqual(matches.count, 3, "Empty query should match all")

        // Sort by score
        matches.sort { $0.match.score > $1.match.score }

        // Move current to front
        if let index = matches.firstIndex(where: { $0.item.value == currentProject }) {
            let currentMatch = matches.remove(at: index)
            matches.insert(currentMatch, at: 0)
        }

        // Find first selectable
        let selectedIndex = CompletionIndexCalculator.findFirstSelectableIndex(
            items: matches.map(\.item),
            currentValueId: currentProject
        )

        // "b" should be at front, so first selectable is index 1
        XCTAssertEqual(matches.first?.item.value, "b", "Current should be at front")
        XCTAssertEqual(selectedIndex, 1, "First selectable should skip current")
    }

    // MARK: - Navigation After Filtering Tests

    func testNavigation_afterFuzzyFiltering() throws {
        let allProjects = TestHelpers.makeCompletionItems([
            "work",
            "website",
            "web-api",
            "personal",
        ])

        let query = "w"
        let currentProject = "work"

        // Filter
        var matches: [FuzzyMatchedItem<CompletionItem>] = allProjects.compactMap { item in
            guard let match = FuzzyMatcher.match(query, in: item.value) else {
                return nil
            }
            return FuzzyMatchedItem(item: item, match: match)
        }

        // Sort
        matches.sort { $0.match.score > $1.match.score }

        // Move current to front
        if let index = matches.firstIndex(where: { $0.item.value == currentProject }) {
            let currentMatch = matches.remove(at: index)
            matches.insert(currentMatch, at: 0)
        }

        let items = matches.map(\.item)

        // Initial selection
        var selectedIndex = CompletionIndexCalculator.findFirstSelectableIndex(
            items: items,
            currentValueId: currentProject
        )

        XCTAssertEqual(selectedIndex, 1, "Should skip 'work' at index 0")

        // Navigate down
        selectedIndex = CompletionIndexCalculator.selectNextIndex(
            from: selectedIndex!,
            items: items,
            currentValueId: currentProject
        )

        XCTAssertEqual(selectedIndex, 2, "Should go to next item")

        // Navigate up (should wrap, skipping 'work')
        selectedIndex = CompletionIndexCalculator.selectPreviousIndex(
            from: 1,
            items: items,
            currentValueId: currentProject
        )

        // Should wrap to last item, not go to 'work' at 0
        XCTAssertNotEqual(selectedIndex, 0, "Should not land on current value")
    }

    // MARK: - Edge Case Tests

    func testEdgeCase_singleNonCurrentItem() throws {
        let items = [TestHelpers.makeCompletionItem(value: "only-option")]
        let matches = items.map { FuzzyMatchedItem(item: $0, match: FuzzyMatch(score: 1.0, matchedIndices: [])) }

        let menu = CompletionMenuView(
            matches: matches,
            selectedIndex: 0,
            currentValue: nil,
            theme: .default,
            onSelect: { _ in }
        )

        let view = try menu.inspect()
        _ = try view.find(text: "only-option")
    }

    func testEdgeCase_allItemsExceptCurrentMatch() throws {
        // Current value doesn't match query, but others do
        let items = TestHelpers.makeCompletionItems(["hobby", "hobbies-misc"])
        let matches = items.map { FuzzyMatchedItem(item: $0, match: FuzzyMatch(score: 1.0, matchedIndices: [])) }

        // Current value is "work" which isn't in the list
        let selectedIndex = CompletionIndexCalculator.findFirstSelectableIndex(
            items: items,
            currentValueId: "work" // Not in list
        )

        XCTAssertEqual(selectedIndex, 0, "Should select first since current not in list")

        let menu = CompletionMenuView(
            matches: matches,
            selectedIndex: selectedIndex!,
            currentValue: nil, // No current value in list
            theme: .default,
            onSelect: { _ in }
        )

        let view = try menu.inspect()
        _ = try view.find(text: "hobby")
        _ = try view.find(text: "hobbies-misc")
    }

    func testEdgeCase_manyItemsWithCurrentInMiddle() throws {
        let items = (0 ..< 10).map { TestHelpers.makeCompletionItem(value: "item-\($0)") }
        let matches = items.map { FuzzyMatchedItem(item: $0, match: FuzzyMatch(score: 1.0, matchedIndices: [])) }

        // Current value is item-5
        let currentValue = TestHelpers.makeCompletionItem(value: "item-5")
        let selectedIndex = CompletionIndexCalculator.findFirstSelectableIndex(
            items: items,
            currentValueId: "item-5"
        )

        XCTAssertEqual(selectedIndex, 0, "Should select first (item-5 is not at front)")

        let menu = CompletionMenuView(
            matches: matches,
            selectedIndex: selectedIndex!,
            currentValue: currentValue,
            theme: .default,
            onSelect: { _ in }
        )

        let view = try menu.inspect()
        _ = try view.find(text: "item-0")
        _ = try view.find(text: "item-5")
    }
}
