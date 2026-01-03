import Foundation

/// Pure function calculator for completion field index logic.
///
/// This struct extracts the index calculation logic from CompletionField
/// for testability. All methods are static and pure (no side effects).
///
/// ## Index Rules
///
/// 1. The `currentValue` (if present and in the list) should be greyed out and not selectable
/// 2. `findFirstSelectableIndex` returns the first index that is NOT the currentValue
/// 3. When no valid selection exists, returns `nil` (NOT 0, which could be invalid)
/// 4. Navigation (`selectNext`/`selectPrevious`) wraps around and skips currentValue
///
enum CompletionIndexCalculator {
    /// Finds the first selectable index in a list of items, skipping the currentValue.
    ///
    /// - Parameters:
    ///   - items: Array of items to search
    ///   - currentValueId: The ID of the current value to skip (nil if no current value)
    /// - Returns: The first valid index, or nil if no valid selection exists
    static func findFirstSelectableIndex<T: Identifiable>(
        items: [T],
        currentValueId: T.ID?
    ) -> Int? {
        for (index, item) in items.enumerated() {
            if currentValueId != item.id {
                return index
            }
        }
        return nil
    }

    /// Calculates the next selectable index when navigating forward.
    ///
    /// - Parameters:
    ///   - currentIndex: The current selected index
    ///   - items: Array of items
    ///   - currentValueId: The ID of the current value to skip
    /// - Returns: The next valid index, or nil if no valid selection exists
    static func selectNextIndex<T: Identifiable>(
        from currentIndex: Int,
        items: [T],
        currentValueId: T.ID?
    ) -> Int? {
        guard !items.isEmpty else { return nil }

        let count = items.count
        var nextIndex = currentIndex

        // Try all positions (worst case: all items except one are currentValue)
        for _ in 0 ..< count {
            nextIndex = (nextIndex + 1) % count
            if currentValueId != items[nextIndex].id {
                return nextIndex
            }
        }

        return nil
    }

    /// Calculates the previous selectable index when navigating backward.
    ///
    /// - Parameters:
    ///   - currentIndex: The current selected index
    ///   - items: Array of items
    ///   - currentValueId: The ID of the current value to skip
    /// - Returns: The previous valid index, or nil if no valid selection exists
    static func selectPreviousIndex<T: Identifiable>(
        from currentIndex: Int,
        items: [T],
        currentValueId: T.ID?
    ) -> Int? {
        guard !items.isEmpty else { return nil }

        let count = items.count
        var prevIndex = currentIndex

        // Try all positions
        for _ in 0 ..< count {
            prevIndex = (prevIndex - 1 + count) % count
            if currentValueId != items[prevIndex].id {
                return prevIndex
            }
        }

        return nil
    }

    /// Validates whether a selected index is safe to use.
    ///
    /// - Parameters:
    ///   - index: The index to validate
    ///   - items: The array being indexed
    /// - Returns: true if the index is within bounds
    static func isValidIndex(_ index: Int, for items: [some Any]) -> Bool {
        items.indices.contains(index)
    }

    /// Calculates the previous selectable index, allowing navigation to "no selection" state.
    ///
    /// Unlike `selectPreviousIndex` which wraps around, this method returns -1 when
    /// at the first selectable index, enabling the user to unselect all items.
    ///
    /// - Parameters:
    ///   - currentIndex: The current selected index (-1 means no selection)
    ///   - items: Array of items
    ///   - currentValueId: The ID of the current value to skip
    /// - Returns: The previous valid index, -1 to indicate "no selection", or nil if already at -1
    static func selectPreviousIndexAllowingUnselect<T: Identifiable>(
        from currentIndex: Int,
        items: [T],
        currentValueId: T.ID?
    ) -> Int? {
        // If already at no-selection, stay there
        guard currentIndex >= 0 else { return nil }

        // If at first selectable index, go to no-selection
        let firstSelectable = findFirstSelectableIndex(items: items, currentValueId: currentValueId)
        if currentIndex == firstSelectable {
            return -1
        }

        // Find previous selectable index (without wrapping)
        var prevIndex = currentIndex - 1
        while prevIndex >= 0 {
            if currentValueId != items[prevIndex].id {
                return prevIndex
            }
            prevIndex -= 1
        }

        // Reached the beginning, go to no-selection
        return -1
    }
}
