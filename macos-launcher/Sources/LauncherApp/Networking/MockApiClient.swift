import Foundation

/// Mock API client for SwiftUI previews and tests.
final class MockApiClient: ApiClientProtocol, @unchecked Sendable {
    var parseResult: Result<ParseResponse, Error> = .success(ParseResponse(
        action: "list",
        properties: nil,
        filter: nil,
        tokens: []
    ))

    var actionResult: Result<ActionResponse, Error> = .success(ActionResponse(
        action: "list",
        tasks: MockApiClient.sampleTasks,
        events: []
    ))

    var configResult: Result<ConfigResponse, Error> = .success(MockApiClient.sampleConfig)
    var completionsResult: Result<CompletionsResponse, Error> = .success(MockApiClient.sampleCompletions)
    var taskDetailResult: Result<ApiTaskDetail, Error> = .success(MockApiClient.sampleTaskDetail)
    var externalLinksResult: Result<[ExternalLinkDto], Error> = .success(MockApiClient.sampleExternalLinks)
    var syncExternalLinkResult: Result<ExternalLinkSyncResponse, Error> = .success(
        ExternalLinkSyncResponse(attempted: 1, succeeded: 1, failed: 0, errors: [])
    )
    var gitlabMergeRequestsResult: Result<[GitlabMergeRequestSuggestion], Error> = .success(MockApiClient
        .sampleMergeRequests)
    var jiraIssuesResult: Result<[JiraIssueSuggestion], Error> = .success(MockApiClient.sampleJiraIssues)
    var resolveResult: Result<ExternalLinkResolveResponse, Error> = .success(
        ExternalLinkResolveResponse(url: "https://gitlab.example.com/group/project/-/merge_requests/42")
    )
    var addExternalLinkResult: Result<ExternalLinkDto, Error> = .success(
        ExternalLinkDto(
            id: 1,
            provider: "gitlab",
            url: "https://gitlab.example.com/group/project/-/merge_requests/42",
            externalKey: "mr:group/project:42",
            cachedResponse: nil,
            lastSyncedAt: nil,
            syncError: nil
        )
    )
    var createUserReportResult: Result<UserReportDto, Error> = .success(MockApiClient.sampleUserReport)
    var updateUserReportResult: Result<UserReportDto, Error> = .success(MockApiClient.sampleUserReport)
    var deleteUserReportResult: Result<Void, Error> = .success(())
    var lastParseInput: String?
    var lastRunActionFilter: JSONValue?

    func parse(input: String) async throws -> ParseResponse {
        lastParseInput = input
        return try parseResult.get()
    }

    func runAction(action: String, properties: JSONValue?, filter: JSONValue?) async throws -> ActionResponse {
        lastRunActionFilter = filter
        return try actionResult.get()
    }

    func fetchConfig() async throws -> ConfigResponse {
        try configResult.get()
    }

    func fetchCompletions(type: String) async throws -> CompletionsResponse {
        try completionsResult.get()
    }

    func fetchTaskDetail(taskUUID: String) async throws -> ApiTaskDetail {
        try taskDetailResult.get()
    }

    func fetchExternalLinks(taskUUID: String) async throws -> [ExternalLinkDto] {
        try externalLinksResult.get()
    }

    func syncExternalLink(linkId: Int, force: Bool) async throws -> ExternalLinkSyncResponse {
        try syncExternalLinkResult.get()
    }

    func fetchRecentGitlabMergeRequests(limit: Int) async throws -> [GitlabMergeRequestSuggestion] {
        try gitlabMergeRequestsResult.get()
    }

    func fetchRecentJiraIssues(limit: Int, scope: JiraIssueScope) async throws -> [JiraIssueSuggestion] {
        try jiraIssuesResult.get()
    }

    func resolveExternalLink(
        provider: ExternalLinkProvider,
        input: String
    ) async throws -> ExternalLinkResolveResponse {
        try resolveResult.get()
    }

    func addExternalLink(taskUUID: String, url: String) async throws -> ExternalLinkDto {
        try addExternalLinkResult.get()
    }

    func emptyParse() -> ParseResponse {
        ParseResponse(action: "list", properties: nil, filter: nil, tokens: [])
    }

    // MARK: - User Reports

    func createUserReport(_ request: UserReportRequest) async throws -> UserReportDto {
        try createUserReportResult.get()
    }

    func updateUserReport(name: String, _ request: UserReportRequest) async throws -> UserReportDto {
        try updateUserReportResult.get()
    }

    func deleteUserReport(name: String) async throws {
        _ = try deleteUserReportResult.get()
    }

    // MARK: - Sample Data

    static let sampleConfig = ConfigResponse(
        report: ReportConfig(
            staticFilters: ["status:pending or status:active"],
            columns: ["id", "summary", "tags", "status", "urgency"],
            columnNames: ["ID", "Summary", "Tags", "Status", "Urgency"]
        ),
        reports: [
            ReportSummary(
                name: "default",
                staticFilters: ["status:pending or status:active"],
                columns: ["id", "summary", "tags", "status", "urgency"],
                columnNames: ["ID", "Summary", "Tags", "Status", "Urgency"],
                isDefault: true
            ),
            ReportSummary(
                name: "all",
                staticFilters: [],
                columns: ["id", "summary", "status"],
                columnNames: ["ID", "Summary", "Status"],
                isDefault: false
            ),
        ]
    )

    static let sampleCompletions = CompletionsResponse(items: [
        CompletionItem(value: "bee", count: 10),
        CompletionItem(value: "infra", count: 5),
        CompletionItem(value: "work", count: 3),
    ])

    static let sampleTasks: [ApiTask] = [
        ApiTask(
            dbId: 1,
            uuid: "a1b2c3d4",
            status: "active",
            summary: "Review pull request",
            project: "bee",
            tags: ["code", "review"],
            dateCreated: "2024-01-15T10:00:00Z",
            dateCompleted: nil,
            dateDue: "2024-01-20T17:00:00Z",
            urgency: 8
        ),
        ApiTask(
            dbId: 2,
            uuid: "e5f6g7h8",
            status: "active",
            summary: "Write documentation",
            project: "bee",
            tags: ["docs"],
            dateCreated: "2024-01-14T09:00:00Z",
            dateCompleted: nil,
            dateDue: nil,
            urgency: 5
        ),
        ApiTask(
            dbId: 3,
            uuid: "i9j0k1l2",
            status: "completed",
            summary: "Set up CI pipeline",
            project: "infra",
            tags: ["devops"],
            dateCreated: "2024-01-10T08:00:00Z",
            dateCompleted: "2024-01-12T16:00:00Z",
            dateDue: nil,
            urgency: nil
        ),
    ]

    static let sampleTaskDetail = ApiTaskDetail(
        dbId: 1,
        uuid: "a1b2c3d4",
        status: "active",
        summary: "Review pull request",
        project: "bee",
        tags: ["code", "review"],
        dateCreated: "2024-01-15T10:00:00Z",
        dateCompleted: nil,
        dateDue: "2024-01-20T17:00:00Z",
        urgency: 8,
        annotations: [
            TaskAnnotationDto(value: "Follow up with QA", time: "2024-01-18T09:00:00Z"),
        ],
        history: [
            TaskHistoryDto(value: "Status changed from 'PENDING' to 'ACTIVE'", datetime: "2024-01-16T12:30:00Z"),
            TaskHistoryDto(value: "Added a UUID to depend on: 'deadbeef'", datetime: "2024-01-15T11:00:00Z"),
        ],
        links: [
            TaskLinkDto(linkType: "depends_on", targetUuid: "deadbeef"),
        ]
    )

    static let sampleExternalLinks: [ExternalLinkDto] = [
        ExternalLinkDto(
            id: 1,
            provider: "gitlab",
            url: "https://gitlab.example.com/group/project/-/merge_requests/42",
            externalKey: "mr:group/project:42",
            cachedResponse: """
            {"merge_request":{"title":"Improve task sync","state":"opened",\
            "user_notes_count":12,"head_pipeline":{"status":"running"}},\
            "approvals":{"approved":false}}
            """,
            lastSyncedAt: "2024-09-24T12:00:00Z",
            syncError: nil
        ),
        ExternalLinkDto(
            id: 2,
            provider: "jira",
            url: "https://jira.example.com/browse/BEE-101",
            externalKey: "BEE-101",
            cachedResponse: """
            {"fields":{"summary":"Add command palette","status":{"name":"In Progress"}}}
            """,
            lastSyncedAt: "2024-09-22T09:30:00Z",
            syncError: nil
        ),
    ]

    static let sampleMergeRequests: [GitlabMergeRequestSuggestion] = [
        GitlabMergeRequestSuggestion(
            id: 42,
            title: "Improve task sync",
            webURL: "https://gitlab.example.com/group/project/-/merge_requests/42",
            projectPath: "group/project",
            state: .opened,
            updatedAt: "2024-09-24T12:00:00Z",
            notesCount: 12,
            approved: false,
            pipelineStatus: .running
        ),
        GitlabMergeRequestSuggestion(
            id: 41,
            title: "Fix launcher bug",
            webURL: "https://gitlab.example.com/group/project/-/merge_requests/41",
            projectPath: "group/project",
            state: .merged,
            updatedAt: "2024-09-23T18:15:00Z",
            notesCount: 4,
            approved: true,
            pipelineStatus: .success
        ),
    ]

    static let sampleJiraIssues: [JiraIssueSuggestion] = [
        JiraIssueSuggestion(
            key: "BEE-101",
            summary: "Add command palette",
            status: "In Progress",
            webURL: "https://jira.example.com/browse/BEE-101",
            updatedAt: "2024-09-22T09:30:00Z"
        ),
        JiraIssueSuggestion(
            key: "BEE-102",
            summary: "Polish UI",
            status: "To Do",
            webURL: "https://jira.example.com/browse/BEE-102",
            updatedAt: "2024-09-21T14:05:00Z"
        ),
    ]

    static let sampleUserReport = UserReportDto(
        name: "my-report",
        filter: .object([
            "type": .string("StatusFilter"),
            "value": .object(["status": .string("pending")]),
        ]),
        columns: ["id", "summary", "status"],
        columnNames: ["ID", "Summary", "Status"],
        columnWidths: .object(["id": .number(60), "summary": .number(300)]),
        sortColumn: "status",
        sortDirection: "ascending",
        createdAt: "2024-12-31T10:00:00Z",
        updatedAt: "2024-12-31T10:00:00Z"
    )
}
