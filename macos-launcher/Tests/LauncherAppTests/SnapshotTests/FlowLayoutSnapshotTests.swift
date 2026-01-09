@testable import LauncherAppKit
import SnapshotTesting
import SwiftUI
import XCTest

/// Snapshot tests for FlowLayout to verify wrapping behavior.
///
/// FlowLayout is a custom Layout that wraps items to new rows when
/// they exceed the available width. These tests verify the layout
/// behavior across different configurations.
final class FlowLayoutSnapshotTests: SnapshotTestCase {
    // MARK: - Helper Views

    /// A simple tag-like chip for testing layout behavior
    private struct TestChip: View {
        let text: String
        let color: Color

        init(_ text: String, color: Color = .blue) {
            self.text = text
            self.color = color
        }

        var body: some View {
            Text(text)
                .font(.system(size: 12))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(color.opacity(0.2))
                .foregroundColor(color)
                .clipShape(Capsule())
        }
    }

    // MARK: - Empty Layout

    func testEmptyLayout() {
        let view = FlowLayout {
            // Empty content
        }
        .frame(width: 400, height: 50)
        .background(Color.gray.opacity(0.1))

        assertViewSnapshot(view, size: CGSize(width: 400, height: 50))
    }

    // MARK: - Single Row

    func testSingleItem() {
        let view = FlowLayout {
            TestChip("Swift")
        }
        .frame(width: 400, height: 50)
        .background(Color.gray.opacity(0.1))

        assertViewSnapshot(view, size: CGSize(width: 400, height: 50))
    }

    func testFewItemsFitInRow() {
        let view = FlowLayout {
            TestChip("Swift", color: .blue)
            TestChip("iOS", color: .green)
            TestChip("macOS", color: .purple)
        }
        .frame(width: 400, height: 50)
        .background(Color.gray.opacity(0.1))

        assertViewSnapshot(view, size: CGSize(width: 400, height: 50))
    }

    func testItemsFillSingleRow() {
        let view = FlowLayout {
            TestChip("SwiftUI", color: .blue)
            TestChip("UIKit", color: .green)
            TestChip("AppKit", color: .purple)
            TestChip("Core Data", color: .orange)
        }
        .frame(width: 400, height: 50)
        .background(Color.gray.opacity(0.1))

        assertViewSnapshot(view, size: CGSize(width: 400, height: 50))
    }

    // MARK: - Multiple Rows

    func testItemsWrapToSecondRow() {
        let view = FlowLayout {
            TestChip("SwiftUI", color: .blue)
            TestChip("UIKit", color: .green)
            TestChip("AppKit", color: .purple)
            TestChip("Core Data", color: .orange)
            TestChip("Combine", color: .pink)
            TestChip("Foundation", color: .teal)
        }
        .frame(width: 300, height: 80)
        .background(Color.gray.opacity(0.1))

        assertViewSnapshot(view, size: CGSize(width: 300, height: 80))
    }

    func testManyItemsWrapMultipleRows() {
        let view = FlowLayout {
            TestChip("Swift", color: .blue)
            TestChip("iOS", color: .green)
            TestChip("macOS", color: .purple)
            TestChip("watchOS", color: .orange)
            TestChip("tvOS", color: .pink)
            TestChip("visionOS", color: .teal)
            TestChip("iPadOS", color: .red)
            TestChip("CarPlay", color: .yellow)
        }
        .frame(width: 300, height: 120)
        .background(Color.gray.opacity(0.1))

        assertViewSnapshot(view, size: CGSize(width: 300, height: 120))
    }

    // MARK: - Varying Item Widths

    func testVaryingWidths() {
        let view = FlowLayout {
            TestChip("A", color: .blue)
            TestChip("Long label here", color: .green)
            TestChip("B", color: .purple)
            TestChip("Another long one", color: .orange)
            TestChip("C", color: .pink)
        }
        .frame(width: 300, height: 100)
        .background(Color.gray.opacity(0.1))

        assertViewSnapshot(view, size: CGSize(width: 300, height: 100))
    }

    func testVeryLongItemWraps() {
        let view = FlowLayout {
            TestChip("Short", color: .blue)
            TestChip("This is a very long label that might need special handling", color: .green)
            TestChip("Short", color: .purple)
        }
        .frame(width: 300, height: 100)
        .background(Color.gray.opacity(0.1))

        assertViewSnapshot(view, size: CGSize(width: 300, height: 100))
    }

    // MARK: - Different Spacings

    func testCustomSpacing() {
        let view = FlowLayout(spacing: 16, rowSpacing: 16) {
            TestChip("Swift", color: .blue)
            TestChip("iOS", color: .green)
            TestChip("macOS", color: .purple)
            TestChip("watchOS", color: .orange)
            TestChip("tvOS", color: .pink)
        }
        .frame(width: 300, height: 100)
        .background(Color.gray.opacity(0.1))

        assertViewSnapshot(view, size: CGSize(width: 300, height: 100))
    }

    func testTightSpacing() {
        let view = FlowLayout(spacing: 2, rowSpacing: 2) {
            TestChip("A", color: .blue)
            TestChip("B", color: .green)
            TestChip("C", color: .purple)
            TestChip("D", color: .orange)
            TestChip("E", color: .pink)
            TestChip("F", color: .teal)
        }
        .frame(width: 200, height: 80)
        .background(Color.gray.opacity(0.1))

        assertViewSnapshot(view, size: CGSize(width: 200, height: 80))
    }

    // MARK: - Width Constraints

    func testNarrowWidth() {
        let view = FlowLayout {
            TestChip("Swift", color: .blue)
            TestChip("iOS", color: .green)
            TestChip("macOS", color: .purple)
        }
        .frame(width: 100, height: 120)
        .background(Color.gray.opacity(0.1))

        assertViewSnapshot(view, size: CGSize(width: 100, height: 120))
    }

    func testWideWidth() {
        let view = FlowLayout {
            TestChip("Swift", color: .blue)
            TestChip("iOS", color: .green)
            TestChip("macOS", color: .purple)
            TestChip("watchOS", color: .orange)
            TestChip("tvOS", color: .pink)
            TestChip("visionOS", color: .teal)
        }
        .frame(width: 600, height: 50)
        .background(Color.gray.opacity(0.1))

        assertViewSnapshot(view, size: CGSize(width: 600, height: 50))
    }
}
