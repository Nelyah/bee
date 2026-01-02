import SnapshotTesting
import SwiftUI
import XCTest

/// Base class for snapshot tests providing common configuration.
///
/// Snapshot tests capture rendered views as images and compare them against
/// stored reference images. This catches visual regressions like layout
/// changes, styling issues, and theming problems.
///
/// ## Usage
/// ```swift
/// final class MyViewSnapshotTests: SnapshotTestCase {
///     func testMyView() {
///         let view = MyView()
///         assertViewSnapshot(view, named: "default")
///     }
/// }
/// ```
///
/// ## Recording Snapshots
/// To record new snapshots without code changes, use the environment variable:
/// ```bash
/// RECORD_SNAPSHOTS=1 swift test --filter "MyViewSnapshotTests"
/// ```
///
/// Or record all snapshots:
/// ```bash
/// RECORD_SNAPSHOTS=1 swift test
/// ```
///
/// ## Reference Images
/// Reference images are stored in `__Snapshots__` directories alongside tests.
/// On first run, or when recording is enabled, new reference images are created.
class SnapshotTestCase: XCTestCase {
    /// Whether to record new reference snapshots.
    ///
    /// Checks `RECORD_SNAPSHOTS` environment variable first, then falls back to
    /// subclass override. Set `RECORD_SNAPSHOTS=1` to record without code changes.
    var isRecording: Bool {
        ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] == "1"
    }

    // MARK: - Snapshot Helpers

    /// Assert a SwiftUI view matches its reference snapshot.
    ///
    /// - Parameters:
    ///   - view: The SwiftUI view to snapshot
    ///   - named: Optional name suffix for the snapshot file
    ///   - size: The size to render the view at (defaults to intrinsic size)
    ///   - precision: Pixel matching precision (0.0-1.0, default 0.99)
    ///   - file: Source file for failure reporting
    ///   - testName: Test function name for file naming
    ///   - line: Source line for failure reporting
    func assertViewSnapshot(
        _ view: some View,
        named name: String? = nil,
        size: CGSize? = nil,
        precision: Float = 0.99,
        waitForAsync: Bool = false,
        file: StaticString = #file,
        testName: String = #function,
        line: UInt = #line
    ) {
        let hostView = NSHostingView(rootView: view)

        if let size {
            hostView.frame = CGRect(origin: .zero, size: size)
        } else {
            // Use intrinsic content size
            hostView.frame.size = hostView.intrinsicContentSize
        }

        // Allow async operations (like DispatchQueue.main.async in onAppear) to complete
        if waitForAsync {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
        }

        assertSnapshot(
            of: hostView,
            as: .image(precision: precision),
            named: name,
            record: isRecording,
            file: file,
            testName: testName,
            line: line
        )
    }

    /// Assert a SwiftUI view matches its reference snapshot at multiple sizes.
    ///
    /// Useful for testing responsive layouts.
    ///
    /// - Parameters:
    ///   - view: The SwiftUI view to snapshot
    ///   - sizes: Dictionary of name -> size pairs to test
    ///   - precision: Pixel matching precision
    ///   - file: Source file for failure reporting
    ///   - testName: Test function name for file naming
    ///   - line: Source line for failure reporting
    func assertViewSnapshots(
        _ view: some View,
        sizes: [String: CGSize],
        precision: Float = 0.99,
        file: StaticString = #file,
        testName: String = #function,
        line: UInt = #line
    ) {
        for (name, size) in sizes {
            assertViewSnapshot(
                view,
                named: name,
                size: size,
                precision: precision,
                file: file,
                testName: testName,
                line: line
            )
        }
    }
}

// MARK: - Common Test Sizes

extension SnapshotTestCase {
    /// Common sizes for testing responsive layouts.
    enum TestSizes {
        /// Compact width (e.g., narrow sidebar)
        static let compact = CGSize(width: 300, height: 400)

        /// Regular width (typical main content)
        static let regular = CGSize(width: 520, height: 600)

        /// Wide layout (full window)
        static let wide = CGSize(width: 800, height: 600)

        /// Task row at typical width
        static let taskRow = CGSize(width: 600, height: 60)

        /// Task row expanded
        static let taskRowExpanded = CGSize(width: 600, height: 150)

        /// Command palette
        static let commandPalette = CGSize(width: 520, height: 400)

        /// Task detail view - compact (single column)
        static let detailViewCompact = CGSize(width: 400, height: 600)

        /// Task detail view - wide (two columns)
        static let detailViewWide = CGSize(width: 800, height: 600)

        /// Completion menu dropdown
        static let completionMenu = CGSize(width: 300, height: 200)

        /// External link row
        static let externalLinkRow = CGSize(width: 500, height: 80)

        /// External link row - GitLab MR with full details
        static let externalLinkRowExpanded = CGSize(width: 500, height: 120)

        /// Criteria strip for filters
        static let criteriaStrip = CGSize(width: 600, height: 60)

        /// Save report sheet dialog
        static let saveReportSheet = CGSize(width: 400, height: 300)

        /// Flow layout for wrapping items
        static let flowLayout = CGSize(width: 400, height: 150)

        /// Task row links preview
        static let linksPreview = CGSize(width: 500, height: 40)

        /// Task row annotations preview
        static let annotationsPreview = CGSize(width: 500, height: 60)

        /// Simple button/chip components
        static let smallComponent = CGSize(width: 200, height: 40)

        /// Timeline row
        static let timelineRow = CGSize(width: 400, height: 30)

        /// Task list view (search + list)
        static let taskListView = CGSize(width: 600, height: 500)

        /// Task list view - compact
        static let taskListViewCompact = CGSize(width: 400, height: 400)

        /// Content view - full window
        static let contentView = CGSize(width: 680, height: 440)

        /// Token highlight text input
        static let tokenInput = CGSize(width: 400, height: 50)

        /// Report menu button
        static let reportMenuButton = CGSize(width: 150, height: 30)
    }
}
