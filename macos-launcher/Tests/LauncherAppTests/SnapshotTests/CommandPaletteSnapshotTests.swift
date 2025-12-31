@testable import LauncherApp
import SnapshotTesting
import SwiftUI
import XCTest

/// Snapshot tests for CommandPaletteView to catch visual regressions.
///
/// These tests capture the rendered appearance of the command palette in various states.
/// Note: The CommandPaletteView has a fixed width of 520px internally.
@MainActor
final class CommandPaletteSnapshotTests: SnapshotTestCase {
    // MARK: - Test Setup

    private func makeViewModel() -> LauncherViewModel {
        LauncherViewModel(apiClient: MockApiClient())
    }

    private func makeSection(
        id: String,
        title: String?,
        items: [CommandPaletteItem]
    ) -> CommandPaletteSection {
        TestHelpers.makeCommandPaletteSection(id: id, title: title, items: items)
    }

    private func makeActionItem(
        id: String,
        title: String,
        subtitle: String? = nil,
        icon: CommandPaletteIcon? = .system("star")
    ) -> CommandPaletteItem {
        TestHelpers.makeCommandPaletteActionItem(
            id: id,
            title: title,
            subtitle: subtitle,
            icon: icon
        )
    }

    // MARK: - Basic States

    func testCommandPaletteLoading() {
        let viewModel = makeViewModel()
        viewModel.commandPalette.isLoading = true

        let view = CommandPaletteView(
            viewModel: viewModel,
            commandPalette: viewModel.commandPalette
        )

        assertViewSnapshot(view, size: TestSizes.commandPalette)
    }

    func testCommandPaletteEmpty() {
        let viewModel = makeViewModel()
        let coordinator = viewModel.commandPalette

        // Open with empty context
        _ = coordinator.open(context: CommandPaletteContext())

        // Push empty menu
        let menu = TestHelpers.makeCommandPaletteMenu(sections: [])
        coordinator.pushMenu(menu)

        let view = CommandPaletteView(
            viewModel: viewModel,
            commandPalette: coordinator
        )

        assertViewSnapshot(view, size: TestSizes.commandPalette)
    }

    // MARK: - Single Section

    func testCommandPaletteWithSingleSection() {
        let viewModel = makeViewModel()
        let coordinator = viewModel.commandPalette

        _ = coordinator.open(context: CommandPaletteContext())

        let section = makeSection(
            id: "actions",
            title: "Actions",
            items: [
                makeActionItem(id: "1", title: "Create Task", icon: .system("plus")),
                makeActionItem(id: "2", title: "Edit Task", icon: .system("pencil")),
                makeActionItem(id: "3", title: "Delete Task", icon: .system("trash")),
            ]
        )
        let menu = TestHelpers.makeCommandPaletteMenu(sections: [section])
        coordinator.pushMenu(menu)

        let view = CommandPaletteView(
            viewModel: viewModel,
            commandPalette: coordinator
        )

        assertViewSnapshot(view, size: TestSizes.commandPalette)
    }

    func testCommandPaletteWithSectionNoTitle() {
        let viewModel = makeViewModel()
        let coordinator = viewModel.commandPalette

        _ = coordinator.open(context: CommandPaletteContext())

        let section = makeSection(
            id: "actions",
            title: nil,
            items: [
                makeActionItem(id: "1", title: "Quick Action", icon: .system("bolt")),
                makeActionItem(id: "2", title: "Another Action", icon: .system("sparkles")),
            ]
        )
        let menu = TestHelpers.makeCommandPaletteMenu(sections: [section])
        coordinator.pushMenu(menu)

        let view = CommandPaletteView(
            viewModel: viewModel,
            commandPalette: coordinator
        )

        assertViewSnapshot(view, size: TestSizes.commandPalette)
    }

    // MARK: - Multiple Sections

    func testCommandPaletteWithMultipleSections() {
        let viewModel = makeViewModel()
        let coordinator = viewModel.commandPalette

        _ = coordinator.open(context: CommandPaletteContext())

        let sections = [
            makeSection(
                id: "recent",
                title: "Recent",
                items: [
                    makeActionItem(id: "r1", title: "Last Edited Task", icon: .system("clock")),
                    makeActionItem(id: "r2", title: "Previous Task", icon: .system("clock.arrow.circlepath")),
                ]
            ),
            makeSection(
                id: "actions",
                title: "Actions",
                items: [
                    makeActionItem(id: "a1", title: "New Task", icon: .system("plus.circle")),
                    makeActionItem(id: "a2", title: "Search", icon: .system("magnifyingglass")),
                ]
            ),
            makeSection(
                id: "navigation",
                title: "Navigation",
                items: [
                    makeActionItem(id: "n1", title: "Go to Project", icon: .system("folder")),
                ]
            ),
        ]
        let menu = TestHelpers.makeCommandPaletteMenu(sections: sections)
        coordinator.pushMenu(menu)

        let view = CommandPaletteView(
            viewModel: viewModel,
            commandPalette: coordinator
        )

        assertViewSnapshot(view, size: CGSize(width: 600, height: 500))
    }

    // MARK: - Selection State

    func testCommandPaletteWithSelectedItem() {
        let viewModel = makeViewModel()
        let coordinator = viewModel.commandPalette

        _ = coordinator.open(context: CommandPaletteContext())

        let section = makeSection(
            id: "items",
            title: "Choose",
            items: [
                makeActionItem(id: "1", title: "First Option"),
                makeActionItem(id: "2", title: "Second Option"),
                makeActionItem(id: "3", title: "Third Option"),
            ]
        )
        let menu = TestHelpers.makeCommandPaletteMenu(sections: [section])
        coordinator.pushMenu(menu)

        // Select the second item
        coordinator.selectionIndex = 1

        let view = CommandPaletteView(
            viewModel: viewModel,
            commandPalette: coordinator
        )

        assertViewSnapshot(view, size: TestSizes.commandPalette)
    }

    func testCommandPaletteWithLastItemSelected() {
        let viewModel = makeViewModel()
        let coordinator = viewModel.commandPalette

        _ = coordinator.open(context: CommandPaletteContext())

        let section = makeSection(
            id: "items",
            title: nil,
            items: [
                makeActionItem(id: "1", title: "Option A"),
                makeActionItem(id: "2", title: "Option B"),
                makeActionItem(id: "3", title: "Option C"),
            ]
        )
        let menu = TestHelpers.makeCommandPaletteMenu(sections: [section])
        coordinator.pushMenu(menu)

        // Select the last item
        coordinator.selectionIndex = 2

        let view = CommandPaletteView(
            viewModel: viewModel,
            commandPalette: coordinator
        )

        assertViewSnapshot(view, size: TestSizes.commandPalette)
    }

    // MARK: - Navigation State (Breadcrumbs)

    func testCommandPaletteWithBreadcrumbs() {
        let viewModel = makeViewModel()
        let coordinator = viewModel.commandPalette

        _ = coordinator.open(context: CommandPaletteContext())

        // Push a submenu to create breadcrumbs
        let submenu = TestHelpers.makeCommandPaletteMenu(
            id: "settings",
            title: "Settings",
            sections: [
                makeSection(
                    id: "general",
                    title: "General",
                    items: [
                        makeActionItem(id: "1", title: "Theme", icon: .system("paintpalette")),
                        makeActionItem(id: "2", title: "Notifications", icon: .system("bell")),
                    ]
                ),
            ]
        )
        coordinator.pushMenu(submenu)

        let view = CommandPaletteView(
            viewModel: viewModel,
            commandPalette: coordinator
        )

        assertViewSnapshot(view, size: TestSizes.commandPalette)
    }

    func testCommandPaletteDeepNavigation() {
        let viewModel = makeViewModel()
        let coordinator = viewModel.commandPalette

        _ = coordinator.open(context: CommandPaletteContext())

        // Push multiple submenus for deep navigation
        let level1 = TestHelpers.makeCommandPaletteMenu(
            id: "level1",
            title: "Level 1",
            sections: []
        )
        coordinator.pushMenu(level1)

        let level2 = TestHelpers.makeCommandPaletteMenu(
            id: "level2",
            title: "Level 2",
            sections: [
                makeSection(
                    id: "items",
                    title: nil,
                    items: [makeActionItem(id: "1", title: "Deep Item")]
                ),
            ]
        )
        coordinator.pushMenu(level2)

        let view = CommandPaletteView(
            viewModel: viewModel,
            commandPalette: coordinator
        )

        assertViewSnapshot(view, size: TestSizes.commandPalette)
    }

    // MARK: - Item Variations

    func testCommandPaletteWithSubtitles() {
        let viewModel = makeViewModel()
        let coordinator = viewModel.commandPalette

        _ = coordinator.open(context: CommandPaletteContext())

        let section = makeSection(
            id: "items",
            title: "Actions",
            items: [
                makeActionItem(
                    id: "1",
                    title: "Export Data",
                    subtitle: "Save tasks to JSON file",
                    icon: .system("square.and.arrow.up")
                ),
                makeActionItem(
                    id: "2",
                    title: "Import Data",
                    subtitle: "Load tasks from JSON file",
                    icon: .system("square.and.arrow.down")
                ),
                makeActionItem(
                    id: "3",
                    title: "Sync",
                    subtitle: "Synchronize with remote server",
                    icon: .system("arrow.triangle.2.circlepath")
                ),
            ]
        )
        let menu = TestHelpers.makeCommandPaletteMenu(sections: [section])
        coordinator.pushMenu(menu)

        let view = CommandPaletteView(
            viewModel: viewModel,
            commandPalette: coordinator
        )

        assertViewSnapshot(view, size: TestSizes.commandPalette)
    }

    func testCommandPaletteWithSubmenuItems() {
        let viewModel = makeViewModel()
        let coordinator = viewModel.commandPalette

        _ = coordinator.open(context: CommandPaletteContext())

        let section = makeSection(
            id: "menus",
            title: "Navigate",
            items: [
                TestHelpers.makeCommandPaletteSubmenuItem(
                    id: "sub1",
                    title: "Projects",
                    subtitle: "Browse all projects",
                    icon: .system("folder.fill")
                ),
                TestHelpers.makeCommandPaletteSubmenuItem(
                    id: "sub2",
                    title: "Tags",
                    subtitle: "Browse all tags",
                    icon: .system("tag.fill")
                ),
            ]
        )
        let menu = TestHelpers.makeCommandPaletteMenu(sections: [section])
        coordinator.pushMenu(menu)

        let view = CommandPaletteView(
            viewModel: viewModel,
            commandPalette: coordinator
        )

        assertViewSnapshot(view, size: TestSizes.commandPalette)
    }

    func testCommandPaletteMixedItemTypes() {
        let viewModel = makeViewModel()
        let coordinator = viewModel.commandPalette

        _ = coordinator.open(context: CommandPaletteContext())

        let section = makeSection(
            id: "mixed",
            title: "Commands",
            items: [
                makeActionItem(id: "1", title: "Quick Action", icon: .system("bolt")),
                TestHelpers.makeCommandPaletteSubmenuItem(
                    id: "sub1",
                    title: "More Options",
                    icon: .system("ellipsis.circle")
                ),
                makeActionItem(id: "2", title: "Another Action", icon: .system("sparkles")),
            ]
        )
        let menu = TestHelpers.makeCommandPaletteMenu(sections: [section])
        coordinator.pushMenu(menu)

        let view = CommandPaletteView(
            viewModel: viewModel,
            commandPalette: coordinator
        )

        assertViewSnapshot(view, size: TestSizes.commandPalette)
    }

    // MARK: - Search Query State

    func testCommandPaletteWithSearchQuery() {
        let viewModel = makeViewModel()
        let coordinator = viewModel.commandPalette

        _ = coordinator.open(context: CommandPaletteContext())

        // Set a search query
        coordinator.query = "task"

        let section = makeSection(
            id: "results",
            title: "Results",
            items: [
                makeActionItem(id: "1", title: "Create Task"),
                makeActionItem(id: "2", title: "Edit Task"),
            ]
        )
        let menu = TestHelpers.makeCommandPaletteMenu(sections: [section])
        coordinator.pushMenu(menu)

        let view = CommandPaletteView(
            viewModel: viewModel,
            commandPalette: coordinator
        )

        assertViewSnapshot(view, size: TestSizes.commandPalette)
    }

    // MARK: - Long Content

    func testCommandPaletteWithManyItems() {
        let viewModel = makeViewModel()
        let coordinator = viewModel.commandPalette

        _ = coordinator.open(context: CommandPaletteContext())

        let items = (1 ... 10).map { i in
            makeActionItem(
                id: "item-\(i)",
                title: "Action Item \(i)",
                subtitle: "Description for item \(i)",
                icon: .system("star")
            )
        }

        let section = makeSection(id: "many", title: "Many Items", items: items)
        let menu = TestHelpers.makeCommandPaletteMenu(sections: [section])
        coordinator.pushMenu(menu)

        let view = CommandPaletteView(
            viewModel: viewModel,
            commandPalette: coordinator
        )

        // Taller to show scrollable content
        assertViewSnapshot(view, size: CGSize(width: 600, height: 600))
    }

    func testCommandPaletteWithLongTitles() {
        let viewModel = makeViewModel()
        let coordinator = viewModel.commandPalette

        _ = coordinator.open(context: CommandPaletteContext())

        let section = makeSection(
            id: "long",
            title: "Actions With Long Names",
            items: [
                makeActionItem(
                    id: "1",
                    title: "This is a very long action title that might wrap or truncate",
                    subtitle: "And this subtitle is also quite long to test text handling"
                ),
                makeActionItem(
                    id: "2",
                    title: "Another lengthy command name for testing purposes"
                ),
            ]
        )
        let menu = TestHelpers.makeCommandPaletteMenu(sections: [section])
        coordinator.pushMenu(menu)

        let view = CommandPaletteView(
            viewModel: viewModel,
            commandPalette: coordinator
        )

        assertViewSnapshot(view, size: TestSizes.commandPalette)
    }
}
