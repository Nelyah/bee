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
    static func isValidIndex<T>(_ index: Int, for items: [T]) -> Bool {
        items.indices.contains(index)
    }
}
