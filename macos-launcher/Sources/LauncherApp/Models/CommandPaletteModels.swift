import Combine
import Foundation

// MARK: - Command Palette Types

/// Icon representation for palette items
enum CommandPaletteIcon: Equatable {
    case system(String)
    case asset(String)
    case gitlab
    case jira
}

/// Metadata for different suggestion types
enum CommandPaletteSuggestionMetadata {
    case gitlab(GitlabMergeRequestSuggestion)
    case jira(JiraIssueSuggestion)
    case report(ReportSummary)
    case rawInput(String)
}

/// A section in the command palette containing items with an optional title
struct CommandPaletteSection: Identifiable {
    let id: String
    let title: String?
    let items: [CommandPaletteItem]

    init(id: String = UUID().uuidString, title: String? = nil, items: [CommandPaletteItem]) {
        self.id = id
        self.title = title
        self.items = items
    }
}

/// Represents a selectable or navigable item in the command palette
enum CommandPaletteItem: Identifiable {
    case action(CommandPaletteActionItem)
    case submenu(CommandPaletteSubmenuItem)
    case suggestion(CommandPaletteSuggestionItem)
    case shortcut(CommandPaletteShortcutItem)

    var id: String {
        switch self {
        case let .action(item): "action-\(item.id)"
        case let .submenu(item): "submenu-\(item.id)"
        case let .suggestion(item): "suggestion-\(item.id)"
        case let .shortcut(item): "shortcut-\(item.id)"
        }
    }

    var displayTitle: String {
        switch self {
        case let .action(item): item.title
        case let .submenu(item): item.title
        case let .suggestion(item): item.title
        case let .shortcut(item): item.title
        }
    }

    var subtitle: String? {
        switch self {
        case let .action(item): item.subtitle
        case let .submenu(item): item.subtitle
        case let .suggestion(item): item.subtitle
        case .shortcut: nil
        }
    }

    var icon: CommandPaletteIcon? {
        switch self {
        case let .action(item): item.icon
        case let .submenu(item): item.icon
        case let .suggestion(item): item.icon
        case .shortcut: nil
        }
    }

    var isSelectable: Bool {
        switch self {
        case .shortcut: false
        default: true
        }
    }
}

/// An executable action item
struct CommandPaletteActionItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    let icon: CommandPaletteIcon?
    let shortcut: String?
    let requiresSelectedTask: Bool
    let handler: () -> Void

    init(
        id: String,
        title: String,
        subtitle: String? = nil,
        icon: CommandPaletteIcon? = nil,
        shortcut: String? = nil,
        requiresSelectedTask: Bool = false,
        handler: @escaping () -> Void
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.shortcut = shortcut
        self.requiresSelectedTask = requiresSelectedTask
        self.handler = handler
    }
}

/// A submenu item that pushes a new menu level
struct CommandPaletteSubmenuItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    let icon: CommandPaletteIcon?
    let menuBuilder: @MainActor () -> CommandPaletteMenu

    init(
        id: String,
        title: String,
        subtitle: String? = nil,
        icon: CommandPaletteIcon? = nil,
        menuBuilder: @MainActor @escaping () -> CommandPaletteMenu
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.menuBuilder = menuBuilder
    }
}

/// A suggestion item with metadata
struct CommandPaletteSuggestionItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    let icon: CommandPaletteIcon?
    let metadata: CommandPaletteSuggestionMetadata
    let handler: () -> Void

    init(
        id: String,
        title: String,
        subtitle: String? = nil,
        icon: CommandPaletteIcon? = nil,
        metadata: CommandPaletteSuggestionMetadata,
        handler: @escaping () -> Void
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.metadata = metadata
        self.handler = handler
    }
}

/// A shortcut display item (display-only, not selectable)
struct CommandPaletteShortcutItem: Identifiable {
    let id: String
    let title: String
    let keys: String
}

/// Represents a menu level in the navigation stack
struct CommandPaletteMenu: Identifiable {
    let id: String
    let title: String
    let sections: [CommandPaletteSection]

    init(
        id: String = UUID().uuidString,
        title: String,
        sections: [CommandPaletteSection]
    ) {
        self.id = id
        self.title = title
        self.sections = sections
    }

    /// All selectable items across all sections
    var selectableItems: [CommandPaletteItem] {
        sections.flatMap { $0.items.filter(\.isSelectable) }
    }
}

/// Manages the navigation stack for nested menus
final class CommandPaletteStack: ObservableObject {
    @Published private(set) var stack: [CommandPaletteMenu] = []

    var currentMenu: CommandPaletteMenu? { stack.last }
    var isAtRoot: Bool { stack.count <= 1 }
    var depth: Int { stack.count }
    var breadcrumb: [String] { stack.map(\.title) }

    func push(_ menu: CommandPaletteMenu) {
        stack.append(menu)
    }

    @discardableResult
    func pop() -> Bool {
        guard stack.count > 1 else { return false }
        stack.removeLast()
        return true
    }

    func reset(to root: CommandPaletteMenu) {
        stack = [root]
    }

    func clear() {
        stack = []
    }
}

/// Context passed to section contributors for building sections
struct CommandPaletteContext {
    let hasSelectedTask: Bool
    let selectedTaskUUID: String?
    let currentReportName: String?
    let availableReports: [ReportSummary]
    let projects: [String]
    let tags: [String]
    let currentProjectScope: String?

    init(
        hasSelectedTask: Bool = false,
        selectedTaskUUID: String? = nil,
        currentReportName: String? = nil,
        availableReports: [ReportSummary] = [],
        projects: [String] = [],
        tags: [String] = [],
        currentProjectScope: String? = nil
    ) {
        self.hasSelectedTask = hasSelectedTask
        self.selectedTaskUUID = selectedTaskUUID
        self.currentReportName = currentReportName
        self.availableReports = availableReports
        self.projects = projects
        self.tags = tags
        self.currentProjectScope = currentProjectScope
    }
}
