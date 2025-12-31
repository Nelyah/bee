@testable import LauncherApp
import XCTest

final class ExternalLinkModelsTests: XCTestCase {
    // MARK: - GitlabMergeRequestState Tests

    func testGitlabMergeRequestStateDecodesOpened() throws {
        let json = #""opened""#
        let state = try decode(GitlabMergeRequestState.self, from: json)
        XCTAssertEqual(state, .opened)
    }

    func testGitlabMergeRequestStateDecodesOpen() throws {
        let json = #""open""#
        let state = try decode(GitlabMergeRequestState.self, from: json)
        XCTAssertEqual(state, .opened)
    }

    func testGitlabMergeRequestStateDecodesMerged() throws {
        let json = #""merged""#
        let state = try decode(GitlabMergeRequestState.self, from: json)
        XCTAssertEqual(state, .merged)
    }

    func testGitlabMergeRequestStateDecodesClosed() throws {
        let json = #""closed""#
        let state = try decode(GitlabMergeRequestState.self, from: json)
        XCTAssertEqual(state, .closed)
    }

    func testGitlabMergeRequestStateDecodesUnknown() throws {
        let json = #""draft""#
        let state = try decode(GitlabMergeRequestState.self, from: json)
        XCTAssertEqual(state, .unknown("draft"))
    }

    func testGitlabMergeRequestStateIconName() {
        XCTAssertEqual(GitlabMergeRequestState.opened.iconName, "pr-open")
        XCTAssertEqual(GitlabMergeRequestState.merged.iconName, "pr-merged")
        XCTAssertEqual(GitlabMergeRequestState.closed.iconName, "pr-closed")
        XCTAssertEqual(GitlabMergeRequestState.unknown("draft").iconName, "pr-open")
    }

    func testGitlabMergeRequestStateFromRaw() {
        XCTAssertEqual(GitlabMergeRequestState.fromRaw("opened"), .opened)
        XCTAssertEqual(GitlabMergeRequestState.fromRaw("OPENED"), .opened)
        XCTAssertEqual(GitlabMergeRequestState.fromRaw("open"), .opened)
        XCTAssertEqual(GitlabMergeRequestState.fromRaw("merged"), .merged)
        XCTAssertEqual(GitlabMergeRequestState.fromRaw("closed"), .closed)
        XCTAssertEqual(GitlabMergeRequestState.fromRaw("unknown_state"), .unknown("unknown_state"))
    }

    // MARK: - GitlabPipelineStatus Tests

    func testGitlabPipelineStatusDecodesAllStates() throws {
        let states: [(String, GitlabPipelineStatus)] = [
            ("success", .success),
            ("running", .running),
            ("pending", .pending),
            ("failed", .failed),
            ("canceled", .canceled),
            ("skipped", .skipped),
        ]

        for (json, expected) in states {
            let status = try decode(GitlabPipelineStatus.self, from: #""\#(json)""#)
            XCTAssertEqual(status, expected, "Failed for \(json)")
        }
    }

    func testGitlabPipelineStatusDecodesUnknown() throws {
        let json = #""manual""#
        let status = try decode(GitlabPipelineStatus.self, from: json)
        XCTAssertEqual(status, .unknown("manual"))
    }

    func testGitlabPipelineStatusIconName() {
        XCTAssertEqual(GitlabPipelineStatus.success.iconName, "gitlab-success")
        XCTAssertEqual(GitlabPipelineStatus.running.iconName, "gitlab-running")
        XCTAssertEqual(GitlabPipelineStatus.pending.iconName, "gitlab-pending")
        XCTAssertEqual(GitlabPipelineStatus.failed.iconName, "gitlab-pending")
        XCTAssertEqual(GitlabPipelineStatus.canceled.iconName, "gitlab-pending")
        XCTAssertEqual(GitlabPipelineStatus.skipped.iconName, "gitlab-pending")
        XCTAssertNil(GitlabPipelineStatus.unknown("manual").iconName)
    }

    func testGitlabPipelineStatusLabel() {
        XCTAssertEqual(GitlabPipelineStatus.success.label, "Passed")
        XCTAssertEqual(GitlabPipelineStatus.failed.label, "Failed")
        XCTAssertEqual(GitlabPipelineStatus.running.label, "Running")
        XCTAssertEqual(GitlabPipelineStatus.pending.label, "Pending")
        XCTAssertEqual(GitlabPipelineStatus.canceled.label, "Canceled")
        XCTAssertEqual(GitlabPipelineStatus.skipped.label, "Skipped")
        XCTAssertEqual(GitlabPipelineStatus.unknown("manual").label, "Manual")
    }

    func testGitlabPipelineStatusFromRaw() {
        XCTAssertEqual(GitlabPipelineStatus.fromRaw("success"), .success)
        XCTAssertEqual(GitlabPipelineStatus.fromRaw("SUCCESS"), .success)
        XCTAssertEqual(GitlabPipelineStatus.fromRaw("running"), .running)
        XCTAssertEqual(GitlabPipelineStatus.fromRaw("unknown_status"), .unknown("unknown_status"))
    }

    // MARK: - JiraIssueSuggestion Tests

    func testJiraIssueSuggestionDecodes() throws {
        let json = """
        {
            "key": "BEE-123",
            "summary": "Add dark mode",
            "status": "In Progress",
            "web_url": "https://jira.example.com/browse/BEE-123",
            "updated_at": "2024-01-15T10:30:00Z"
        }
        """
        let suggestion = try decode(JiraIssueSuggestion.self, from: json)
        XCTAssertEqual(suggestion.key, "BEE-123")
        XCTAssertEqual(suggestion.summary, "Add dark mode")
        XCTAssertEqual(suggestion.status, "In Progress")
        XCTAssertEqual(suggestion.webURL, "https://jira.example.com/browse/BEE-123")
        XCTAssertEqual(suggestion.id, "BEE-123")
    }

    // MARK: - GitlabMergeRequestSuggestion Tests

    func testGitlabMergeRequestSuggestionDecodes() throws {
        let json = """
        {
            "iid": 42,
            "title": "Fix bug",
            "web_url": "https://gitlab.example.com/group/project/-/merge_requests/42",
            "project_path": "group/project",
            "state": "opened",
            "updated_at": "2024-01-15T10:30:00Z",
            "user_notes_count": 5,
            "approved": true,
            "pipeline_status": "success"
        }
        """
        let suggestion = try decode(GitlabMergeRequestSuggestion.self, from: json)
        XCTAssertEqual(suggestion.id, 42)
        XCTAssertEqual(suggestion.title, "Fix bug")
        XCTAssertEqual(suggestion.projectPath, "group/project")
        XCTAssertEqual(suggestion.state, .opened)
        XCTAssertEqual(suggestion.notesCount, 5)
        XCTAssertEqual(suggestion.approved, true)
        XCTAssertEqual(suggestion.pipelineStatus, .success)
    }

    // MARK: - ExternalLinkDto Tests

    func testExternalLinkDtoDecodes() throws {
        let json = """
        {
            "id": 1,
            "provider": "gitlab",
            "url": "https://gitlab.example.com/merge_requests/42",
            "external_key": "mr:group/project:42",
            "cached_response": null,
            "last_synced_at": null,
            "sync_error": null
        }
        """
        let dto = try decode(ExternalLinkDto.self, from: json)
        XCTAssertEqual(dto.id, 1)
        XCTAssertEqual(dto.provider, "gitlab")
        XCTAssertEqual(dto.externalKey, "mr:group/project:42")
        XCTAssertNil(dto.cachedResponse)
    }

    func testExternalLinkSyncStatePending() {
        let link = makeExternalLinkDto(lastSyncedAt: nil, syncError: nil)
        XCTAssertEqual(link.syncState(), .pending)
    }

    func testExternalLinkSyncStateError() {
        let link = makeExternalLinkDto(lastSyncedAt: nil, syncError: "Connection failed")
        if case let .error(message) = link.syncState() {
            XCTAssertEqual(message, "Connection failed")
        } else {
            XCTFail("Expected error state")
        }
    }

    func testExternalLinkSyncStateSynced() {
        let recentDate = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600))
        let link = makeExternalLinkDto(lastSyncedAt: recentDate, syncError: nil)
        if case .synced = link.syncState() {
            // Success
        } else {
            XCTFail("Expected synced state")
        }
    }

    func testExternalLinkSyncStateStale() {
        let oldDate = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-86401))
        let link = makeExternalLinkDto(lastSyncedAt: oldDate, syncError: nil)
        if case .stale = link.syncState() {
            // Success
        } else {
            XCTFail("Expected stale state")
        }
    }

    // MARK: - ExternalLinkSyncResponse Tests

    func testExternalLinkSyncResponseDecodes() throws {
        let json = """
        {
            "attempted": 5,
            "succeeded": 4,
            "failed": 1,
            "errors": ["Connection timeout"]
        }
        """
        let response = try decode(ExternalLinkSyncResponse.self, from: json)
        XCTAssertEqual(response.attempted, 5)
        XCTAssertEqual(response.succeeded, 4)
        XCTAssertEqual(response.failed, 1)
        XCTAssertEqual(response.errors, ["Connection timeout"])
    }

    // MARK: - ExternalLinkProvider Tests

    func testExternalLinkProviderRawValues() {
        XCTAssertEqual(ExternalLinkProvider.gitlab.rawValue, "gitlab")
        XCTAssertEqual(ExternalLinkProvider.jira.rawValue, "jira")
    }

    // MARK: - JiraIssueScope Tests

    func testJiraIssueScopeRawValues() {
        XCTAssertEqual(JiraIssueScope.assigned.rawValue, "assigned")
        XCTAssertEqual(JiraIssueScope.created.rawValue, "created")
        XCTAssertEqual(JiraIssueScope.both.rawValue, "both")
    }

    // MARK: - Helpers

    private func decode<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
        let data = json.data(using: .utf8)!
        return try JSONDecoder().decode(type, from: data)
    }

    private func makeExternalLinkDto(
        lastSyncedAt: String?,
        syncError: String?
    ) -> ExternalLinkDto {
        ExternalLinkDto(
            id: 1,
            provider: "gitlab",
            url: "https://gitlab.example.com/merge_requests/42",
            externalKey: "mr:group/project:42",
            cachedResponse: nil,
            lastSyncedAt: lastSyncedAt,
            syncError: syncError
        )
    }
}
