import Foundation

struct GitlabMergeRequestSuggestion: Identifiable, Decodable {
    let id: Int64
    let title: String
    let webURL: String
    let projectPath: String
    let state: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id = "iid"
        case title
        case webURL = "web_url"
        case projectPath = "project_path"
        case state
        case updatedAt = "updated_at"
    }
}

struct JiraIssueSuggestion: Identifiable, Decodable {
    var id: String { key }
    let key: String
    let summary: String
    let status: String
    let webURL: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case key
        case summary
        case status
        case webURL = "web_url"
        case updatedAt = "updated_at"
    }
}

struct ExternalLinkResolveRequest: Encodable {
    let provider: String
    let input: String
}

struct ExternalLinkResolveResponse: Decodable {
    let url: String
}

struct ExternalLinkCreateRequest: Encodable {
    let url: String
}

struct ExternalLinkDto: Decodable {
    let id: Int
    let provider: String
    let url: String
    let externalKey: String
    let cachedResponse: String?
    let lastSyncedAt: String?
    let syncError: String?

    enum CodingKeys: String, CodingKey {
        case id
        case provider
        case url
        case externalKey = "external_key"
        case cachedResponse = "cached_response"
        case lastSyncedAt = "last_synced_at"
        case syncError = "sync_error"
    }
}

enum JiraIssueScope: String, Codable {
    case assigned
    case created
    case both
}

enum ExternalLinkProvider: String, Codable {
    case gitlab
    case jira
}
