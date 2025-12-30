import XCTest
@testable import LauncherApp

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

    private func enterLabel(in context: InteractionContext) -> String? {
        let model = BottomHintModelBuilder.model(for: context)
        return model.right.first(where: { $0.key == "Enter" })?.label
    }

    private func sampleRows() -> [GroupedListRow] {
        let header = GroupHeader(key: "project", displayName: "Project", isCollapsed: false)
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
            .task(GroupedTask(task: task, flatIndex: 0))
        ]
    }
}
