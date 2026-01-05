import Foundation

/// Protocol for API client dependency injection.
protocol ApiClientProtocol: Sendable {
    func parse(input: String) async throws -> ParseResponse
    func runAction(action: String, properties: JSONValue?, filter: JSONValue?) async throws -> ActionResponse
    func fetchConfig() async throws -> ConfigResponse
    func fetchCompletions(type: String) async throws -> CompletionsResponse
    func fetchTaskDetail(taskUUID: String) async throws -> ApiTaskDetail
    func fetchExternalLinks(taskUUID: String) async throws -> [ExternalLinkDto]
    func syncExternalLink(linkId: Int, force: Bool) async throws -> ExternalLinkSyncResponse
    func fetchRecentGitlabMergeRequests(limit: Int) async throws -> [GitlabMergeRequestSuggestion]
    func fetchRecentJiraIssues(limit: Int, scope: JiraIssueScope) async throws -> [JiraIssueSuggestion]
    func resolveExternalLink(provider: ExternalLinkProvider, input: String) async throws -> ExternalLinkResolveResponse
    func addExternalLink(taskUUID: String, url: String) async throws -> ExternalLinkDto
    func emptyParse() -> ParseResponse

    // User Reports
    func createUserReport(_ request: UserReportRequest) async throws -> UserReportDto
    func updateUserReport(name: String, _ request: UserReportRequest) async throws -> UserReportDto
    func deleteUserReport(name: String) async throws

    // Attachments
    func uploadAttachment(taskUUID: String, fileURL: URL) async throws -> TaskAttachmentDto
    func downloadAttachment(attachmentId: Int) async throws -> Data
    func deleteAttachment(attachmentId: Int) async throws

    // Project Overview
    func fetchProjects() async throws -> ProjectsResponse
    func fetchProjectBurndown(project: String, days: Int) async throws -> ProjectBurndownResponse
}
