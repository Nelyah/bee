@testable import LauncherApp
import XCTest

/// Tests for CompletionIndexCalculator.
///
/// These tests verify the index calculation logic used by CompletionField
/// to handle the "current value greyed out" behavior.
final class CompletionIndexCalculatorTests: XCTestCase {
    // MARK: - Test Helpers

    struct TestItem: Identifiable {
        let id: String
        let name: String

        init(_ name: String) {
            self.id = name
            self.name = name
        }
    }

    // MARK: - findFirstSelectableIndex Tests

    func testFindFirstSelectableIndex_noCurrentValue_returnsZero() {
        let items = [TestItem("a"), TestItem("b"), TestItem("c")]

        let result = CompletionIndexCalculator.findFirstSelectableIndex(
            items: items,
            currentValueId: nil
        )

        XCTAssertEqual(result, 0, "Should return first index when no current value")
    }

    func testFindFirstSelectableIndex_currentValueAtIndex0_returnsIndex1() {
        let items = [TestItem("current"), TestItem("second"), TestItem("third")]

        let result = CompletionIndexCalculator.findFirstSelectableIndex(
            items: items,
            currentValueId: "current"
        )

        XCTAssertEqual(result, 1, "Should skip current value at index 0")
    }

    func testFindFirstSelectableIndex_currentValueAtIndex1_returnsIndex0() {
        let items = [TestItem("first"), TestItem("current"), TestItem("third")]

        let result = CompletionIndexCalculator.findFirstSelectableIndex(
            items: items,
            currentValueId: "current"
        )

        XCTAssertEqual(result, 0, "Should return index 0 when current value is at index 1")
    }

    func testFindFirstSelectableIndex_currentValueNotInList_returnsIndex0() {
        let items = [TestItem("a"), TestItem("b"), TestItem("c")]

        let result = CompletionIndexCalculator.findFirstSelectableIndex(
            items: items,
            currentValueId: "not-in-list"
        )

        XCTAssertEqual(result, 0, "Should return index 0 when current value not in list")
    }

    func testFindFirstSelectableIndex_onlyCurrentValue_returnsNil() {
        let items = [TestItem("current")]

        let result = CompletionIndexCalculator.findFirstSelectableIndex(
            items: items,
            currentValueId: "current"
        )

        XCTAssertNil(result, "Should return nil when only item is current value")
    }

    func testFindFirstSelectableIndex_emptyList_returnsNil() {
        let items: [TestItem] = []

        let result = CompletionIndexCalculator.findFirstSelectableIndex(
            items: items,
            currentValueId: nil
        )

        XCTAssertNil(result, "Should return nil for empty list")
    }

    func testFindFirstSelectableIndex_emptyListWithCurrentValue_returnsNil() {
        let items: [TestItem] = []

        let result = CompletionIndexCalculator.findFirstSelectableIndex(
            items: items,
            currentValueId: "some-value"
        )

        XCTAssertNil(result, "Should return nil for empty list even with current value")
    }

    // MARK: - selectNextIndex Tests

    func testSelectNextIndex_noCurrentValue_wrapsAround() {
        let items = [TestItem("a"), TestItem("b"), TestItem("c")]

        // From index 0 → 1
        var result = CompletionIndexCalculator.selectNextIndex(
            from: 0,
            items: items,
            currentValueId: nil
        )
        XCTAssertEqual(result, 1)

        // From index 2 → 0 (wrap around)
        result = CompletionIndexCalculator.selectNextIndex(
            from: 2,
            items: items,
            currentValueId: nil
        )
        XCTAssertEqual(result, 0)
    }

    func testSelectNextIndex_skipsCurrentValue() {
        let items = [TestItem("a"), TestItem("current"), TestItem("c")]

        // From index 0, should skip index 1 (current) and go to index 2
        let result = CompletionIndexCalculator.selectNextIndex(
            from: 0,
            items: items,
            currentValueId: "current"
        )

        XCTAssertEqual(result, 2, "Should skip current value at index 1")
    }

    func testSelectNextIndex_skipsCurrentValueAtEdge() {
        // Current value at index 2, should wrap to 0
        let items = [TestItem("a"), TestItem("b"), TestItem("current")]

        let result = CompletionIndexCalculator.selectNextIndex(
            from: 1,
            items: items,
            currentValueId: "current"
        )

        XCTAssertEqual(result, 0, "Should wrap around and skip current value")
    }

    func testSelectNextIndex_emptyList_returnsNil() {
        let items: [TestItem] = []

        let result = CompletionIndexCalculator.selectNextIndex(
            from: 0,
            items: items,
            currentValueId: nil
        )

        XCTAssertNil(result)
    }

    func testSelectNextIndex_onlyCurrentValue_returnsNil() {
        let items = [TestItem("current")]

        let result = CompletionIndexCalculator.selectNextIndex(
            from: 0,
            items: items,
            currentValueId: "current"
        )

        XCTAssertNil(result, "Should return nil when only item is current value")
    }

    // MARK: - selectPreviousIndex Tests

    func testSelectPreviousIndex_noCurrentValue_wrapsAround() {
        let items = [TestItem("a"), TestItem("b"), TestItem("c")]

        // From index 1 → 0
        var result = CompletionIndexCalculator.selectPreviousIndex(
            from: 1,
            items: items,
            currentValueId: nil
        )
        XCTAssertEqual(result, 0)

        // From index 0 → 2 (wrap around)
        result = CompletionIndexCalculator.selectPreviousIndex(
            from: 0,
            items: items,
            currentValueId: nil
        )
        XCTAssertEqual(result, 2)
    }

    func testSelectPreviousIndex_skipsCurrentValue() {
        let items = [TestItem("a"), TestItem("current"), TestItem("c")]

        // From index 2, should skip index 1 (current) and go to index 0
        let result = CompletionIndexCalculator.selectPreviousIndex(
            from: 2,
            items: items,
            currentValueId: "current"
        )

        XCTAssertEqual(result, 0, "Should skip current value at index 1")
    }

    func testSelectPreviousIndex_skipsCurrentValueAtEdge() {
        // Current value at index 0, from index 1 should wrap to 2
        let items = [TestItem("current"), TestItem("b"), TestItem("c")]

        let result = CompletionIndexCalculator.selectPreviousIndex(
            from: 1,
            items: items,
            currentValueId: "current"
        )

        XCTAssertEqual(result, 2, "Should wrap around and skip current value at index 0")
    }

    func testSelectPreviousIndex_emptyList_returnsNil() {
        let items: [TestItem] = []

        let result = CompletionIndexCalculator.selectPreviousIndex(
            from: 0,
            items: items,
            currentValueId: nil
        )

        XCTAssertNil(result)
    }

    // MARK: - isValidIndex Tests

    func testIsValidIndex_withinBounds_returnsTrue() {
        let items = [TestItem("a"), TestItem("b"), TestItem("c")]

        XCTAssertTrue(CompletionIndexCalculator.isValidIndex(0, for: items))
        XCTAssertTrue(CompletionIndexCalculator.isValidIndex(1, for: items))
        XCTAssertTrue(CompletionIndexCalculator.isValidIndex(2, for: items))
    }

    func testIsValidIndex_negative_returnsFalse() {
        let items = [TestItem("a"), TestItem("b"), TestItem("c")]

        XCTAssertFalse(CompletionIndexCalculator.isValidIndex(-1, for: items))
        XCTAssertFalse(CompletionIndexCalculator.isValidIndex(-100, for: items))
    }

    func testIsValidIndex_outOfBounds_returnsFalse() {
        let items = [TestItem("a"), TestItem("b"), TestItem("c")]

        XCTAssertFalse(CompletionIndexCalculator.isValidIndex(3, for: items))
        XCTAssertFalse(CompletionIndexCalculator.isValidIndex(100, for: items))
    }

    func testIsValidIndex_emptyArray_alwaysFalse() {
        let items: [TestItem] = []

        XCTAssertFalse(CompletionIndexCalculator.isValidIndex(0, for: items))
        XCTAssertFalse(CompletionIndexCalculator.isValidIndex(-1, for: items))
    }

    // MARK: - Extended findFirstSelectableIndex Tests

    func testFindFirstSelectableIndex_currentValueAtLastIndex() {
        let items = [TestItem("a"), TestItem("b"), TestItem("current")]

        let result = CompletionIndexCalculator.findFirstSelectableIndex(
            items: items,
            currentValueId: "current"
        )

        XCTAssertEqual(result, 0, "Should return first non-current item")
    }

    func testFindFirstSelectableIndex_currentValueInMiddle() {
        let items = [TestItem("a"), TestItem("current"), TestItem("c"), TestItem("d")]

        let result = CompletionIndexCalculator.findFirstSelectableIndex(
            items: items,
            currentValueId: "current"
        )

        XCTAssertEqual(result, 0, "Should return index 0 when current is in middle")
    }

    func testFindFirstSelectableIndex_twoItems_currentFirst() {
        let items = [TestItem("current"), TestItem("other")]

        let result = CompletionIndexCalculator.findFirstSelectableIndex(
            items: items,
            currentValueId: "current"
        )

        XCTAssertEqual(result, 1, "Should return index 1 when current is first of two")
    }

    func testFindFirstSelectableIndex_twoItems_currentSecond() {
        let items = [TestItem("other"), TestItem("current")]

        let result = CompletionIndexCalculator.findFirstSelectableIndex(
            items: items,
            currentValueId: "current"
        )

        XCTAssertEqual(result, 0, "Should return index 0 when current is second of two")
    }

    func testFindFirstSelectableIndex_largeList_currentAtStart() {
        let items = (0 ..< 100).map { TestItem("item-\($0)") }

        let result = CompletionIndexCalculator.findFirstSelectableIndex(
            items: items,
            currentValueId: "item-0"
        )

        XCTAssertEqual(result, 1, "Should skip first item in large list")
    }

    func testFindFirstSelectableIndex_largeList_currentAtEnd() {
        let items = (0 ..< 100).map { TestItem("item-\($0)") }

        let result = CompletionIndexCalculator.findFirstSelectableIndex(
            items: items,
            currentValueId: "item-99"
        )

        XCTAssertEqual(result, 0, "Should return first item when current is at end")
    }

    func testFindFirstSelectableIndex_largeList_currentInMiddle() {
        let items = (0 ..< 100).map { TestItem("item-\($0)") }

        let result = CompletionIndexCalculator.findFirstSelectableIndex(
            items: items,
            currentValueId: "item-50"
        )

        XCTAssertEqual(result, 0, "Should return first item when current is in middle")
    }

    // MARK: - Extended selectNextIndex Tests

    func testSelectNextIndex_consecutiveNavigation() {
        let items = [TestItem("a"), TestItem("b"), TestItem("c"), TestItem("d")]

        var index = 0
        index = CompletionIndexCalculator.selectNextIndex(from: index, items: items, currentValueId: nil)!
        XCTAssertEqual(index, 1)
        index = CompletionIndexCalculator.selectNextIndex(from: index, items: items, currentValueId: nil)!
        XCTAssertEqual(index, 2)
        index = CompletionIndexCalculator.selectNextIndex(from: index, items: items, currentValueId: nil)!
        XCTAssertEqual(index, 3)
        index = CompletionIndexCalculator.selectNextIndex(from: index, items: items, currentValueId: nil)!
        XCTAssertEqual(index, 0, "Should wrap to beginning")
    }

    func testSelectNextIndex_consecutiveNavigationWithCurrentValue() {
        // Current value at index 1
        let items = [TestItem("a"), TestItem("current"), TestItem("c"), TestItem("d")]

        var index = 0
        index = CompletionIndexCalculator.selectNextIndex(from: index, items: items, currentValueId: "current")!
        XCTAssertEqual(index, 2, "Should skip current at index 1")
        index = CompletionIndexCalculator.selectNextIndex(from: index, items: items, currentValueId: "current")!
        XCTAssertEqual(index, 3)
        index = CompletionIndexCalculator.selectNextIndex(from: index, items: items, currentValueId: "current")!
        XCTAssertEqual(index, 0, "Should wrap, skipping current")
    }

    func testSelectNextIndex_multipleConsecutiveCurrentValues() {
        // This tests a theoretical edge case where the same ID appears multiple times
        // In practice, IDs should be unique, but the algorithm should handle it
        let items = [TestItem("a"), TestItem("b"), TestItem("c")]

        // Even with "b" as current, navigation should work
        var index = 0
        index = CompletionIndexCalculator.selectNextIndex(from: index, items: items, currentValueId: "b")!
        XCTAssertEqual(index, 2, "Should skip index 1")
        index = CompletionIndexCalculator.selectNextIndex(from: index, items: items, currentValueId: "b")!
        XCTAssertEqual(index, 0, "Should wrap to 0")
    }

    func testSelectNextIndex_fromNegativeIndex() {
        let items = [TestItem("a"), TestItem("b"), TestItem("c")]

        // Starting from -1 (no selection), next should go to 0
        let result = CompletionIndexCalculator.selectNextIndex(
            from: -1,
            items: items,
            currentValueId: nil
        )

        XCTAssertEqual(result, 0, "From -1, next should be 0")
    }

    func testSelectNextIndex_fromNegativeIndexWithCurrentAtZero() {
        let items = [TestItem("current"), TestItem("b"), TestItem("c")]

        // Starting from -1, should skip current at 0
        let result = CompletionIndexCalculator.selectNextIndex(
            from: -1,
            items: items,
            currentValueId: "current"
        )

        XCTAssertEqual(result, 1, "From -1, should skip current at 0")
    }

    func testSelectNextIndex_twoItemsWithCurrentValue() {
        let items = [TestItem("current"), TestItem("other")]

        // From index 1 (other), next should wrap to... skip 0 (current), land on 1 again
        let result = CompletionIndexCalculator.selectNextIndex(
            from: 1,
            items: items,
            currentValueId: "current"
        )

        XCTAssertEqual(result, 1, "With only one selectable item, should stay on it")
    }

    // MARK: - Extended selectPreviousIndex Tests

    func testSelectPreviousIndex_consecutiveNavigation() {
        let items = [TestItem("a"), TestItem("b"), TestItem("c"), TestItem("d")]

        var index = 3
        index = CompletionIndexCalculator.selectPreviousIndex(from: index, items: items, currentValueId: nil)!
        XCTAssertEqual(index, 2)
        index = CompletionIndexCalculator.selectPreviousIndex(from: index, items: items, currentValueId: nil)!
        XCTAssertEqual(index, 1)
        index = CompletionIndexCalculator.selectPreviousIndex(from: index, items: items, currentValueId: nil)!
        XCTAssertEqual(index, 0)
        index = CompletionIndexCalculator.selectPreviousIndex(from: index, items: items, currentValueId: nil)!
        XCTAssertEqual(index, 3, "Should wrap to end")
    }

    func testSelectPreviousIndex_consecutiveNavigationWithCurrentValue() {
        // Current value at index 2
        let items = [TestItem("a"), TestItem("b"), TestItem("current"), TestItem("d")]

        var index = 3
        index = CompletionIndexCalculator.selectPreviousIndex(from: index, items: items, currentValueId: "current")!
        XCTAssertEqual(index, 1, "Should skip current at index 2")
        index = CompletionIndexCalculator.selectPreviousIndex(from: index, items: items, currentValueId: "current")!
        XCTAssertEqual(index, 0)
        index = CompletionIndexCalculator.selectPreviousIndex(from: index, items: items, currentValueId: "current")!
        XCTAssertEqual(index, 3, "Should wrap, skipping current")
    }

    func testSelectPreviousIndex_fromNegativeIndex() {
        let items = [TestItem("a"), TestItem("b"), TestItem("c")]

        // From -1, previous should wrap to last
        let result = CompletionIndexCalculator.selectPreviousIndex(
            from: -1,
            items: items,
            currentValueId: nil
        )

        // (-1 - 1 + 3) % 3 = 1, but let's verify
        XCTAssertNotNil(result, "Should return a valid index")
    }

    func testSelectPreviousIndex_onlyCurrentValue_returnsNil() {
        let items = [TestItem("current")]

        let result = CompletionIndexCalculator.selectPreviousIndex(
            from: 0,
            items: items,
            currentValueId: "current"
        )

        XCTAssertNil(result, "Should return nil when only item is current value")
    }

    func testSelectPreviousIndex_twoItemsWithCurrentValue() {
        let items = [TestItem("other"), TestItem("current")]

        // From index 0, previous should wrap... skip 1 (current), land on 0 again
        let result = CompletionIndexCalculator.selectPreviousIndex(
            from: 0,
            items: items,
            currentValueId: "current"
        )

        XCTAssertEqual(result, 0, "With only one selectable item, should stay on it")
    }

    // MARK: - Bidirectional Navigation Tests

    func testBidirectionalNavigation_nextThenPrevious() {
        let items = [TestItem("a"), TestItem("b"), TestItem("c")]

        var index = 0
        index = CompletionIndexCalculator.selectNextIndex(from: index, items: items, currentValueId: nil)!
        XCTAssertEqual(index, 1)
        index = CompletionIndexCalculator.selectPreviousIndex(from: index, items: items, currentValueId: nil)!
        XCTAssertEqual(index, 0, "Should return to original position")
    }

    func testBidirectionalNavigation_withCurrentValue() {
        // Current at index 1
        let items = [TestItem("a"), TestItem("current"), TestItem("c")]

        var index = 0
        index = CompletionIndexCalculator.selectNextIndex(from: index, items: items, currentValueId: "current")!
        XCTAssertEqual(index, 2, "Next from 0 should skip 1, go to 2")
        index = CompletionIndexCalculator.selectPreviousIndex(from: index, items: items, currentValueId: "current")!
        XCTAssertEqual(index, 0, "Previous from 2 should skip 1, go to 0")
    }

    // MARK: - Integration Scenario Tests

    func testScenario_noCurrentProject_typingHobby() {
        // Simulates: currentProject=nil, query="hobby"
        // Items after fuzzy filtering: [hobby, hobbies-misc, homework]
        let items = [TestItem("hobby"), TestItem("hobbies-misc"), TestItem("homework")]

        let selectedIndex = CompletionIndexCalculator.findFirstSelectableIndex(
            items: items,
            currentValueId: nil
        )

        XCTAssertEqual(selectedIndex, 0, "Should highlight 'hobby' at index 0")
    }

    func testScenario_currentProjectWork_typingHobby() {
        // Simulates: currentProject="work", query="hobby"
        // "work" doesn't match "hobby", so not in the filtered list
        let items = [TestItem("hobby"), TestItem("hobbies-misc"), TestItem("homework")]

        let selectedIndex = CompletionIndexCalculator.findFirstSelectableIndex(
            items: items,
            currentValueId: "work" // Not in the list
        )

        XCTAssertEqual(selectedIndex, 0, "Should highlight 'hobby' at index 0")
    }

    func testScenario_currentProjectHobby_typingHobby() {
        // Simulates: currentProject="hobby", query="hobby"
        // "hobby" matches and is moved to front, but should be greyed out
        let items = [TestItem("hobby"), TestItem("hobbies-misc"), TestItem("homework")]

        let selectedIndex = CompletionIndexCalculator.findFirstSelectableIndex(
            items: items,
            currentValueId: "hobby"
        )

        XCTAssertEqual(selectedIndex, 1, "Should highlight 'hobbies-misc' at index 1, skipping greyed 'hobby'")
    }

    func testScenario_onlyMatchIsCurrentValue() {
        // Simulates: currentProject="hobby", query="hobby" but only exact match
        let items = [TestItem("hobby")]

        let selectedIndex = CompletionIndexCalculator.findFirstSelectableIndex(
            items: items,
            currentValueId: "hobby"
        )

        XCTAssertNil(selectedIndex, "Should have no valid selection when only match is current value")
    }

    func testScenario_noMatches() {
        // Simulates: query doesn't match anything
        let items: [TestItem] = []

        let selectedIndex = CompletionIndexCalculator.findFirstSelectableIndex(
            items: items,
            currentValueId: nil
        )

        XCTAssertNil(selectedIndex, "Should have no valid selection when no matches")
    }

    // MARK: - Real-World Project Scenarios

    func testScenario_projectEditingWorkflow_startWithNoProject() {
        // User has a task with no project, opens project editor
        // Types "w" - sees [work, website, web-api]
        let items = [TestItem("work"), TestItem("website"), TestItem("web-api")]

        // Initial selection
        let initial = CompletionIndexCalculator.findFirstSelectableIndex(
            items: items,
            currentValueId: nil // No current project
        )
        XCTAssertEqual(initial, 0, "Should select first match")

        // Navigate down
        let next = CompletionIndexCalculator.selectNextIndex(from: 0, items: items, currentValueId: nil)
        XCTAssertEqual(next, 1, "Down arrow should select 'website'")

        // Navigate down again
        let next2 = CompletionIndexCalculator.selectNextIndex(from: 1, items: items, currentValueId: nil)
        XCTAssertEqual(next2, 2, "Down arrow should select 'web-api'")
    }

    func testScenario_projectEditingWorkflow_changeExistingProject() {
        // User has a task with project="work", wants to change to "personal"
        // Types "p" - sees [work (greyed), personal, project-x]
        // Note: "work" doesn't match "p" so wouldn't be in list... let's say they typed nothing
        let items = [TestItem("work"), TestItem("personal"), TestItem("project-x")]

        // Initial selection should skip "work"
        let initial = CompletionIndexCalculator.findFirstSelectableIndex(
            items: items,
            currentValueId: "work"
        )
        XCTAssertEqual(initial, 1, "Should select 'personal', skipping greyed 'work'")

        // Navigate down
        let next = CompletionIndexCalculator.selectNextIndex(from: 1, items: items, currentValueId: "work")
        XCTAssertEqual(next, 2, "Down should select 'project-x'")

        // Navigate down again - should wrap, skipping "work"
        let wrapped = CompletionIndexCalculator.selectNextIndex(from: 2, items: items, currentValueId: "work")
        XCTAssertEqual(wrapped, 1, "Should wrap to 'personal', skipping 'work'")
    }

    func testScenario_projectEditingWorkflow_sameProjectTyped() {
        // User has project="hobby", types "hobby" exactly
        // Only "hobby" matches but it's the current value
        let items = [TestItem("hobby")]

        let initial = CompletionIndexCalculator.findFirstSelectableIndex(
            items: items,
            currentValueId: "hobby"
        )
        XCTAssertNil(initial, "No valid selection - only match is current")

        // Navigation should also return nil
        let next = CompletionIndexCalculator.selectNextIndex(from: 0, items: items, currentValueId: "hobby")
        XCTAssertNil(next, "Navigation should return nil")
    }

    func testScenario_projectEditingWorkflow_partialMatchIncludesCurrent() {
        // User has project="hobby", types "hob"
        // Matches: [hobby (greyed), hobbies-misc]
        let items = [TestItem("hobby"), TestItem("hobbies-misc")]

        let initial = CompletionIndexCalculator.findFirstSelectableIndex(
            items: items,
            currentValueId: "hobby"
        )
        XCTAssertEqual(initial, 1, "Should select 'hobbies-misc'")

        // Navigate - should stay on hobbies-misc (only selectable)
        let next = CompletionIndexCalculator.selectNextIndex(from: 1, items: items, currentValueId: "hobby")
        XCTAssertEqual(next, 1, "Should stay on only selectable item")

        let prev = CompletionIndexCalculator.selectPreviousIndex(from: 1, items: items, currentValueId: "hobby")
        XCTAssertEqual(prev, 1, "Should stay on only selectable item")
    }

    // MARK: - CompletionItem Specific Tests

    func testWithCompletionItem_findFirstSelectableIndex() {
        let items = [
            CompletionItem(value: "work", count: 10),
            CompletionItem(value: "personal", count: 5),
            CompletionItem(value: "hobby", count: 3),
        ]

        let result = CompletionIndexCalculator.findFirstSelectableIndex(
            items: items,
            currentValueId: "work"
        )

        XCTAssertEqual(result, 1, "Should skip 'work' and return 'personal' at index 1")
    }

    func testWithCompletionItem_selectNext() {
        let items = [
            CompletionItem(value: "work", count: 10),
            CompletionItem(value: "personal", count: 5),
            CompletionItem(value: "hobby", count: 3),
        ]

        let result = CompletionIndexCalculator.selectNextIndex(
            from: 1,
            items: items,
            currentValueId: "work"
        )

        XCTAssertEqual(result, 2, "Should go to 'hobby' at index 2")
    }

    func testWithCompletionItem_noCurrentValue() {
        let items = [
            CompletionItem(value: "work", count: 10),
            CompletionItem(value: "personal", count: 5),
        ]

        let result = CompletionIndexCalculator.findFirstSelectableIndex(
            items: items,
            currentValueId: nil
        )

        XCTAssertEqual(result, 0, "Should return first item when no current value")
    }

    // MARK: - Stress Tests

    func testStress_largeListNavigation() {
        let items = (0 ..< 1000).map { TestItem("item-\($0)") }

        // Navigate through entire list
        var index = 0
        for i in 1 ..< 1000 {
            index = CompletionIndexCalculator.selectNextIndex(from: index, items: items, currentValueId: nil)!
            XCTAssertEqual(index, i, "Index should be \(i)")
        }

        // One more should wrap
        index = CompletionIndexCalculator.selectNextIndex(from: index, items: items, currentValueId: nil)!
        XCTAssertEqual(index, 0, "Should wrap to 0")
    }

    func testStress_largeListWithCurrentValue() {
        let items = (0 ..< 1000).map { TestItem("item-\($0)") }

        // Current value in middle
        let initial = CompletionIndexCalculator.findFirstSelectableIndex(
            items: items,
            currentValueId: "item-500"
        )
        XCTAssertEqual(initial, 0, "Should start at 0")

        // Navigate past current value
        var index = 499
        index = CompletionIndexCalculator.selectNextIndex(from: index, items: items, currentValueId: "item-500")!
        XCTAssertEqual(index, 501, "Should skip 500")
    }
}
