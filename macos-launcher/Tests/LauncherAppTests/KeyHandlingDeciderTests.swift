import AppKit
@testable import LauncherApp
import XCTest

final class KeyHandlingDeciderTests: XCTestCase {
    func testToggleMenuWithCtrlSpace() {
        let input = KeyInput(
            keyCode: 49,
            charactersIgnoringModifiers: " ",
            modifierFlags: [.control]
        )
        XCTAssertEqual(KeyHandlingDecider.action(for: input, showCompletionMenu: false), .toggleMenu)
    }

    func testToggleMenuWithCommandI() {
        let input = KeyInput(
            keyCode: 34,
            charactersIgnoringModifiers: "i",
            modifierFlags: [.command]
        )
        XCTAssertEqual(KeyHandlingDecider.action(for: input, showCompletionMenu: false), .toggleMenu)
    }

    func testAcceptGhostOnTab() {
        let input = KeyInput(
            keyCode: 48,
            charactersIgnoringModifiers: "\t",
            modifierFlags: []
        )
        XCTAssertEqual(KeyHandlingDecider.action(for: input, showCompletionMenu: false), .acceptGhost)
    }

    func testMenuNavigationWhenMenuOpen() {
        let up = KeyInput(keyCode: 126, charactersIgnoringModifiers: nil, modifierFlags: [])
        let down = KeyInput(keyCode: 125, charactersIgnoringModifiers: nil, modifierFlags: [])
        XCTAssertEqual(KeyHandlingDecider.action(for: up, showCompletionMenu: true), .menuNavigate(-1))
        XCTAssertEqual(KeyHandlingDecider.action(for: down, showCompletionMenu: true), .menuNavigate(1))
    }

    func testMenuNavigationWithCtrlPN() {
        let ctrlP = KeyInput(keyCode: 35, charactersIgnoringModifiers: "p", modifierFlags: [.control])
        let ctrlN = KeyInput(keyCode: 45, charactersIgnoringModifiers: "n", modifierFlags: [.control])
        XCTAssertEqual(KeyHandlingDecider.action(for: ctrlP, showCompletionMenu: true), .menuNavigate(-1))
        XCTAssertEqual(KeyHandlingDecider.action(for: ctrlN, showCompletionMenu: true), .menuNavigate(1))
    }

    func testMenuOpenSubmitAndEscape() {
        let enter = KeyInput(keyCode: 36, charactersIgnoringModifiers: "\r", modifierFlags: [])
        let escape = KeyInput(keyCode: 53, charactersIgnoringModifiers: nil, modifierFlags: [])
        XCTAssertEqual(KeyHandlingDecider.action(for: enter, showCompletionMenu: true), .acceptCompletion)
        XCTAssertEqual(KeyHandlingDecider.action(for: escape, showCompletionMenu: true), .escape)
    }

    func testReadlineShortcuts() {
        let optF = KeyInput(keyCode: 3, charactersIgnoringModifiers: "f", modifierFlags: [.option])
        let optB = KeyInput(keyCode: 11, charactersIgnoringModifiers: "b", modifierFlags: [.option])
        let ctrlW = KeyInput(keyCode: 13, charactersIgnoringModifiers: "w", modifierFlags: [.control])
        XCTAssertEqual(KeyHandlingDecider.action(for: optF, showCompletionMenu: false), .moveWordForward)
        XCTAssertEqual(KeyHandlingDecider.action(for: optB, showCompletionMenu: false), .moveWordBackward)
        XCTAssertEqual(KeyHandlingDecider.action(for: ctrlW, showCompletionMenu: false), .deleteWordBackward)
    }

    func testSelectionNavigationWhenMenuClosed() {
        let up = KeyInput(keyCode: 126, charactersIgnoringModifiers: nil, modifierFlags: [])
        let down = KeyInput(keyCode: 125, charactersIgnoringModifiers: nil, modifierFlags: [])
        XCTAssertEqual(KeyHandlingDecider.action(for: up, showCompletionMenu: false), .moveSelection(-1))
        XCTAssertEqual(KeyHandlingDecider.action(for: down, showCompletionMenu: false), .moveSelection(1))
    }

    func testSubmitWhenMenuClosed() {
        let enter = KeyInput(keyCode: 36, charactersIgnoringModifiers: "\r", modifierFlags: [])
        XCTAssertEqual(KeyHandlingDecider.action(for: enter, showCompletionMenu: false), .submit)
    }

    func testNormalModeActions() {
        let enterInsert = KeyInput(keyCode: KeyCode.i, charactersIgnoringModifiers: "i", modifierFlags: [])
        XCTAssertEqual(KeyHandlingDecider.normalModeAction(for: enterInsert), .enterInsertMode)

        let down = KeyInput(keyCode: KeyCode.j, charactersIgnoringModifiers: "j", modifierFlags: [])
        XCTAssertEqual(KeyHandlingDecider.normalModeAction(for: down), .moveSelection(1))

        let up = KeyInput(keyCode: KeyCode.k, charactersIgnoringModifiers: "k", modifierFlags: [])
        XCTAssertEqual(KeyHandlingDecider.normalModeAction(for: up), .moveSelection(-1))

        let ctrlN = KeyInput(keyCode: KeyCode.j, charactersIgnoringModifiers: "n", modifierFlags: [.control])
        XCTAssertEqual(KeyHandlingDecider.normalModeAction(for: ctrlN), .moveSelection(1))

        let ctrlP = KeyInput(keyCode: KeyCode.k, charactersIgnoringModifiers: "p", modifierFlags: [.control])
        XCTAssertEqual(KeyHandlingDecider.normalModeAction(for: ctrlP), .moveSelection(-1))

        let first = KeyInput(keyCode: KeyCode.g, charactersIgnoringModifiers: "g", modifierFlags: [])
        XCTAssertEqual(KeyHandlingDecider.normalModeAction(for: first), .selectFirst)

        let last = KeyInput(keyCode: KeyCode.g, charactersIgnoringModifiers: "G", modifierFlags: [.shift])
        XCTAssertEqual(KeyHandlingDecider.normalModeAction(for: last), .selectLast)

        let activate = KeyInput(keyCode: KeyCode.returnKey, charactersIgnoringModifiers: "\r", modifierFlags: [])
        XCTAssertEqual(KeyHandlingDecider.normalModeAction(for: activate), .activatePrimary)

        let toggle = KeyInput(keyCode: KeyCode.space, charactersIgnoringModifiers: " ", modifierFlags: [])
        XCTAssertEqual(KeyHandlingDecider.normalModeAction(for: toggle), .toggleGroupCollapse)

        let tabKey = KeyInput(keyCode: KeyCode.tab, charactersIgnoringModifiers: "\t", modifierFlags: [])
        XCTAssertEqual(KeyHandlingDecider.normalModeAction(for: tabKey), .toggleWithTab)
    }
}
