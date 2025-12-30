import Foundation

enum CommandPaletteMode: String {
    case root
    case addGitlab
    case addJira
}

enum CommandPaletteAction: String, CaseIterable, Identifiable {
    case addGitlab = "Add GitLab link"
    case addJira = "Add Jira link"

    var id: String { rawValue }
}

enum CommandPaletteSuggestion: Identifiable {
    case gitlab(GitlabMergeRequestSuggestion)
    case jira(JiraIssueSuggestion)
    case rawInput(String)

    var id: String {
        switch self {
        case .gitlab(let mr):
            return "gitlab-\(mr.id)"
        case .jira(let issue):
            return "jira-\(issue.key)"
        case .rawInput(let value):
            return "raw-\(value)"
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
        }
    }
}
