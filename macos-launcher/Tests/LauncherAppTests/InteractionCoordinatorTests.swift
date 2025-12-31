@testable import LauncherApp
import XCTest

final class InteractionCoordinatorTests: XCTestCase {
    func testEscapeActionForCommandPalette() {
        let action = InteractionCoordinator.escapeAction(for: .commandPalette)
        XCTAssertEqual(action, .closeCommandPalette)
    }

    func testEscapeActionForCompletionMenu() {
        let action = InteractionCoordinator.escapeAction(
            for: .completionMenu(selection: .task, isInsertMode: true)
        )
        XCTAssertEqual(action, .clearCompletions)
    }

    func testEscapeActionForDetail() {
        let action = InteractionCoordinator.escapeAction(for: .detail)
        XCTAssertEqual(action, .closeDetail)
    }

    func testEscapeActionForInsertModeList() {
        let action = InteractionCoordinator.escapeAction(
            for: .list(selection: .none, isInsertMode: true)
        )
        XCTAssertEqual(action, .exitInsertMode)
    }

    func testEscapeActionForNormalModeList() {
        let action = InteractionCoordinator.escapeAction(
            for: .list(selection: .none, isInsertMode: false)
        )
        XCTAssertEqual(action, .closeWindow)
    }

    func testNormalModeEffectActivatesPrimaryUsesToggleWhenAvailable() {
        let effect = InteractionCoordinator.normalModeEffect(
            action: .activatePrimary,
            canToggleGroupCollapse: true
        )
        XCTAssertEqual(effect, .toggleGroupCollapse)
    }

    func testNormalModeEffectActivatesPrimaryOpensDetailWhenNoHeader() {
        let effect = InteractionCoordinator.normalModeEffect(
            action: .activatePrimary,
            canToggleGroupCollapse: false
        )
        XCTAssertEqual(effect, .openDetail)
    }

    func testToggleWithTabCollapsesHeaderWhenOnHeader() {
        let effect = InteractionCoordinator.normalModeEffect(
            action: .toggleWithTab,
            canToggleGroupCollapse: true
        )
        XCTAssertEqual(effect, .toggleGroupCollapse)
    }

    func testToggleWithTabExpandsTaskWhenOnTask() {
        let effect = InteractionCoordinator.normalModeEffect(
            action: .toggleWithTab,
            canToggleGroupCollapse: false
        )
        XCTAssertEqual(effect, .toggleTaskExpansion)
    }
}
