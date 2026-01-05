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

/// A section in the command palette containing items with an optional title.
///
/// Sections can hold either raw items (from contributors) or fuzzy-matched items
/// (after filtering). The `matchedItems` property provides access to the matched
/// items with their fuzzy match information for highlighting.
struct CommandPaletteSection: Identifiable {
    let id: String
    let title: String?
    let matchedItems: [FuzzyMatchedPaletteItem]
    let sectionTitleMatch: FuzzyMatch?

    /// Backward compatibility: access raw items without match info.
    var items: [CommandPaletteItem] { matchedItems.map(\.item) }

    /// Initializer for section contributors (no highlighting yet).
    init(id: String = UUID().uuidString, title: String? = nil, items: [CommandPaletteItem]) {
        self.id = id
        self.title = title
        matchedItems = items.map { FuzzyMatchedPaletteItem(item: $0, titleMatch: nil, subtitleMatch: nil) }
        sectionTitleMatch = nil
    }

    /// Initializer for filtered sections with match info for highlighting.
    init(
        id: String = UUID().uuidString,
        title: String? = nil,
        matchedItems: [FuzzyMatchedPaletteItem],
        sectionTitleMatch: FuzzyMatch? = nil
    ) {
        self.id = id
        self.title = title
        self.matchedItems = matchedItems
        self.sectionTitleMatch = sectionTitleMatch
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

    /// Returns true if this item should always be shown regardless of filtering.
    var isPinned: Bool {
        switch self {
        case let .action(item): item.isPinned
        default: false
        }
    }
}

/// A command palette item wrapped with fuzzy match information for highlighting.
///
/// This struct pairs a `CommandPaletteItem` with optional match results from
/// `FuzzyMatcher`, enabling the view layer to highlight matched characters
/// in the title and subtitle.
struct FuzzyMatchedPaletteItem: Identifiable {
    let item: CommandPaletteItem
    let titleMatch: FuzzyMatch?
    let subtitleMatch: FuzzyMatch?

    var id: String { item.id }

    /// Combined score for sorting (best of title/subtitle matches).
    /// Returns 0 if neither matched.
    var score: Double {
        max(titleMatch?.score ?? 0, subtitleMatch?.score ?? 0)
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
    /// When true, this item is always shown regardless of search query filtering.
    let isPinned: Bool
    let handler: () -> Void

    init(
        id: String,
        title: String,
        subtitle: String? = nil,
        icon: CommandPaletteIcon? = nil,
        shortcut: String? = nil,
        requiresSelectedTask: Bool = false,
        isPinned: Bool = false,
        handler: @escaping () -> Void
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.shortcut = shortcut
        self.requiresSelectedTask = requiresSelectedTask
        self.isPinned = isPinned
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

    /// All selectable items across all sections (without match info).
    var selectableItems: [CommandPaletteItem] {
        sections.flatMap { $0.items.filter(\.isSelectable) }
    }

    /// All selectable matched items across all sections (with match info for highlighting).
    var selectableMatchedItems: [FuzzyMatchedPaletteItem] {
        sections.flatMap { $0.matchedItems.filter(\.item.isSelectable) }
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
