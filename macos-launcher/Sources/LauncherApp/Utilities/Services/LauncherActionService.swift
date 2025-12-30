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

    func resolveDefaultFilterIfNeeded(parsed: ParseResponse, actionName: String) async -> JSONValue? {
        guard actionName.lowercased() == "list" else { return parsed.filter }
        guard parsed.filter == nil else { return parsed.filter }
        guard let defaults = reportConfig?.filters, !defaults.isEmpty else { return parsed.filter }

        let filterExpr = defaults.joined(separator: " or ")
        do {
            let parsedDefaults = try await apiClient.parse(input: "list \(filterExpr)")
            return parsedDefaults.filter
        } catch {
            logger.error("Failed to parse default filters: \(error.localizedDescription, privacy: .public)")
            return parsed.filter
        }
    }

    func runAction(parsed: ParseResponse, actionName: String) async throws -> ActionResponse {
        try await actionQueue.run {
            let filter = await self.resolveDefaultFilterIfNeeded(parsed: parsed, actionName: actionName)
            return try await self.apiClient.runAction(
                action: actionName,
                properties: parsed.properties,
                filter: filter
            )
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
