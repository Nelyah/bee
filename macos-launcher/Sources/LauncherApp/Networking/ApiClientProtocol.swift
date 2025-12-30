import Foundation

/// Protocol for API client dependency injection.
protocol ApiClientProtocol: Sendable {
    func parse(input: String) async throws -> ParseResponse
    func runAction(action: String, properties: JSONValue?, filter: JSONValue?) async throws -> ActionResponse
    func fetchConfig() async throws -> ConfigResponse
    func fetchCompletions(type: String) async throws -> CompletionsResponse
    func fetchRecentGitlabMergeRequests(limit: Int) async throws -> [GitlabMergeRequestSuggestion]
    func fetchRecentJiraIssues(limit: Int, scope: JiraIssueScope) async throws -> [JiraIssueSuggestion]
    func resolveExternalLink(provider: ExternalLinkProvider, input: String) async throws -> ExternalLinkResolveResponse
    func addExternalLink(taskUUID: String, url: String) async throws -> ExternalLinkDto
    func emptyParse() -> ParseResponse
}
