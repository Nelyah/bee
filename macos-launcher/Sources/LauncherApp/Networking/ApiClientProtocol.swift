import Foundation

/// Protocol for API client dependency injection.
protocol ApiClientProtocol: Sendable {
    func parse(input: String) async throws -> ParseResponse
    func runAction(action: String, properties: JSONValue?, filter: JSONValue?) async throws -> ActionResponse
    func fetchConfig() async throws -> ConfigResponse
    func fetchCompletions(type: String) async throws -> CompletionsResponse
    func emptyParse() -> ParseResponse
}
