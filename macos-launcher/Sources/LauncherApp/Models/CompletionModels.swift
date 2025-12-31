import Foundation

/// A single completion suggestion from the API.
struct CompletionItem: Identifiable, Decodable, Equatable {
    let value: String
    let count: Int?

    var id: String { value }
}

/// Response from the /v1/completions endpoint.
struct CompletionsResponse: Decodable {
    let items: [CompletionItem]
}

/// Context for determining what type of completions to show.
enum CompletionContext: Equatable {
    case action // First word - complete action names
    case tag // After + or -
    case project // After project: or proj:
    case status // After status:
    case date // After due:, due.before:, etc.
    case taskRef // After depends:
    case none // No completion context

    /// The API type parameter for fetching completions.
    var apiType: String? {
        switch self {
        case .action: "actions"
        case .tag: "tags"
        case .project: "projects"
        case .status: "status"
        case .date: "dates"
        case .taskRef, .none: nil
        }
    }
}
