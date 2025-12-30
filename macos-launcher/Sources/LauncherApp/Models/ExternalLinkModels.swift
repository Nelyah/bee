import Foundation

struct GitlabMergeRequestSuggestion: Identifiable, Decodable {
    let id: Int64
    let title: String
    let webURL: String
    let projectPath: String
    let state: GitlabMergeRequestState
    let updatedAt: String
    let notesCount: Int?
    let approved: Bool?
    let pipelineStatus: GitlabPipelineStatus?

    enum CodingKeys: String, CodingKey {
        case id = "iid"
        case title
        case webURL = "web_url"
        case projectPath = "project_path"
        case state
        case updatedAt = "updated_at"
        case notesCount = "user_notes_count"
        case approved
        case pipelineStatus = "pipeline_status"
    }
}

enum GitlabMergeRequestState: Equatable, Decodable {
    case opened
    case merged
    case closed
    case unknown(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self).lowercased()
        switch value {
        case "opened", "open":
            self = .opened
        case "merged":
            self = .merged
        case "closed":
            self = .closed
        default:
            self = .unknown(value)
        }
    }

    var iconName: String {
        switch self {
        case .merged:
            return "pr-merged"
        case .closed:
            return "pr-closed"
        case .opened, .unknown:
            return "pr-open"
        }
    }
}

enum GitlabPipelineStatus: Equatable, Decodable {
    case success
    case running
    case pending
    case failed
    case canceled
    case skipped
    case unknown(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self).lowercased()
        switch value {
        case "success":
            self = .success
        case "running":
            self = .running
        case "pending":
            self = .pending
        case "failed":
            self = .failed
        case "canceled":
            self = .canceled
        case "skipped":
            self = .skipped
        default:
            self = .unknown(value)
        }
    }

    var iconName: String? {
        switch self {
        case .success:
            return "gitlab-success"
        case .running:
            return "gitlab-running"
        case .pending, .failed, .canceled, .skipped:
            return "gitlab-pending"
        case .unknown:
            return nil
        }
    }

    var label: String {
        switch self {
        case .success:
            return "Passed"
        case .failed:
            return "Failed"
        case .running:
            return "Running"
        case .pending:
            return "Pending"
        case .canceled:
            return "Canceled"
        case .skipped:
            return "Skipped"
        case .unknown(let value):
            return value.capitalized
        }
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
