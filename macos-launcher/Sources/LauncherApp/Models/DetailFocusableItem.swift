import Foundation

/// Represents a focusable item in the task detail view.
/// Used for keyboard navigation with j/k keys.
enum DetailFocusableItem: Equatable, Identifiable {
    case uuid(String)
    case gitlabMR(ExternalLinkDto)
    case jiraIssue(ExternalLinkDto)

    var id: String {
        switch self {
        case let .uuid(uuid):
            "uuid-\(uuid)"
        case let .gitlabMR(link):
            "gitlab-\(link.id)"
        case let .jiraIssue(link):
            "jira-\(link.id)"
        }
    }

    /// What action "o" (open) performs on this item.
    /// Returns nil for items that cannot be opened.
    var openURL: URL? {
        switch self {
        case .uuid:
            nil // UUID is not openable
        case let .gitlabMR(link):
            URL(string: link.url)
        case let .jiraIssue(link):
            URL(string: link.url)
        }
    }

    /// What "y" (copy) action should copy to clipboard.
    var copyValue: String {
        switch self {
        case let .uuid(uuid):
            return uuid
        case let .gitlabMR(link):
            // Prefer branch name if available, otherwise copy URL
            if let summary = link.cachedSummary(),
               case let .gitlab(gitlab) = summary,
               let branch = gitlab.sourceBranch {
                return branch
            }
            return link.url
        case let .jiraIssue(link):
            return link.url
        }
    }

    /// Label for the copy toast message.
    var copyLabel: String {
        switch self {
        case .uuid:
            return "UUID"
        case let .gitlabMR(link):
            if let summary = link.cachedSummary(),
               case let .gitlab(gitlab) = summary,
               gitlab.sourceBranch != nil {
                return "Branch"
            }
            return "Link"
        case .jiraIssue:
            return "Link"
        }
    }
}
