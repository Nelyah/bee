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

    func emptyParse() -> ParseResponse {
        ParseResponse(action: "list", properties: nil, filter: nil, tokens: [])
    }

    // MARK: - Sample Data

    static let sampleConfig = ConfigResponse(
        report: ReportConfig(
            filters: ["status:pending or status:active"],
            columns: ["id", "summary", "tags", "status", "urgency"],
            columnNames: ["ID", "Summary", "Tags", "Status", "Urgency"]
        )
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
        )
    ]
}
