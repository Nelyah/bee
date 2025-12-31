import Foundation

/// Grouping option for task list display.
enum GroupByOption: String, CaseIterable {
    case project
    case dueDate
    case tag
    case none

    var displayName: String {
        switch self {
        case .project: "Project"
        case .dueDate: "Due Date"
        case .tag: "Tag"
        case .none: "None"
        }
    }

    var icon: CommandPaletteIcon {
        switch self {
        case .project: .system("folder")
        case .dueDate: .system("calendar")
        case .tag: .system("tag")
        case .none: .system("list.bullet")
        }
    }

    func makeStrategy() -> TaskGroupingStrategy {
        switch self {
        case .project: ProjectGroupingStrategy()
        case .dueDate: DueDateGroupingStrategy()
        case .tag: TagGroupingStrategy()
        case .none: NoGroupingStrategy()
        }
    }
}

/// Contributes group-by options to the command palette.
struct GroupBySectionContributor: CommandPaletteSectionContributor {
    var contributorId: String { "groupBy" }
    var priority: Int { 10 }

    private let currentGroupBy: () -> GroupByOption
    private let onGroupBySelect: (GroupByOption) -> Void

    init(
        currentGroupBy: @escaping () -> GroupByOption,
        onGroupBySelect: @escaping (GroupByOption) -> Void
    ) {
        self.currentGroupBy = currentGroupBy
        self.onGroupBySelect = onGroupBySelect
    }

    func buildSections(context: CommandPaletteContext, query: String) -> [CommandPaletteSection] {
        let current = currentGroupBy()
        let items: [CommandPaletteItem] = GroupByOption.allCases.map { option in
            .action(
                CommandPaletteActionItem(
                    id: "group-by-\(option.rawValue)",
                    title: option.displayName,
                    subtitle: option == current ? "Current" : nil,
                    icon: option.icon,
                    handler: { [onGroupBySelect] in onGroupBySelect(option) }
                )
            )
        }

        return [CommandPaletteSection(id: "groupBy", title: "Group By", items: items)]
    }
}
