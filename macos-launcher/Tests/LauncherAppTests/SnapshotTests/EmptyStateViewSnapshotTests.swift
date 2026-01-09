@testable import LauncherAppKit
import SnapshotTesting
import SwiftUI
import XCTest

/// Snapshot tests for EmptyStateView.
///
/// Tests the two states of the empty task list:
/// - No tasks exist yet (first-run experience)
/// - Filters are active but no tasks match
final class EmptyStateViewSnapshotTests: SnapshotTestCase {
    // MARK: - Empty State Tests

    func testEmptyStateNoFilters() {
        let view = EmptyStateView(hasActiveFilters: false)
            .frame(width: 400, height: 300)
            .background(ThemeManager.current.base)

        assertViewSnapshot(view, size: CGSize(width: 400, height: 300))
    }

    func testEmptyStateWithFilters() {
        let view = EmptyStateView(hasActiveFilters: true)
            .frame(width: 400, height: 300)
            .background(ThemeManager.current.base)

        assertViewSnapshot(view, size: CGSize(width: 400, height: 300))
    }
}
