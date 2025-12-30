import XCTest
@testable import LauncherApp

@MainActor
final class LauncherActionServiceTests: XCTestCase {
    func testLoadConfigCachesReport() async throws {
        let mock = MockApiClient()
        let service = LauncherActionService(apiClient: mock)

        let config = try await service.loadConfig()

        XCTAssertEqual(config.columns, MockApiClient.sampleConfig.report.columns)
        XCTAssertEqual(service.reportConfig?.columns, MockApiClient.sampleConfig.report.columns)
    }

    func testResolveDefaultFilterReturnsParsedFilter() async {
        let mock = MockApiClient()
        mock.parseResult = .success(ParseResponse(
            action: "list",
            properties: nil,
            filter: .string("from-default"),
            tokens: []
        ))

        let service = LauncherActionService(apiClient: mock)
        service.setReportConfig(ReportConfig(
            filters: ["status:pending or status:active"],
            columns: ["id"],
            columnNames: ["ID"]
        ))

        let parsed = ParseResponse(action: "list", properties: nil, filter: nil, tokens: [])
        let filter = await service.resolveDefaultFilterIfNeeded(parsed: parsed, actionName: "list")

        XCTAssertEqual(mock.lastParseInput, "list status:pending or status:active")
        switch filter {
        case .string(let value):
            XCTAssertEqual(value, "from-default")
        default:
            XCTFail("Expected parsed default filter")
        }
    }

    func testRunActionSerializesRequests() async throws {
        let client = BlockingApiClient()
        let service = LauncherActionService(apiClient: client)
        let parsed = ParseResponse(action: "list", properties: nil, filter: nil, tokens: [])

        async let first = service.runAction(parsed: parsed, actionName: "list")
        async let second = service.runAction(parsed: parsed, actionName: "list")
        _ = try await (first, second)

        let maxConcurrent = await client.counter.maxConcurrent()
        XCTAssertEqual(maxConcurrent, 1)
    }
}

private actor ActionCounter {
    private var current = 0
    private var maxValue = 0

    func increment() {
        current += 1
        if current > maxValue {
            maxValue = current
        }
    }

    func decrement() {
        current -= 1
    }

    func maxConcurrent() -> Int {
        maxValue
    }
}

private final class BlockingApiClient: ApiClientProtocol, @unchecked Sendable {
    let counter = ActionCounter()

    func parse(input: String) async throws -> ParseResponse {
        ParseResponse(action: "", properties: nil, filter: nil, tokens: [])
    }

    func runAction(action: String, properties: JSONValue?, filter: JSONValue?) async throws -> ActionResponse {
        await counter.increment()
        defer { Task { await self.counter.decrement() } }
        try await Task.sleep(nanoseconds: 150_000_000)
        return ActionResponse(action: action, tasks: [], events: [])
    }

    func fetchConfig() async throws -> ConfigResponse {
        ConfigResponse(report: ReportConfig(filters: [], columns: [], columnNames: []), reports: [])
    }

    func fetchCompletions(type: String) async throws -> CompletionsResponse {
        CompletionsResponse(items: [])
    }

    func fetchTaskDetail(taskUUID: String) async throws -> ApiTaskDetail {
        ApiTaskDetail(
            dbId: nil,
            uuid: taskUUID,
            status: "pending",
            summary: "Detail",
            project: nil,
            tags: [],
            dateCreated: "2024-01-01T00:00:00Z",
            dateCompleted: nil,
            dateDue: nil,
            urgency: nil,
            annotations: [],
            history: []
        )
    }

    func fetchExternalLinks(taskUUID: String) async throws -> [ExternalLinkDto] {
        []
    }

    func syncExternalLink(linkId: Int, force: Bool) async throws -> ExternalLinkSyncResponse {
        ExternalLinkSyncResponse(attempted: 1, succeeded: 1, failed: 0, errors: [])
    }

    func fetchRecentGitlabMergeRequests(limit: Int) async throws -> [GitlabMergeRequestSuggestion] {
        []
    }

    func fetchRecentJiraIssues(limit: Int, scope: JiraIssueScope) async throws -> [JiraIssueSuggestion] {
        []
    }

    func resolveExternalLink(provider: ExternalLinkProvider, input: String) async throws -> ExternalLinkResolveResponse {
        ExternalLinkResolveResponse(url: "")
    }

    func addExternalLink(taskUUID: String, url: String) async throws -> ExternalLinkDto {
        ExternalLinkDto(
            id: 1,
            provider: "test",
            url: url,
            externalKey: "",
            cachedResponse: nil,
            lastSyncedAt: nil,
            syncError: nil
        )
    }

    func emptyParse() -> ParseResponse {
        ParseResponse(action: "", properties: nil, filter: nil, tokens: [])
    }
}
