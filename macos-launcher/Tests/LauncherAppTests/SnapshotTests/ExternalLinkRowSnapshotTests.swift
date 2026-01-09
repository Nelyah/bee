@testable import LauncherAppKit
import SnapshotTesting
import SwiftUI
import XCTest

/// Snapshot tests for ExternalLinkRow to catch visual regressions.
///
/// These tests capture the rendered appearance of external links in various states,
/// including GitLab merge requests with different statuses.
final class ExternalLinkRowSnapshotTests: SnapshotTestCase {
    // MARK: - Generic Link States

    func testGenericLinkDefault() {
        let link = TestHelpers.makeExternalLink(
            url: "https://example.com/docs/getting-started"
        )
        let view = ExternalLinkRow(
            link: link,
            onCopyBranch: { _ in },
            onCopyLink: { _ in }
        )

        assertViewSnapshot(view, size: TestSizes.externalLinkRow)
    }

    func testGenericLinkWithSyncError() {
        let link = TestHelpers.makeExternalLink(
            url: "https://example.com/broken-link",
            syncError: "Connection timeout"
        )
        let view = ExternalLinkRow(
            link: link,
            onCopyBranch: { _ in },
            onCopyLink: { _ in }
        )

        assertViewSnapshot(view, size: TestSizes.externalLinkRow)
    }

    // MARK: - GitLab MR States

    func testGitLabMROpen() {
        let link = TestHelpers.makeGitLabMRLink(
            title: "Add authentication feature",
            state: "opened",
            comments: 5
        )
        let view = ExternalLinkRow(
            link: link,
            onCopyBranch: { _ in },
            onCopyLink: { _ in }
        )

        assertViewSnapshot(view, size: TestSizes.externalLinkRow)
    }

    func testGitLabMRMerged() {
        let link = TestHelpers.makeGitLabMRLink(
            title: "Fix critical bug in login",
            state: "merged",
            comments: 12
        )
        let view = ExternalLinkRow(
            link: link,
            onCopyBranch: { _ in },
            onCopyLink: { _ in }
        )

        assertViewSnapshot(view, size: TestSizes.externalLinkRow)
    }

    func testGitLabMRClosed() {
        let link = TestHelpers.makeGitLabMRLink(
            title: "Experimental feature (rejected)",
            state: "closed",
            comments: 3
        )
        let view = ExternalLinkRow(
            link: link,
            onCopyBranch: { _ in },
            onCopyLink: { _ in }
        )

        assertViewSnapshot(view, size: TestSizes.externalLinkRow)
    }

    // MARK: - Pipeline Status States

    func testGitLabMRWithSuccessPipeline() {
        let link = TestHelpers.makeGitLabMRLink(
            title: "All tests passing",
            state: "opened",
            pipelineStatus: "success"
        )
        let view = ExternalLinkRow(
            link: link,
            onCopyBranch: { _ in },
            onCopyLink: { _ in }
        )

        assertViewSnapshot(view, size: TestSizes.externalLinkRow)
    }

    func testGitLabMRWithFailedPipeline() {
        let link = TestHelpers.makeGitLabMRLink(
            title: "Needs fixes",
            state: "opened",
            pipelineStatus: "failed"
        )
        let view = ExternalLinkRow(
            link: link,
            onCopyBranch: { _ in },
            onCopyLink: { _ in }
        )

        assertViewSnapshot(view, size: TestSizes.externalLinkRow)
    }

    func testGitLabMRWithRunningPipeline() {
        let link = TestHelpers.makeGitLabMRLink(
            title: "CI in progress",
            state: "opened",
            pipelineStatus: "running"
        )
        let view = ExternalLinkRow(
            link: link,
            onCopyBranch: { _ in },
            onCopyLink: { _ in }
        )

        assertViewSnapshot(view, size: TestSizes.externalLinkRow)
    }

    // MARK: - Branch Display

    func testGitLabMRWithLongBranchName() {
        let link = TestHelpers.makeGitLabMRLink(
            title: "Feature implementation",
            state: "opened",
            sourceBranch: "feature/very-long-branch-name-that-might-overflow-ui"
        )
        let view = ExternalLinkRow(
            link: link,
            onCopyBranch: { _ in },
            onCopyLink: { _ in }
        )

        assertViewSnapshot(view, size: TestSizes.externalLinkRowExpanded)
    }

    func testGitLabMRWithShortBranchName() {
        let link = TestHelpers.makeGitLabMRLink(
            title: "Quick fix",
            state: "opened",
            sourceBranch: "fix"
        )
        let view = ExternalLinkRow(
            link: link,
            onCopyBranch: { _ in },
            onCopyLink: { _ in }
        )

        assertViewSnapshot(view, size: TestSizes.externalLinkRow)
    }

    // MARK: - Comment Variations

    func testGitLabMRWithNoComments() {
        let link = TestHelpers.makeGitLabMRLink(
            title: "New MR without discussion",
            state: "opened",
            comments: 0
        )
        let view = ExternalLinkRow(
            link: link,
            onCopyBranch: { _ in },
            onCopyLink: { _ in }
        )

        assertViewSnapshot(view, size: TestSizes.externalLinkRow)
    }

    func testGitLabMRWithManyComments() {
        let link = TestHelpers.makeGitLabMRLink(
            title: "Heavily discussed MR",
            state: "opened",
            comments: 156
        )
        let view = ExternalLinkRow(
            link: link,
            onCopyBranch: { _ in },
            onCopyLink: { _ in }
        )

        assertViewSnapshot(view, size: TestSizes.externalLinkRow)
    }

    // MARK: - Title Variations

    func testGitLabMRWithLongTitle() {
        let link = TestHelpers.makeGitLabMRLink(
            title: "This is a very long merge request title that describes a complex feature implementation with many details",
            state: "opened"
        )
        let view = ExternalLinkRow(
            link: link,
            onCopyBranch: { _ in },
            onCopyLink: { _ in }
        )

        assertViewSnapshot(view, size: TestSizes.externalLinkRowExpanded)
    }

    func testGitLabMRWithShortTitle() {
        let link = TestHelpers.makeGitLabMRLink(
            title: "Fix",
            state: "opened"
        )
        let view = ExternalLinkRow(
            link: link,
            onCopyBranch: { _ in },
            onCopyLink: { _ in }
        )

        assertViewSnapshot(view, size: TestSizes.externalLinkRow)
    }

    // MARK: - Without Cached Response

    func testLinkWithoutCachedResponse() {
        let link = TestHelpers.makeExternalLink(
            url: "https://gitlab.com/org/repo/-/merge_requests/456",
            externalKey: "org/repo!456",
            cachedResponse: nil,
            lastSyncedAt: nil
        )
        let view = ExternalLinkRow(
            link: link,
            onCopyBranch: { _ in },
            onCopyLink: { _ in }
        )

        assertViewSnapshot(view, size: TestSizes.externalLinkRow)
    }
}
