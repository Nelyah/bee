import Foundation

enum CommandPaletteMode: String {
    case root
    case addGitlab
    case addJira
    case selectReport
}

enum CommandPaletteAction: String, CaseIterable, Identifiable {
    case selectReport = "Select Report"
    case addGitlab = "Add GitLab link"
    case addJira = "Add Jira link"

    var id: String { rawValue }

    /// Whether this action requires a task to be selected.
    var requiresSelectedTask: Bool {
        switch self {
        case .selectReport:
            return false
        case .addGitlab, .addJira:
            return true
        }
    }
}

enum CommandPaletteSuggestion: Identifiable {
    case gitlab(GitlabMergeRequestSuggestion)
    case jira(JiraIssueSuggestion)
    case rawInput(String)
    case report(ReportSummary)

    var id: String {
        switch self {
        case .gitlab(let mr):
            return "gitlab-\(mr.id)"
        case .jira(let issue):
            return "jira-\(issue.key)"
        case .rawInput(let value):
            return "raw-\(value)"
        case .report(let summary):
            return "report-\(summary.name)"
        }
    }

    var displayTitle: String {
        switch self {
        case .gitlab(let mr):
            return mr.title
        case .jira(let issue):
            return issue.summary
        case .rawInput(let value):
            return "Use \(value)"
        case .report(let summary):
            return summary.name
        }
    }

    var subtitle: String {
        switch self {
        case .gitlab(let mr):
            return "MR !\(mr.id) • \(mr.projectPath)"
        case .jira(let issue):
            return "\(issue.key) • \(issue.status)"
        case .rawInput:
            return "Paste or resolve input"
        case .report(let summary):
            let filterText = summary.filters.isEmpty ? "No filters" : summary.filters.joined(separator: " • ")
            return filterText
        }
    }
}
