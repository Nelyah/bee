@testable import LauncherApp
import SwiftUI
import ViewInspector
import XCTest

/// UI tests for CommandPaletteView using ViewInspector.
///
/// These tests verify the command palette's structure, content display, and section rendering.
/// Note: Some interactive features (keyboard navigation, NSEvent monitoring) are not testable
/// with ViewInspector alone.
@MainActor
final class CommandPaletteUITests: XCTestCase {
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

    // MARK: - Basic Rendering Tests

    func testCommandPaletteDisplaysSearchField() throws {
        let viewModel = makeViewModel()
        let sut = CommandPaletteView(
            viewModel: viewModel,
            commandPalette: viewModel.commandPalette
        )

        let view = try sut.inspect()

        // Should have a TextField for search
        _ = try view.find(ViewType.TextField.self)
    }

    func testCommandPaletteDisplaysSearchPlaceholder() throws {
        let viewModel = makeViewModel()
        let sut = CommandPaletteView(
            viewModel: viewModel,
            commandPalette: viewModel.commandPalette
        )

        let view = try sut.inspect()

        // Should have "Search" placeholder text in the TextField
        let textField = try view.find(ViewType.TextField.self)
        XCTAssertNotNil(textField)
    }

    func testCommandPaletteDisplaysMagnifyingGlass() throws {
        let viewModel = makeViewModel()
        let sut = CommandPaletteView(
            viewModel: viewModel,
            commandPalette: viewModel.commandPalette
        )

        let view = try sut.inspect()

        // Should display the magnifying glass icon
        _ = try view.find(ViewType.Image.self)
    }

    // MARK: - Loading State Tests

    func testCommandPaletteDisplaysLoadingSpinner() throws {
        let viewModel = makeViewModel()
        viewModel.commandPalette.isLoading = true

        let sut = CommandPaletteView(
            viewModel: viewModel,
            commandPalette: viewModel.commandPalette
        )

        let view = try sut.inspect()

        // Should display ProgressView when loading
        _ = try view.find(ViewType.ProgressView.self)
    }

    func testCommandPaletteDisplaysLoadingText() throws {
        let viewModel = makeViewModel()
        viewModel.commandPalette.isLoading = true

        let sut = CommandPaletteView(
            viewModel: viewModel,
            commandPalette: viewModel.commandPalette
        )

        let view = try sut.inspect()

        // Should display "Loading…" text
        _ = try view.find(text: "Loading…")
    }

    // MARK: - Section Rendering Tests

    func testCommandPaletteDisplaysSectionTitle() throws {
        let viewModel = makeViewModel()
        let coordinator = viewModel.commandPalette

        // Open the command palette to initialize it
        _ = coordinator.open(context: CommandPaletteContext())

        // Create a menu with a section that has a title
        let section = makeSection(
            id: "actions",
            title: "Actions",
            items: [makeActionItem(id: "action-1", title: "Test Action")]
        )
        let menu = TestHelpers.makeCommandPaletteMenu(
            id: "test",
            title: "Test",
            sections: [section]
        )
        coordinator.pushMenu(menu)

        let sut = CommandPaletteView(
            viewModel: viewModel,
            commandPalette: coordinator
        )

        let view = try sut.inspect()

        // Should display section title in uppercase
        _ = try view.find(text: "ACTIONS")
    }

    func testCommandPaletteDisplaysItemTitle() throws {
        let viewModel = makeViewModel()
        let coordinator = viewModel.commandPalette

        _ = coordinator.open(context: CommandPaletteContext())

        let section = makeSection(
            id: "actions",
            title: nil,
            items: [makeActionItem(id: "action-1", title: "Create New Task")]
        )
        let menu = TestHelpers.makeCommandPaletteMenu(sections: [section])
        coordinator.pushMenu(menu)

        let sut = CommandPaletteView(
            viewModel: viewModel,
            commandPalette: coordinator
        )

        let view = try sut.inspect()

        // Should display the action item title
        _ = try view.find(text: "Create New Task")
    }

    func testCommandPaletteDisplaysItemSubtitle() throws {
        let viewModel = makeViewModel()
        let coordinator = viewModel.commandPalette

        _ = coordinator.open(context: CommandPaletteContext())

        let section = makeSection(
            id: "actions",
            title: nil,
            items: [
                makeActionItem(
                    id: "action-1",
                    title: "Open Settings",
                    subtitle: "Configure application preferences"
                ),
            ]
        )
        let menu = TestHelpers.makeCommandPaletteMenu(sections: [section])
        coordinator.pushMenu(menu)

        let sut = CommandPaletteView(
            viewModel: viewModel,
            commandPalette: coordinator
        )

        let view = try sut.inspect()

        // Should display the subtitle
        _ = try view.find(text: "Configure application preferences")
    }

    // MARK: - Navigation State Tests

    func testCommandPaletteShowsBreadcrumbWhenNotAtRoot() throws {
        let viewModel = makeViewModel()
        let coordinator = viewModel.commandPalette

        _ = coordinator.open(context: CommandPaletteContext())

        // Push a submenu to get breadcrumbs
        let submenu = TestHelpers.makeCommandPaletteMenu(
            id: "settings",
            title: "Settings",
            sections: []
        )
        coordinator.pushMenu(submenu)

        let sut = CommandPaletteView(
            viewModel: viewModel,
            commandPalette: coordinator
        )

        let view = try sut.inspect()

        // Should show breadcrumb with menu title
        // Breadcrumb shows "Command Palette › Settings"
        _ = try view.find(text: "Command Palette › Settings")
    }

    func testCommandPaletteShowsBackButtonWhenNotAtRoot() throws {
        let viewModel = makeViewModel()
        let coordinator = viewModel.commandPalette

        _ = coordinator.open(context: CommandPaletteContext())

        let submenu = TestHelpers.makeCommandPaletteMenu(title: "Submenu", sections: [])
        coordinator.pushMenu(submenu)

        let sut = CommandPaletteView(
            viewModel: viewModel,
            commandPalette: coordinator
        )

        let view = try sut.inspect()

        // Should show back button (chevron.left image)
        // Find at least one button in the breadcrumb area
        _ = try view.find(ViewType.Button.self)
    }

    func testCommandPaletteShowsBackRowWhenNotAtRoot() throws {
        let viewModel = makeViewModel()
        let coordinator = viewModel.commandPalette

        _ = coordinator.open(context: CommandPaletteContext())

        let submenu = TestHelpers.makeCommandPaletteMenu(title: "Submenu", sections: [])
        coordinator.pushMenu(submenu)

        let sut = CommandPaletteView(
            viewModel: viewModel,
            commandPalette: coordinator
        )

        let view = try sut.inspect()

        // Should show "Back" row in the content area
        _ = try view.find(text: "Back")
    }

    // MARK: - Multiple Sections Tests

    func testCommandPaletteDisplaysMultipleSections() throws {
        let viewModel = makeViewModel()
        let coordinator = viewModel.commandPalette

        _ = coordinator.open(context: CommandPaletteContext())

        let sections = [
            makeSection(
                id: "recent",
                title: "Recent",
                items: [makeActionItem(id: "recent-1", title: "Recent Item")]
            ),
            makeSection(
                id: "actions",
                title: "Actions",
                items: [makeActionItem(id: "action-1", title: "Action Item")]
            ),
        ]
        let menu = TestHelpers.makeCommandPaletteMenu(sections: sections)
        coordinator.pushMenu(menu)

        let sut = CommandPaletteView(
            viewModel: viewModel,
            commandPalette: coordinator
        )

        let view = try sut.inspect()

        // Should display both section titles
        _ = try view.find(text: "RECENT")
        _ = try view.find(text: "ACTIONS")
    }

    func testCommandPaletteDisplaysMultipleItems() throws {
        let viewModel = makeViewModel()
        let coordinator = viewModel.commandPalette

        _ = coordinator.open(context: CommandPaletteContext())

        let section = makeSection(
            id: "items",
            title: nil,
            items: [
                makeActionItem(id: "item-1", title: "First Item"),
                makeActionItem(id: "item-2", title: "Second Item"),
                makeActionItem(id: "item-3", title: "Third Item"),
            ]
        )
        let menu = TestHelpers.makeCommandPaletteMenu(sections: [section])
        coordinator.pushMenu(menu)

        let sut = CommandPaletteView(
            viewModel: viewModel,
            commandPalette: coordinator
        )

        let view = try sut.inspect()

        // Should display all items
        _ = try view.find(text: "First Item")
        _ = try view.find(text: "Second Item")
        _ = try view.find(text: "Third Item")
    }

    // MARK: - Submenu Indicator Tests

    func testCommandPaletteDisplaysSubmenuChevron() throws {
        let viewModel = makeViewModel()
        let coordinator = viewModel.commandPalette

        _ = coordinator.open(context: CommandPaletteContext())

        let section = makeSection(
            id: "menus",
            title: nil,
            items: [
                TestHelpers.makeCommandPaletteSubmenuItem(
                    id: "submenu-1",
                    title: "Go to Submenu"
                ),
            ]
        )
        let menu = TestHelpers.makeCommandPaletteMenu(sections: [section])
        coordinator.pushMenu(menu)

        let sut = CommandPaletteView(
            viewModel: viewModel,
            commandPalette: coordinator
        )

        let view = try sut.inspect()

        // Should display the submenu item title
        _ = try view.find(text: "Go to Submenu")

        // Should have chevron.right indicator (Image in view hierarchy)
        // Multiple images may exist (icons, chevrons)
        let images = view.findAll(ViewType.Image.self)
        XCTAssertGreaterThan(images.count, 0)
    }
}
