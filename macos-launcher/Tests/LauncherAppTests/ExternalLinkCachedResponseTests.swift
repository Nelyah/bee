@testable import LauncherApp
import XCTest

final class ExternalLinkCachedResponseTests: XCTestCase {
    func testParsesGitlabCachedSummary() {
        let cached = """
        {"merge_request":{"title":"Improve task sync","state":"opened","user_notes_count":12,"head_pipeline":{"status":"running"}},"approvals":{"approved":false}}
        """
        let link = ExternalLinkDto(
            id: 1,
            provider: "gitlab",
            url: "https://gitlab.example.com/group/project/-/merge_requests/42",
            externalKey: "mr:group/project:42",
            cachedResponse: cached,
            lastSyncedAt: nil,
            syncError: nil
        )

        guard let summary = link.cachedSummary() else {
            XCTFail("Expected cached summary")
            return
        }

        switch summary {
        case let .gitlab(gitlab):
            XCTAssertEqual(gitlab.title, "Improve task sync")
            XCTAssertEqual(gitlab.state, "opened")
            XCTAssertEqual(gitlab.comments, 12)
            XCTAssertEqual(gitlab.pipelineStatus, "running")
            XCTAssertEqual(gitlab.approved, false)
        case .jira:
            XCTFail("Expected gitlab summary")
        }
    }

    func testParsesJiraCachedSummary() {
        let cached = """
        {"fields":{"summary":"Add command palette","status":{"name":"In Progress"}}}
        """
        let link = ExternalLinkDto(
            id: 2,
            provider: "jira",
            url: "https://jira.example.com/browse/BEE-101",
            externalKey: "BEE-101",
            cachedResponse: cached,
            lastSyncedAt: nil,
            syncError: nil
        )

        guard let summary = link.cachedSummary() else {
            XCTFail("Expected cached summary")
            return
        }

        switch summary {
        case let .jira(jira):
            XCTAssertEqual(jira.summary, "Add command palette")
            XCTAssertEqual(jira.status, "In Progress")
        case .gitlab:
            XCTFail("Expected jira summary")
        }
    }
}
