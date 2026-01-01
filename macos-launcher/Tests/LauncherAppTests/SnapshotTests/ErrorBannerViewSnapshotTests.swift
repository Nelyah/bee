@testable import LauncherApp
import SnapshotTesting
import SwiftUI
import XCTest

/// Snapshot tests for ErrorBannerView.
///
/// Tests error banner display with and without retry action.
final class ErrorBannerViewSnapshotTests: SnapshotTestCase {
    override var isRecording: Bool { false }

    // MARK: - Error Banner Tests

    func testErrorBannerWithRetry() {
        let view = ErrorBannerView(message: "Failed to load task details", onRetry: {})
            .frame(width: 400)
            .padding()
            .background(ThemeManager.current.base)

        assertViewSnapshot(view, size: CGSize(width: 450, height: 80))
    }

    func testErrorBannerWithoutRetry() {
        let view = ErrorBannerView(message: "Could not fetch external links")
            .frame(width: 400)
            .padding()
            .background(ThemeManager.current.base)

        assertViewSnapshot(view, size: CGSize(width: 450, height: 80))
    }

    func testErrorBannerLongMessage() {
        let view = ErrorBannerView(
            message: "Network request timed out. Please check your connection and try again.",
            onRetry: {}
        )
        .frame(width: 400)
        .padding()
        .background(ThemeManager.current.base)

        assertViewSnapshot(view, size: CGSize(width: 450, height: 100))
    }
}
