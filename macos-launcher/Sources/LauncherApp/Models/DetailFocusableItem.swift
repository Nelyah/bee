import Foundation

/// Represents a focusable item in the task detail view.
/// Used for keyboard navigation with j/k keys.
enum DetailFocusableItem: Equatable, Identifiable {
    /// Task name at the top of the detail view.
    /// Associated value is the task summary for copying.
    case taskName(String)
    /// Project field in the metadata section.
    /// Associated value is the project name (or empty string if none).
    case project(String)
    case uuid(String)
    case gitlabMR(ExternalLinkDto)
    case jiraIssue(ExternalLinkDto)
    /// A tag in the tags row.
    /// Associated values are the tag name and its index in the tags array.
    case tag(String, index: Int)
    /// The "+" button to add a new tag.
    case addTagButton
    /// Due date field in the Dates section.
    /// Associated value is the current due date ISO8601 string (or nil if not set).
    case dueDate(String?)
    /// A linked task in the Linked Tasks section.
    /// Associated value is the link DTO containing type and target UUID.
    case linkedTask(TaskLinkDto)
    /// A file attachment in the Attachments section.
    /// Associated value is the attachment DTO.
    case attachment(TaskAttachmentDto)
    /// The "+" button to add a new attachment.
    case addAttachmentButton
    /// An annotation in the Annotations section.
    /// Associated value is the annotation DTO.
    case annotation(TaskAnnotationDto)

    var id: String {
        switch self {
        case .taskName:
            "taskName"
        case .project:
            "project"
        case let .uuid(uuid):
            "uuid-\(uuid)"
        case let .gitlabMR(link):
            "gitlab-\(link.id)"
        case let .jiraIssue(link):
            "jira-\(link.id)"
        case let .tag(_, index):
            "tag-\(index)"
        case .addTagButton:
            "addTagButton"
        case .dueDate:
            "dueDate"
        case let .linkedTask(link):
            "linkedTask-\(link.id)"
        case let .attachment(attachment):
            "attachment-\(attachment.id)"
        case .addAttachmentButton:
            "addAttachmentButton"
        case let .annotation(annotation):
            "annotation-\(annotation.id)"
        }
    }

    /// What action "o" (open) performs on this item.
    /// Returns nil for items that cannot be opened.
    /// Note: Task name and project return nil here, but Enter key triggers editing instead.
    var openURL: URL? {
        switch self {
        case .taskName:
            nil // Task name uses Enter to edit, not open URL
        case .project:
            nil // Project uses Enter to edit, not open URL
        case .uuid:
            nil // UUID is not openable
        case let .gitlabMR(link):
            URL(string: link.url)
        case let .jiraIssue(link):
            URL(string: link.url)
        case .tag:
            nil // Tags use Enter to edit, not open URL
        case .addTagButton:
            nil // Add button uses Enter to start adding, not open URL
        case .dueDate:
            nil // Due date uses Enter to edit, not open URL
        case .linkedTask:
            nil // Linked task uses Enter to navigate, not open URL
        case .attachment:
            nil // Attachments use Enter to download and open, handled separately
        case .addAttachmentButton:
            nil // Add button uses Enter to start adding, not open URL
        case .annotation:
            nil // Annotations use Enter to edit, not open URL
        }
    }

    /// What "y" (copy) action should copy to clipboard.
    var copyValue: String {
        switch self {
        case let .taskName(summary):
            return summary
        case let .project(name):
            return name
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
        case let .tag(name, _):
            return name
        case .addTagButton:
            return "" // Nothing to copy from add button
        case let .dueDate(dateString):
            return dateString ?? ""
        case let .linkedTask(link):
            return link.targetUuid
        case let .attachment(attachment):
            return attachment.filename
        case .addAttachmentButton:
            return "" // Nothing to copy from add button
        case let .annotation(annotation):
            return annotation.value
        }
    }

    /// Label for the copy toast message.
    var copyLabel: String {
        switch self {
        case .taskName:
            return "Task name"
        case .project:
            return "Project"
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
        case .tag:
            return "Tag"
        case .addTagButton:
            return "" // Nothing to copy from add button
        case .dueDate:
            return "Due date"
        case .linkedTask:
            return "Task UUID"
        case .attachment:
            return "Filename"
        case .addAttachmentButton:
            return "" // Nothing to copy from add button
        case .annotation:
            return "Annotation"
        }
    }
}
