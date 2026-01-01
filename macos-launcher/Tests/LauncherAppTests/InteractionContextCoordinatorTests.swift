@testable import LauncherApp
import XCTest

final class InteractionContextCoordinatorTests: XCTestCase {
    func testBaseContextUsesHeaderSelection() {
        let rows = sampleRows()
        let base = InteractionContextCoordinator.baseContext(
            mode: .list,
            selectedRowIndex: 0,
            rows: rows
        )
        XCTAssertEqual(base, .list(selection: .groupHeader))
    }

    func testBaseContextUsesTaskSelection() {
        let rows = sampleRows()
        let base = InteractionContextCoordinator.baseContext(
            mode: .list,
            selectedRowIndex: 1,
            rows: rows
        )
        XCTAssertEqual(base, .list(selection: .task))
    }

    func testEnterLabelForGroupHeader() {
        let context = InteractionContextCoordinator.interactionContext(
            base: .list(selection: .groupHeader),
            showCompletionMenu: false,
            commandPalettePresented: false,
            isInsertMode: true
        )
        XCTAssertEqual(enterLabel(in: context), "Toggle fold")
    }

    func testEnterLabelForTask() {
        let context = InteractionContextCoordinator.interactionContext(
            base: .list(selection: .task),
            showCompletionMenu: false,
            commandPalettePresented: false,
            isInsertMode: true
        )
        XCTAssertEqual(enterLabel(in: context), "Open task")
    }

    func testEnterLabelForNoSelection() {
        let context = InteractionContextCoordinator.interactionContext(
            base: .list(selection: .none),
            showCompletionMenu: false,
            commandPalettePresented: false,
            isInsertMode: true
        )
        XCTAssertEqual(enterLabel(in: context), "Run action")
    }

    func testEnterLabelForCompletionMenu() {
        let context = InteractionContextCoordinator.interactionContext(
            base: .list(selection: .task),
            showCompletionMenu: true,
            commandPalettePresented: false,
            isInsertMode: true
        )
        XCTAssertEqual(enterLabel(in: context), "Accept suggestion")
    }

    func testEnterLabelForCommandPalette() {
        let context = InteractionContextCoordinator.interactionContext(
            base: .list(selection: .task),
            showCompletionMenu: false,
            commandPalettePresented: true,
            isInsertMode: true
        )
        XCTAssertEqual(enterLabel(in: context), "Select")
    }

    func testLeftHintsForNormalModeIncludeInsert() {
        let context = InteractionContextCoordinator.interactionContext(
            base: .list(selection: .task),
            showCompletionMenu: false,
            commandPalettePresented: false,
            isInsertMode: false
        )
        let model = BottomHintModelBuilder.model(for: context)
        XCTAssertEqual(model.left.first?.label, "Close")
        XCTAssertTrue(model.left.contains { $0.key == "i" && $0.label == "Insert" })
    }

    func testLeftHintsForInsertModeExcludeInsert() {
        let context = InteractionContextCoordinator.interactionContext(
            base: .list(selection: .task),
            showCompletionMenu: false,
            commandPalettePresented: false,
            isInsertMode: true
        )
        let model = BottomHintModelBuilder.model(for: context)
        XCTAssertEqual(model.left.first?.label, "Exit insert")
        XCTAssertFalse(model.left.contains { $0.key == "i" })
    }

    func testTabHintForTaskInNormalMode() {
        let context = InteractionContextCoordinator.interactionContext(
            base: .list(selection: .task),
            showCompletionMenu: false,
            commandPalettePresented: false,
            isInsertMode: false
        )
        let model = BottomHintModelBuilder.model(for: context)
        XCTAssertTrue(model.right.contains { $0.key == "Tab" && $0.label == "Expand" })
    }

    func testTabHintForHeaderInNormalMode() {
        let context = InteractionContextCoordinator.interactionContext(
            base: .list(selection: .groupHeader),
            showCompletionMenu: false,
            commandPalettePresented: false,
            isInsertMode: false
        )
        let model = BottomHintModelBuilder.model(for: context)
        XCTAssertTrue(model.right.contains { $0.key == "Tab" && $0.label == "Collapse" })
    }

    func testNoTabHintForTaskInInsertMode() {
        let context = InteractionContextCoordinator.interactionContext(
            base: .list(selection: .task),
            showCompletionMenu: false,
            commandPalettePresented: false,
            isInsertMode: true
        )
        let model = BottomHintModelBuilder.model(for: context)
        XCTAssertFalse(model.right.contains { $0.key == "Tab" })
    }

    func testNoTabHintForNoSelection() {
        let context = InteractionContextCoordinator.interactionContext(
            base: .list(selection: .none),
            showCompletionMenu: false,
            commandPalettePresented: false,
            isInsertMode: false
        )
        let model = BottomHintModelBuilder.model(for: context)
        XCTAssertFalse(model.right.contains { $0.key == "Tab" })
    }

    // MARK: - Detail Mode Hints

    func testDetailModeLeftHintsShowEscapeBack() {
        let context = InteractionContextCoordinator.interactionContext(
            base: .detail,
            showCompletionMenu: false,
            commandPalettePresented: false,
            isInsertMode: false
        )
        let model = BottomHintModelBuilder.model(for: context)
        XCTAssertEqual(model.left.first?.key, "Esc")
        XCTAssertEqual(model.left.first?.label, "Back")
    }

    func testDetailModeLeftHintsShowNavigate() {
        let context = InteractionContextCoordinator.interactionContext(
            base: .detail,
            showCompletionMenu: false,
            commandPalettePresented: false,
            isInsertMode: false
        )
        let model = BottomHintModelBuilder.model(for: context)
        XCTAssertTrue(model.left.contains { $0.key == "j/k" && $0.label == "Navigate" })
    }

    func testDetailModeRightHintsShowOpenAndCopy() {
        let context = InteractionContextCoordinator.interactionContext(
            base: .detail,
            showCompletionMenu: false,
            commandPalettePresented: false,
            isInsertMode: false
        )
        let model = BottomHintModelBuilder.model(for: context)
        XCTAssertTrue(model.right.contains { $0.key == "o" && $0.label == "Open" })
        XCTAssertTrue(model.right.contains { $0.key == "y" && $0.label == "Copy" })
    }

    func testDetailModeRightHintsShowCommandMenu() {
        let context = InteractionContextCoordinator.interactionContext(
            base: .detail,
            showCompletionMenu: false,
            commandPalettePresented: false,
            isInsertMode: false
        )
        let model = BottomHintModelBuilder.model(for: context)
        XCTAssertTrue(model.right.contains { $0.key == "⌘K" && $0.label == "Command menu" })
    }

    func testDetailModeNoEnterHint() {
        let context = InteractionContextCoordinator.interactionContext(
            base: .detail,
            showCompletionMenu: false,
            commandPalettePresented: false,
            isInsertMode: false
        )
        let model = BottomHintModelBuilder.model(for: context)
        XCTAssertFalse(model.right.contains { $0.key == "Enter" })
    }

    func testDetailModeNoInsertHint() {
        let context = InteractionContextCoordinator.interactionContext(
            base: .detail,
            showCompletionMenu: false,
            commandPalettePresented: false,
            isInsertMode: false
        )
        let model = BottomHintModelBuilder.model(for: context)
        XCTAssertFalse(model.left.contains { $0.key == "i" })
    }

    func testBaseContextForDetailMode() {
        let rows = sampleRows()
        let base = InteractionContextCoordinator.baseContext(
            mode: .detail,
            selectedRowIndex: 0,
            rows: rows
        )
        XCTAssertEqual(base, .detail)
    }

    private func enterLabel(in context: InteractionContext) -> String? {
        let model = BottomHintModelBuilder.model(for: context)
        return model.right.first(where: { $0.key == "Enter" })?.label
    }

    private func sampleRows() -> [GroupedListRow] {
        let header = GroupHeader(key: "project", displayName: "Project", taskCount: 1, isCollapsed: false)
        let task = ApiTask(
            dbId: 1,
            uuid: "task-1",
            status: "pending",
            summary: "Sample",
            project: "project",
            tags: [],
            dateCreated: "2025-01-01T00:00:00Z",
            dateCompleted: nil,
            dateDue: nil,
            urgency: nil
        )
        return [
            .header(header),
            .task(GroupedTask(task: task, flatIndex: 0, groupKey: "project")),
        ]
    }
}
