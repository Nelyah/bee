@testable import LauncherApp
import XCTest

final class CommandPaletteModelsTests: XCTestCase {
    // MARK: - CommandPaletteIcon Tests

    func testCommandPaletteIconEquality() {
        XCTAssertEqual(CommandPaletteIcon.system("star"), CommandPaletteIcon.system("star"))
        XCTAssertNotEqual(CommandPaletteIcon.system("star"), CommandPaletteIcon.system("circle"))
        XCTAssertEqual(CommandPaletteIcon.asset("custom"), CommandPaletteIcon.asset("custom"))
        XCTAssertEqual(CommandPaletteIcon.gitlab, CommandPaletteIcon.gitlab)
        XCTAssertEqual(CommandPaletteIcon.jira, CommandPaletteIcon.jira)
        XCTAssertNotEqual(CommandPaletteIcon.gitlab, CommandPaletteIcon.jira)
    }

    // MARK: - CommandPaletteItem Tests

    func testCommandPaletteItemActionId() {
        let action = CommandPaletteActionItem(
            id: "test-action",
            title: "Test Action"
        ) {}
        let item = CommandPaletteItem.action(action)
        XCTAssertEqual(item.id, "action-test-action")
    }

    func testCommandPaletteItemSubmenuId() {
        let submenu = CommandPaletteSubmenuItem(
            id: "test-submenu",
            title: "Test Submenu"
        ) { CommandPaletteMenu(title: "Test", sections: []) }
        let item = CommandPaletteItem.submenu(submenu)
        XCTAssertEqual(item.id, "submenu-test-submenu")
    }

    func testCommandPaletteItemSuggestionId() {
        let suggestion = CommandPaletteSuggestionItem(
            id: "test-suggestion",
            title: "Test Suggestion",
            metadata: .rawInput("test")
        ) {}
        let item = CommandPaletteItem.suggestion(suggestion)
        XCTAssertEqual(item.id, "suggestion-test-suggestion")
    }

    func testCommandPaletteItemShortcutId() {
        let shortcut = CommandPaletteShortcutItem(
            id: "test-shortcut",
            title: "Test Shortcut",
            keys: "Cmd+K"
        )
        let item = CommandPaletteItem.shortcut(shortcut)
        XCTAssertEqual(item.id, "shortcut-test-shortcut")
    }

    func testCommandPaletteItemDisplayTitle() {
        let action = CommandPaletteActionItem(id: "id", title: "Action Title") {}
        let submenu = CommandPaletteSubmenuItem(id: "id", title: "Submenu Title") {
            CommandPaletteMenu(title: "Test", sections: [])
        }
        let suggestion = CommandPaletteSuggestionItem(
            id: "id",
            title: "Suggestion Title",
            metadata: .rawInput("test")
        ) {}
        let shortcut = CommandPaletteShortcutItem(id: "id", title: "Shortcut Title", keys: "Esc")

        XCTAssertEqual(CommandPaletteItem.action(action).displayTitle, "Action Title")
        XCTAssertEqual(CommandPaletteItem.submenu(submenu).displayTitle, "Submenu Title")
        XCTAssertEqual(CommandPaletteItem.suggestion(suggestion).displayTitle, "Suggestion Title")
        XCTAssertEqual(CommandPaletteItem.shortcut(shortcut).displayTitle, "Shortcut Title")
    }

    func testCommandPaletteItemSubtitle() {
        let actionWithSubtitle = CommandPaletteActionItem(
            id: "id",
            title: "Title",
            subtitle: "Action Subtitle"
        ) {}
        let actionWithoutSubtitle = CommandPaletteActionItem(id: "id", title: "Title") {}
        let shortcut = CommandPaletteShortcutItem(id: "id", title: "Title", keys: "Esc")

        XCTAssertEqual(CommandPaletteItem.action(actionWithSubtitle).subtitle, "Action Subtitle")
        XCTAssertNil(CommandPaletteItem.action(actionWithoutSubtitle).subtitle)
        XCTAssertNil(CommandPaletteItem.shortcut(shortcut).subtitle)
    }

    func testCommandPaletteItemIcon() {
        let actionWithIcon = CommandPaletteActionItem(
            id: "id",
            title: "Title",
            icon: .system("star")
        ) {}
        let actionWithoutIcon = CommandPaletteActionItem(id: "id", title: "Title") {}
        let shortcut = CommandPaletteShortcutItem(id: "id", title: "Title", keys: "Esc")

        XCTAssertEqual(CommandPaletteItem.action(actionWithIcon).icon, .system("star"))
        XCTAssertNil(CommandPaletteItem.action(actionWithoutIcon).icon)
        XCTAssertNil(CommandPaletteItem.shortcut(shortcut).icon)
    }

    func testCommandPaletteItemIsSelectable() {
        let action = CommandPaletteActionItem(id: "id", title: "Title") {}
        let submenu = CommandPaletteSubmenuItem(id: "id", title: "Title") {
            CommandPaletteMenu(title: "Test", sections: [])
        }
        let suggestion = CommandPaletteSuggestionItem(
            id: "id",
            title: "Title",
            metadata: .rawInput("test")
        ) {}
        let shortcut = CommandPaletteShortcutItem(id: "id", title: "Title", keys: "Esc")

        XCTAssertTrue(CommandPaletteItem.action(action).isSelectable)
        XCTAssertTrue(CommandPaletteItem.submenu(submenu).isSelectable)
        XCTAssertTrue(CommandPaletteItem.suggestion(suggestion).isSelectable)
        XCTAssertFalse(CommandPaletteItem.shortcut(shortcut).isSelectable)
    }

    // MARK: - CommandPaletteSection Tests

    func testCommandPaletteSectionInitWithDefaultId() {
        let section = CommandPaletteSection(title: "Test", items: [])
        XCTAssertFalse(section.id.isEmpty)
        XCTAssertEqual(section.title, "Test")
        XCTAssertTrue(section.items.isEmpty)
    }

    func testCommandPaletteSectionInitWithCustomId() {
        let section = CommandPaletteSection(id: "custom-id", title: "Test", items: [])
        XCTAssertEqual(section.id, "custom-id")
    }

    // MARK: - CommandPaletteMenu Tests

    func testCommandPaletteMenuSelectableItems() {
        let action = CommandPaletteActionItem(id: "action", title: "Action") {}
        let shortcut = CommandPaletteShortcutItem(id: "shortcut", title: "Shortcut", keys: "Esc")
        let section = CommandPaletteSection(
            title: "Test",
            items: [.action(action), .shortcut(shortcut)]
        )
        let menu = CommandPaletteMenu(title: "Menu", sections: [section])

        XCTAssertEqual(menu.selectableItems.count, 1)
        XCTAssertEqual(menu.selectableItems.first?.id, "action-action")
    }

    func testCommandPaletteMenuSelectableItemsAcrossSections() {
        let action1 = CommandPaletteActionItem(id: "action1", title: "Action 1") {}
        let action2 = CommandPaletteActionItem(id: "action2", title: "Action 2") {}
        let section1 = CommandPaletteSection(title: "Section 1", items: [.action(action1)])
        let section2 = CommandPaletteSection(title: "Section 2", items: [.action(action2)])
        let menu = CommandPaletteMenu(title: "Menu", sections: [section1, section2])

        XCTAssertEqual(menu.selectableItems.count, 2)
    }

    // MARK: - CommandPaletteContext Tests

    func testCommandPaletteContextInitWithDefaults() {
        let context = CommandPaletteContext()
        XCTAssertFalse(context.hasSelectedTask)
        XCTAssertNil(context.selectedTaskUUID)
        XCTAssertNil(context.currentReportName)
        XCTAssertTrue(context.availableReports.isEmpty)
        XCTAssertTrue(context.projects.isEmpty)
        XCTAssertTrue(context.tags.isEmpty)
        XCTAssertNil(context.currentProjectScope)
    }

    func testCommandPaletteContextInitWithValues() {
        let report = ReportSummary(
            name: "active",
            columns: ["id"],
            columnNames: ["ID"],
            isDefault: true
        )
        let context = CommandPaletteContext(
            hasSelectedTask: true,
            selectedTaskUUID: "uuid-123",
            currentReportName: "active",
            availableReports: [report],
            projects: ["project1"],
            tags: ["tag1"],
            currentProjectScope: "project1"
        )

        XCTAssertTrue(context.hasSelectedTask)
        XCTAssertEqual(context.selectedTaskUUID, "uuid-123")
        XCTAssertEqual(context.currentReportName, "active")
        XCTAssertEqual(context.availableReports.count, 1)
        XCTAssertEqual(context.projects, ["project1"])
        XCTAssertEqual(context.tags, ["tag1"])
        XCTAssertEqual(context.currentProjectScope, "project1")
    }
}
