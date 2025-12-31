import Foundation
import OSLog

@MainActor
final class LauncherActionService {
    private let apiClient: ApiClientProtocol
    private let logger: Logger
    private(set) var reportConfig: ReportConfig?
    private let actionQueue = SerialTaskQueue()

    init(
        apiClient: ApiClientProtocol,
        logger: Logger = Logger(subsystem: "bee.macos-launcher", category: "action-service")
    ) {
        self.apiClient = apiClient
        self.logger = logger
    }

    func setReportConfig(_ reportConfig: ReportConfig?) {
        self.reportConfig = reportConfig
    }

    func loadConfig() async throws -> ReportConfig {
        let config = try await apiClient.fetchConfig()
        reportConfig = config.report
        return config.report
    }

    func loadFullConfig() async throws -> ConfigResponse {
        let config = try await apiClient.fetchConfig()
        reportConfig = config.report
        return config
    }

    func parse(input: String) async throws -> ParseResponse {
        try await apiClient.parse(input: input)
    }

    func emptyParse() -> ParseResponse {
        apiClient.emptyParse()
    }

    func resolveDefaultFilterIfNeeded(
        parsed: ParseResponse,
        actionName: String,
        projectScope: String? = nil
    ) async -> JSONValue? {
        guard actionName.lowercased() == "list" else { return parsed.filter }

        // Build project scope filter if set
        // Backend expects: ProjectFilter { name: Project { id: Option<i32>, name: String } }
        let scopeFilter: JSONValue? = projectScope.map { project in
            .object([
                "type": .string("ProjectFilter"),
                "value": .object([
                    "name": .object([
                        "id": .null,
                        "name": .string(project),
                    ]),
                ]),
            ])
        }

        // User reports have pre-parsed filter JSON - use it directly
        if let filterJson = reportConfig?.userFilter {
            // Three-way composition: (report filter AND scope) AND user filter
            let defaultsAndScope = combineFilters(defaults: filterJson, user: scopeFilter)
            return combineFilters(defaults: defaultsAndScope, user: parsed.filter)
        }

        // Static reports have filter expression strings - need to parse them
        guard let defaults = reportConfig?.staticFilters, !defaults.isEmpty else {
            // No report defaults - just combine scope and user filter
            return combineFilters(defaults: scopeFilter, user: parsed.filter)
        }

        let filterExpr = defaults.joined(separator: " or ")
        do {
            let parsedDefaults = try await apiClient.parse(input: "list \(filterExpr)")
            // Three-way composition: (defaults AND scope) AND user
            let defaultsAndScope = combineFilters(defaults: parsedDefaults.filter, user: scopeFilter)
            return combineFilters(defaults: defaultsAndScope, user: parsed.filter)
        } catch {
            logger.error("Failed to parse default filters: \(error.localizedDescription, privacy: .public)")
            return combineFilters(defaults: scopeFilter, user: parsed.filter)
        }
    }

    func runAction(
        parsed: ParseResponse,
        actionName: String,
        projectScope: String? = nil
    ) async throws -> ActionResponse {
        try await actionQueue.run {
            let filter = await self.resolveDefaultFilterIfNeeded(
                parsed: parsed,
                actionName: actionName,
                projectScope: projectScope
            )
            return try await self.apiClient.runAction(
                action: actionName,
                properties: parsed.properties,
                filter: filter
            )
        }
    }

    private func combineFilters(defaults: JSONValue?, user: JSONValue?) -> JSONValue? {
        switch (defaults, user) {
        case (nil, nil):
            nil
        case (let defaults?, nil):
            defaults
        case (nil, let user?):
            user
        case let (defaults?, user?):
            .object([
                "type": .string("AndFilter"),
                "value": .object([
                    "children": .array([defaults, user]),
                ]),
            ])
        }
    }

    func fetchCompletions() async throws -> CompletionCache {
        async let projectsTask = apiClient.fetchCompletions(type: "projects")
        async let tagsTask = apiClient.fetchCompletions(type: "tags")
        async let actionsTask = apiClient.fetchCompletions(type: "actions")
        async let statusTask = apiClient.fetchCompletions(type: "status")
        async let datesTask = apiClient.fetchCompletions(type: "dates")

        let (projects, tags, actions, status, dates) = try await (
            projectsTask, tagsTask, actionsTask, statusTask, datesTask
        )

        return CompletionCache(
            projects: projects.items,
            tags: tags.items,
            actions: actions.items,
            status: status.items,
            dates: dates.items
        )
    }
}
