@testable import LauncherApp
import SnapshotTesting
import SwiftUI
import XCTest

/// Snapshot tests for TaskRowLinksPreview and TaskRowAnnotationsPreview.
///
/// These tests capture the visual appearance of preview components
/// used in expanded task rows.
final class TaskRowPreviewsSnapshotTests: SnapshotTestCase {
    // MARK: - TaskRowLinksPreview Tests

    func testLinksPreviewEmpty() {
        let view = TaskRowLinksPreview(links: [])

        assertViewSnapshot(view, size: TestSizes.linksPreview)
    }

    func testLinksPreviewSingleLink() {
        let links = [
            TestHelpers.makeGitLabMRLink(
                iid: 42,
                title: "Add feature",
                state: "opened"
            ),
        ]
        let view = TaskRowLinksPreview(links: links)

        assertViewSnapshot(view, size: TestSizes.linksPreview)
    }

    func testLinksPreviewTwoLinks() {
        let links = [
            TestHelpers.makeGitLabMRLink(
                id: 1,
                iid: 42,
                title: "Main feature",
                state: "opened"
            ),
            TestHelpers.makeGitLabMRLink(
                id: 2,
                iid: 43,
                title: "Follow-up",
                state: "merged"
            ),
        ]
        let view = TaskRowLinksPreview(links: links)

        assertViewSnapshot(view, size: CGSize(width: 500, height: 60))
    }

    func testLinksPreviewThreeLinks() {
        let links = [
            TestHelpers.makeGitLabMRLink(id: 1, iid: 100, title: "First MR", state: "opened"),
            TestHelpers.makeGitLabMRLink(id: 2, iid: 101, title: "Second MR", state: "merged"),
            TestHelpers.makeGitLabMRLink(id: 3, iid: 102, title: "Third MR", state: "closed"),
        ]
        let view = TaskRowLinksPreview(links: links)

        assertViewSnapshot(view, size: CGSize(width: 500, height: 60))
    }

    func testLinksPreviewWithOverflow() {
        let links = (1 ... 5).map { i in
            TestHelpers.makeGitLabMRLink(
                id: i,
                iid: 100 + i,
                title: "MR \(i)",
                state: "opened"
            )
        }
        let view = TaskRowLinksPreview(links: links, maxVisible: 3)

        // Should show 3 links + "+2 more" indicator
        assertViewSnapshot(view, size: CGSize(width: 500, height: 60))
    }

    func testLinksPreviewMixedStates() {
        let links = [
            TestHelpers.makeGitLabMRLink(id: 1, iid: 10, state: "opened"),
            TestHelpers.makeGitLabMRLink(id: 2, iid: 11, state: "merged"),
            TestHelpers.makeGitLabMRLink(id: 3, iid: 12, state: "closed"),
        ]
        let view = TaskRowLinksPreview(links: links)

        assertViewSnapshot(view, size: CGSize(width: 500, height: 60))
    }

    // MARK: - TaskRowAnnotationsPreview Tests

    func testAnnotationsPreviewEmpty() {
        let view = TaskRowAnnotationsPreview(annotations: [])

        assertViewSnapshot(view, size: TestSizes.annotationsPreview)
    }

    func testAnnotationsPreviewSingle() {
        let annotations = [
            TestHelpers.makeAnnotation(
                value: "Follow up with QA team",
                time: "2024-01-15T10:30:00Z"
            ),
        ]
        let view = TaskRowAnnotationsPreview(annotations: annotations)

        assertViewSnapshot(view, size: TestSizes.annotationsPreview)
    }

    func testAnnotationsPreviewTwo() {
        let annotations = [
            TestHelpers.makeAnnotation(value: "Latest update", time: "2024-01-16T14:00:00Z"),
            TestHelpers.makeAnnotation(value: "Initial note", time: "2024-01-15T09:00:00Z"),
        ]
        let view = TaskRowAnnotationsPreview(annotations: annotations)

        assertViewSnapshot(view, size: CGSize(width: 500, height: 80))
    }

    func testAnnotationsPreviewWithOverflow() {
        let annotations = [
            TestHelpers.makeAnnotation(value: "First annotation", time: "2024-01-18T10:00:00Z"),
            TestHelpers.makeAnnotation(value: "Second annotation", time: "2024-01-17T10:00:00Z"),
            TestHelpers.makeAnnotation(value: "Third annotation", time: "2024-01-16T10:00:00Z"),
            TestHelpers.makeAnnotation(value: "Fourth annotation", time: "2024-01-15T10:00:00Z"),
        ]
        let view = TaskRowAnnotationsPreview(annotations: annotations, maxVisible: 2)

        // Should show 2 annotations + "+2 more" indicator
        assertViewSnapshot(view, size: CGSize(width: 500, height: 100))
    }

    func testAnnotationsPreviewLongText() {
        let annotations = [
            TestHelpers.makeAnnotation(
                value: "This is a very long annotation that might wrap to multiple lines and tests how the component handles text overflow",
                time: "2024-01-15T10:00:00Z"
            ),
        ]
        let view = TaskRowAnnotationsPreview(annotations: annotations)

        assertViewSnapshot(view, size: CGSize(width: 500, height: 80))
    }

    func testAnnotationsPreviewMaxVisibleCustom() {
        let annotations = [
            TestHelpers.makeAnnotation(value: "Note 1", time: "2024-01-18T10:00:00Z"),
            TestHelpers.makeAnnotation(value: "Note 2", time: "2024-01-17T10:00:00Z"),
            TestHelpers.makeAnnotation(value: "Note 3", time: "2024-01-16T10:00:00Z"),
        ]
        let view = TaskRowAnnotationsPreview(annotations: annotations, maxVisible: 1)

        // Should show 1 annotation + "+2 more" indicator
        assertViewSnapshot(view, size: CGSize(width: 500, height: 80))
    }
}
