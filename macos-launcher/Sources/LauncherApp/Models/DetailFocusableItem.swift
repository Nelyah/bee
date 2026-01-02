import Foundation

/// Represents a focusable item in the task detail view.
/// Used for keyboard navigation with j/k keys.
enum DetailFocusableItem: Equatable, Identifiable {
    /// Task name at the top of the detail view.
    /// Associated value is the task summary for copying.
    case taskName(String)
    case uuid(String)
    case gitlabMR(ExternalLinkDto)
    case jiraIssue(ExternalLinkDto)

    var id: String {
        switch self {
        case .taskName:
            "taskName"
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
    /// Note: Task name returns nil here, but Enter key triggers editing instead.
    var openURL: URL? {
        switch self {
        case .taskName:
            nil // Task name uses Enter to edit, not open URL
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
        case let .taskName(summary):
            return summary
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
        case .taskName:
            return "Task name"
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
