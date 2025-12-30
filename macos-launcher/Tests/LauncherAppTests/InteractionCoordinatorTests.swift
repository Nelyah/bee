import XCTest
@testable import LauncherApp

final class InteractionCoordinatorTests: XCTestCase {
    func testEscapeActionPrefersCommandPalette() {
        let action = InteractionCoordinator.escapeAction(
            isCommandPalettePresented: true,
            showCompletionMenu: true,
            mode: .detail
        )
        XCTAssertEqual(action, .closeCommandPalette)
    }

    func testEscapeActionFallsBackToCompletion() {
        let action = InteractionCoordinator.escapeAction(
            isCommandPalettePresented: false,
            showCompletionMenu: true,
            mode: .detail
        )
        XCTAssertEqual(action, .clearCompletions)
    }

    func testEscapeActionFallsBackToDetail() {
        let action = InteractionCoordinator.escapeAction(
            isCommandPalettePresented: false,
            showCompletionMenu: false,
            mode: .detail
        )
        XCTAssertEqual(action, .closeDetail)
    }

    func testEscapeActionExitsInsertModeByDefault() {
        let action = InteractionCoordinator.escapeAction(
            isCommandPalettePresented: false,
            showCompletionMenu: false,
            mode: .list
        )
        XCTAssertEqual(action, .exitInsertMode)
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
}
