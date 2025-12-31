import Foundation

/// Contributes the shortcuts section to the command palette.
///
/// This section appears last and displays available keyboard shortcuts.
/// Shortcuts are display-only and not selectable.
struct ShortcutsSectionContributor: CommandPaletteSectionContributor {
    var contributorId: String { "shortcuts" }
    var priority: Int { 100 }

    func buildSections(context: CommandPaletteContext, query: String) -> [CommandPaletteSection] {
        // Don't show shortcuts when filtering
        guard query.isEmpty else { return [] }

        let items: [CommandPaletteItem] = [
            .shortcut(
                CommandPaletteShortcutItem(
                    id: "sc-escape",
                    title: "Close / Back",
                    keys: "Esc"
                )
            ),
            .shortcut(
                CommandPaletteShortcutItem(
                    id: "sc-enter",
                    title: "Select",
                    keys: "Return"
                )
            ),
            .shortcut(
                CommandPaletteShortcutItem(
                    id: "sc-up",
                    title: "Move Up",
                    keys: "↑ / Ctrl+P"
                )
            ),
            .shortcut(
                CommandPaletteShortcutItem(
                    id: "sc-down",
                    title: "Move Down",
                    keys: "↓ / Ctrl+N"
                )
            ),
        ]

        return [CommandPaletteSection(id: "shortcuts", title: "Shortcuts", items: items)]
    }
}
