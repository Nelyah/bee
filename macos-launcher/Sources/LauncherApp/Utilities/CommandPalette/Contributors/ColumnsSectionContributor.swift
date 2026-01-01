import Foundation

/// Contributes column management options to the command palette.
///
/// This section allows users to:
/// - Add columns that are not currently visible
/// - Remove columns (except summary, which is always required)
struct ColumnsSectionContributor: CommandPaletteSectionContributor {
    var contributorId: String { "columns" }
    var priority: Int { 15 } // After actions (0) and group-by (10)

    private let currentColumns: () -> [ColumnConfig]
    private let onAddColumn: (ColumnDefinition) -> Void
    private let onRemoveColumn: (String) -> Void

    init(
        currentColumns: @escaping () -> [ColumnConfig],
        onAddColumn: @escaping (ColumnDefinition) -> Void,
        onRemoveColumn: @escaping (String) -> Void
    ) {
        self.currentColumns = currentColumns
        self.onAddColumn = onAddColumn
        self.onRemoveColumn = onRemoveColumn
    }

    func buildSections(context: CommandPaletteContext, query: String) -> [CommandPaletteSection] {
        var items: [CommandPaletteItem] = []

        // Add Column submenu
        items.append(
            .submenu(
                CommandPaletteSubmenuItem(
                    id: "add-column",
                    title: "Add Column",
                    subtitle: nil,
                    icon: .system("plus.rectangle.on.rectangle"),
                    menuBuilder: { [currentColumns, onAddColumn] in
                        buildAddColumnMenu(
                            currentColumns: currentColumns(),
                            onAdd: onAddColumn
                        )
                    }
                )
            )
        )

        // Remove Column submenu (only if there are removable columns)
        let removableColumns = currentColumns().filter { config in
            ColumnDefinition(rawValue: config.key)?.isRemovable ?? true
        }
        if !removableColumns.isEmpty {
            items.append(
                .submenu(
                    CommandPaletteSubmenuItem(
                        id: "remove-column",
                        title: "Remove Column",
                        subtitle: nil,
                        icon: .system("minus.rectangle"),
                        menuBuilder: { [currentColumns, onRemoveColumn] in
                            buildRemoveColumnMenu(
                                currentColumns: currentColumns(),
                                onRemove: onRemoveColumn
                            )
                        }
                    )
                )
            )
        }

        return [CommandPaletteSection(id: "columns", title: "Columns", items: items)]
    }

    /// Build the "Add Column" submenu showing columns not currently visible.
    private func buildAddColumnMenu(
        currentColumns: [ColumnConfig],
        onAdd: @escaping (ColumnDefinition) -> Void
    ) -> CommandPaletteMenu {
        let currentKeys = Set(currentColumns.map(\.key))

        // Find columns that are not currently visible
        let availableColumns = ColumnDefinition.allCases.filter { !currentKeys.contains($0.rawValue) }

        let items: [CommandPaletteItem] = availableColumns.map { column in
            .action(
                CommandPaletteActionItem(
                    id: "add-column-\(column.rawValue)",
                    title: column.displayName,
                    subtitle: nil,
                    icon: .system(column.icon),
                    handler: { onAdd(column) }
                )
            )
        }

        // If no columns available to add, show a disabled message
        let finalItems: [CommandPaletteItem] = items.isEmpty
            ? [.shortcut(CommandPaletteShortcutItem(
                id: "no-columns-to-add",
                title: "All columns are visible",
                keys: ""
            ))]
            : items

        return CommandPaletteMenu(
            id: "add-column-menu",
            title: "Add Column",
            sections: [
                CommandPaletteSection(id: "available-columns", title: nil, items: finalItems),
            ]
        )
    }

    /// Build the "Remove Column" submenu showing columns that can be removed.
    private func buildRemoveColumnMenu(
        currentColumns: [ColumnConfig],
        onRemove: @escaping (String) -> Void
    ) -> CommandPaletteMenu {
        // Filter to removable columns (summary cannot be removed)
        let removableColumns = currentColumns.filter { config in
            ColumnDefinition(rawValue: config.key)?.isRemovable ?? true
        }

        let items: [CommandPaletteItem] = removableColumns.map { config in
            let definition = ColumnDefinition(rawValue: config.key)
            return .action(
                CommandPaletteActionItem(
                    id: "remove-column-\(config.key)",
                    title: config.displayName,
                    subtitle: nil,
                    icon: .system(definition?.icon ?? "rectangle"),
                    handler: { onRemove(config.key) }
                )
            )
        }

        return CommandPaletteMenu(
            id: "remove-column-menu",
            title: "Remove Column",
            sections: [
                CommandPaletteSection(id: "removable-columns", title: nil, items: items),
            ]
        )
    }
}
