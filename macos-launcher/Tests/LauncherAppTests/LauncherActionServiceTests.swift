@testable import LauncherApp
import XCTest

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
            staticFilters: ["status:pending or status:active"],
            columns: ["id"],
            columnNames: ["ID"]
        ))

        let parsed = ParseResponse(action: "list", properties: nil, filter: nil, tokens: [])
        let filter = await service.resolveDefaultFilterIfNeeded(parsed: parsed, actionName: "list")

        XCTAssertEqual(mock.lastParseInput, "list status:pending or status:active")
        switch filter {
        case let .string(value):
            XCTAssertEqual(value, "from-default")
        default:
            XCTFail("Expected parsed default filter")
        }
    }

    func testResolveDefaultFilterCombinesWithUserFilter() async {
        let mock = MockApiClient()
        mock.parseResult = .success(ParseResponse(
            action: "list",
            properties: nil,
            filter: .string("from-default"),
            tokens: []
        ))

        let service = LauncherActionService(apiClient: mock)
        service.setReportConfig(ReportConfig(
            staticFilters: ["status:pending or status:active"],
            columns: ["id"],
            columnNames: ["ID"]
        ))

        let parsed = ParseResponse(action: "list", properties: nil, filter: .string("from-user"), tokens: [])
        let filter = await service.resolveDefaultFilterIfNeeded(parsed: parsed, actionName: "list")

        guard case let .object(obj)? = filter,
              case let .string(type)? = obj["type"], type == "AndFilter",
              case let .object(valueObj)? = obj["value"],
              case let .array(children)? = valueObj["children"]
        else {
            return XCTFail("Expected AndFilter wrapper")
        }

        XCTAssertEqual(children.count, 2)
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

    // MARK: - Project Scope Filter Tests

    /// Regression test: ProjectFilter.name must be a Project struct (not a plain string).
    /// Backend structs:
    ///   - `pub struct ProjectFilter { pub name: Project }` in filters_impl.rs
    ///   - `pub struct Project { id: Option<i32>, name: String }` in task_model.rs
    func testProjectFilterNameIsProjectStructNotString() async {
        let mock = MockApiClient()
        let service = LauncherActionService(apiClient: mock)

        let parsed = ParseResponse(action: "list", properties: nil, filter: nil, tokens: [])
        let filter = await service.resolveDefaultFilterIfNeeded(
            parsed: parsed,
            actionName: "list",
            projectScope: "testproject"
        )

        guard case let .object(obj)? = filter,
              case let .object(valueObj)? = obj["value"],
              case let .object(projectStruct)? = valueObj["name"]
        else {
            return XCTFail("Expected ProjectFilter.name to be a Project struct object, not a string")
        }

        // Project struct must have "name" field with the project name string
        guard case let .string(projectName)? = projectStruct["name"] else {
            return XCTFail("Project struct must have 'name' field")
        }
        XCTAssertEqual(projectName, "testproject")

        // Project struct should have "id" field (null for scope filter)
        if let idValue = projectStruct["id"] {
            guard case .null = idValue else {
                return XCTFail("Project.id should be null for scope filter, got: \(idValue)")
            }
        }
        // id can be absent or null - both are valid
    }

    func testResolveFilterWithProjectScopeOnly() async {
        let mock = MockApiClient()
        let service = LauncherActionService(apiClient: mock)

        let parsed = ParseResponse(action: "list", properties: nil, filter: nil, tokens: [])
        let filter = await service.resolveDefaultFilterIfNeeded(
            parsed: parsed,
            actionName: "list",
            projectScope: "myproject"
        )

        guard case let .object(obj)? = filter,
              case let .string(type)? = obj["type"], type == "ProjectFilter",
              case let .object(valueObj)? = obj["value"],
              case let .object(projectStruct)? = valueObj["name"],
              case let .string(projectName)? = projectStruct["name"]
        else {
            return XCTFail("Expected ProjectFilter wrapper with Project struct")
        }

        XCTAssertEqual(projectName, "myproject")
    }

    func testResolveFilterWithScopeAndUserInput() async {
        let mock = MockApiClient()
        let service = LauncherActionService(apiClient: mock)

        let parsed = ParseResponse(action: "list", properties: nil, filter: .string("user-filter"), tokens: [])
        let filter = await service.resolveDefaultFilterIfNeeded(
            parsed: parsed,
            actionName: "list",
            projectScope: "myproject"
        )

        guard case let .object(obj)? = filter,
              case let .string(type)? = obj["type"], type == "AndFilter",
              case let .object(valueObj)? = obj["value"],
              case let .array(children)? = valueObj["children"]
        else {
            return XCTFail("Expected AndFilter wrapper")
        }

        XCTAssertEqual(children.count, 2)

        // First child should be ProjectFilter
        guard case let .object(scopeObj) = children[0],
              case let .string(scopeType)? = scopeObj["type"]
        else {
            return XCTFail("Expected first child to be ProjectFilter")
        }
        XCTAssertEqual(scopeType, "ProjectFilter")
    }

    func testResolveFilterThreeWay() async {
        let mock = MockApiClient()
        mock.parseResult = .success(ParseResponse(
            action: "list",
            properties: nil,
            filter: .string("from-default"),
            tokens: []
        ))

        let service = LauncherActionService(apiClient: mock)
        service.setReportConfig(ReportConfig(
            staticFilters: ["status:pending"],
            columns: ["id"],
            columnNames: ["ID"]
        ))

        let parsed = ParseResponse(action: "list", properties: nil, filter: .string("from-user"), tokens: [])
        let filter = await service.resolveDefaultFilterIfNeeded(
            parsed: parsed,
            actionName: "list",
            projectScope: "myproject"
        )

        // Should be nested AndFilter: ((defaults AND scope) AND user)
        guard case let .object(outerObj)? = filter,
              case let .string(outerType)? = outerObj["type"], outerType == "AndFilter",
              case let .object(outerValue)? = outerObj["value"],
              case let .array(outerChildren)? = outerValue["children"]
        else {
            return XCTFail("Expected outer AndFilter wrapper")
        }

        XCTAssertEqual(outerChildren.count, 2)

        // First child should be the inner AndFilter (defaults AND scope)
        guard case let .object(innerObj) = outerChildren[0],
              case let .string(innerType)? = innerObj["type"], innerType == "AndFilter",
              case let .object(innerValue)? = innerObj["value"],
              case let .array(innerChildren)? = innerValue["children"]
        else {
            return XCTFail("Expected inner AndFilter")
        }

        XCTAssertEqual(innerChildren.count, 2)
    }

    func testResolveFilterWithNoScopePassesThrough() async {
        let mock = MockApiClient()
        let service = LauncherActionService(apiClient: mock)

        let parsed = ParseResponse(action: "list", properties: nil, filter: .string("user-filter"), tokens: [])
        let filter = await service.resolveDefaultFilterIfNeeded(
            parsed: parsed,
            actionName: "list",
            projectScope: nil
        )

        guard case let .string(value)? = filter else {
            return XCTFail("Expected user filter to pass through")
        }

        XCTAssertEqual(value, "user-filter")
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
        do {
            try await Task.sleep(nanoseconds: 150_000_000)
            await counter.decrement()
            return ActionResponse(action: action, tasks: [], events: [])
        } catch {
            await counter.decrement()
            throw error
        }
    }

    func fetchConfig() async throws -> ConfigResponse {
        ConfigResponse(report: ReportConfig(staticFilters: [], columns: [], columnNames: []), reports: [])
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
            history: [],
            links: [],
            attachments: []
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

    func resolveExternalLink(
        provider: ExternalLinkProvider,
        input: String
    ) async throws -> ExternalLinkResolveResponse {
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

    func uploadAttachment(taskUUID: String, fileURL: URL) async throws -> TaskAttachmentDto {
        TaskAttachmentDto(
            id: 1,
            uuid: "test-attachment",
            filename: fileURL.lastPathComponent,
            mimeType: "application/octet-stream",
            sizeBytes: 0,
            createdAt: "2024-01-01T00:00:00Z"
        )
    }

    func downloadAttachment(attachmentId: Int) async throws -> Data {
        Data()
    }

    func deleteAttachment(attachmentId: Int) async throws {}

    func emptyParse() -> ParseResponse {
        ParseResponse(action: "", properties: nil, filter: nil, tokens: [])
    }

    func createUserReport(_ request: UserReportRequest) async throws -> UserReportDto {
        UserReportDto(
            name: request.name,
            filter: request.filter,
            columns: request.columns,
            columnNames: request.columnNames,
            columnWidths: request.columnWidths,
            sortColumn: request.sortColumn,
            sortDirection: request.sortDirection,
            createdAt: "2024-01-01T00:00:00Z",
            updatedAt: "2024-01-01T00:00:00Z"
        )
    }

    func updateUserReport(name: String, _ request: UserReportRequest) async throws -> UserReportDto {
        UserReportDto(
            name: name,
            filter: request.filter,
            columns: request.columns,
            columnNames: request.columnNames,
            columnWidths: request.columnWidths,
            sortColumn: request.sortColumn,
            sortDirection: request.sortDirection,
            createdAt: "2024-01-01T00:00:00Z",
            updatedAt: "2024-01-01T00:00:00Z"
        )
    }

    func deleteUserReport(name: String) async throws {
        // No-op for test
    }

    func fetchProjects() async throws -> ProjectsResponse {
        ProjectsResponse(projects: [])
    }

    func fetchProjectBurndown(project: String, days: Int) async throws -> ProjectBurndownResponse {
        ProjectBurndownResponse(
            project: project,
            dataPoints: [],
            totalTasks: 0,
            totalCompleted: 0
        )
    }
}
