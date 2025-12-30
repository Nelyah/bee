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

    static func fromRaw(_ value: String) -> GitlabMergeRequestState {
        switch value.lowercased() {
        case "opened", "open":
            return .opened
        case "merged":
            return .merged
        case "closed":
            return .closed
        default:
            return .unknown(value)
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

    static func fromRaw(_ value: String) -> GitlabPipelineStatus {
        switch value.lowercased() {
        case "success":
            return .success
        case "running":
            return .running
        case "pending":
            return .pending
        case "failed":
            return .failed
        case "canceled":
            return .canceled
        case "skipped":
            return .skipped
        default:
            return .unknown(value)
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

struct ExternalLinkSyncResponse: Decodable {
    let attempted: Int
    let succeeded: Int
    let failed: Int
    let errors: [String]
}

enum ExternalLinkSyncState: Equatable {
    case pending
    case synced(Date)
    case stale(Date)
    case error(String)
}

struct GitlabCachedSummary: Equatable {
    let iid: Int?
    let title: String
    let state: String?
    let comments: Int?
    let pipelineStatus: String?
    let approved: Bool?
    let sourceBranch: String?
}

struct JiraCachedSummary: Equatable {
    let summary: String
    let status: String?
}

enum ExternalLinkCachedSummary: Equatable {
    case gitlab(GitlabCachedSummary)
    case jira(JiraCachedSummary)
}

extension ExternalLinkDto {
    func syncState(
        now: Date = Date(),
        staleAfter: TimeInterval = 24 * 60 * 60
    ) -> ExternalLinkSyncState {
        if let syncError {
            return .error(syncError)
        }
        guard let lastSyncedAt else {
            return .pending
        }
        guard let date = RelativeDateFormatter.date(from: lastSyncedAt) else {
            return .pending
        }
        if now.timeIntervalSince(date) > staleAfter {
            return .stale(date)
        }
        return .synced(date)
    }

    func cachedSummary() -> ExternalLinkCachedSummary? {
        guard let cachedResponse, !cachedResponse.isEmpty else { return nil }
        switch provider.lowercased() {
        case ExternalLinkProvider.gitlab.rawValue:
            guard let summary = ExternalLinkCachedParser.gitlabSummary(from: cachedResponse) else {
                return nil
            }
            return .gitlab(summary)
        case ExternalLinkProvider.jira.rawValue:
            guard let summary = ExternalLinkCachedParser.jiraSummary(from: cachedResponse) else {
                return nil
            }
            return .jira(summary)
        default:
            return nil
        }
    }
}

private enum ExternalLinkCachedParser {
    static func gitlabSummary(from cached: String) -> GitlabCachedSummary? {
        guard let json = parseJSON(cached) else { return nil }
        if let mergeRequest = json["merge_request"] as? [String: Any] {
            return parseGitlabItem(mergeRequest, approvals: json["approvals"] as? [String: Any])
        }
        return parseGitlabItem(json, approvals: nil)
    }

    static func jiraSummary(from cached: String) -> JiraCachedSummary? {
        guard let json = parseJSON(cached) else { return nil }
        guard let fields = json["fields"] as? [String: Any] else { return nil }
        let summary = fields["summary"] as? String
        let status = (fields["status"] as? [String: Any])?["name"] as? String
        if let summary {
            return JiraCachedSummary(summary: summary, status: status)
        }
        return nil
    }

    private static func parseGitlabItem(
        _ json: [String: Any],
        approvals: [String: Any]?
    ) -> GitlabCachedSummary? {
        let title = json["title"] as? String
        let iid = json["iid"] as? Int
        let state = json["state"] as? String
        let comments = json["user_notes_count"] as? Int
        let sourceBranch = json["source_branch"] as? String
        let pipelineStatus =
            (json["head_pipeline"] as? [String: Any])?["status"] as? String
            ?? (json["pipeline"] as? [String: Any])?["status"] as? String
        let approved = approvals?["approved"] as? Bool
            ?? {
                guard let approvedBy = approvals?["approved_by"] as? [[String: Any]] else { return nil }
                return !approvedBy.isEmpty
            }()
        if let title {
            return GitlabCachedSummary(
                iid: iid,
                title: title,
                state: state,
                comments: comments,
                pipelineStatus: pipelineStatus,
                approved: approved,
                sourceBranch: sourceBranch
            )
        }
        return nil
    }

    private static func parseJSON(_ value: String) -> [String: Any]? {
        guard let data = value.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
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
