import XCTest

@testable import LauncherAppKit

final class CommandPaletteStackTests: XCTestCase {
    func testInitialStackIsEmpty() {
        let stack = CommandPaletteStack()
        XCTAssertTrue(stack.stack.isEmpty)
        XCTAssertNil(stack.currentMenu)
        XCTAssertTrue(stack.isAtRoot)
        XCTAssertEqual(stack.depth, 0)
    }

    func testPushAddsToStack() {
        let stack = CommandPaletteStack()
        let menu = CommandPaletteMenu(id: "1", title: "Menu 1", sections: [])

        stack.push(menu)

        XCTAssertEqual(stack.depth, 1)
        XCTAssertEqual(stack.currentMenu?.id, "1")
        XCTAssertTrue(stack.isAtRoot)
    }

    func testPushMultipleMenus() {
        let stack = CommandPaletteStack()
        let menu1 = CommandPaletteMenu(id: "1", title: "Root", sections: [])
        let menu2 = CommandPaletteMenu(id: "2", title: "Submenu", sections: [])

        stack.push(menu1)
        stack.push(menu2)

        XCTAssertEqual(stack.depth, 2)
        XCTAssertEqual(stack.currentMenu?.id, "2")
        XCTAssertFalse(stack.isAtRoot)
    }

    func testPopRemovesFromStack() {
        let stack = CommandPaletteStack()
        let menu1 = CommandPaletteMenu(id: "1", title: "Root", sections: [])
        let menu2 = CommandPaletteMenu(id: "2", title: "Sub", sections: [])

        stack.push(menu1)
        stack.push(menu2)

        let popped = stack.pop()

        XCTAssertTrue(popped)
        XCTAssertEqual(stack.depth, 1)
        XCTAssertEqual(stack.currentMenu?.id, "1")
    }

    func testPopAtRootReturnsFalse() {
        let stack = CommandPaletteStack()
        let menu = CommandPaletteMenu(id: "1", title: "Root", sections: [])

        stack.push(menu)
        let popped = stack.pop()

        XCTAssertFalse(popped)
        XCTAssertEqual(stack.depth, 1)
    }

    func testPopOnEmptyStackReturnsFalse() {
        let stack = CommandPaletteStack()
        let popped = stack.pop()

        XCTAssertFalse(popped)
    }

    func testResetClearsAndSetsRoot() {
        let stack = CommandPaletteStack()
        stack.push(CommandPaletteMenu(id: "old", title: "Old", sections: []))
        stack.push(CommandPaletteMenu(id: "older", title: "Older", sections: []))

        let newRoot = CommandPaletteMenu(id: "new", title: "New Root", sections: [])
        stack.reset(to: newRoot)

        XCTAssertEqual(stack.depth, 1)
        XCTAssertEqual(stack.currentMenu?.id, "new")
        XCTAssertTrue(stack.isAtRoot)
    }

    func testClearEmptiesStack() {
        let stack = CommandPaletteStack()
        stack.push(CommandPaletteMenu(id: "1", title: "Menu", sections: []))

        stack.clear()

        XCTAssertEqual(stack.depth, 0)
        XCTAssertNil(stack.currentMenu)
    }

    func testBreadcrumbReturnsAllTitles() {
        let stack = CommandPaletteStack()
        stack.push(CommandPaletteMenu(id: "1", title: "Root", sections: []))
        stack.push(CommandPaletteMenu(id: "2", title: "Level 1", sections: []))
        stack.push(CommandPaletteMenu(id: "3", title: "Level 2", sections: []))

        XCTAssertEqual(stack.breadcrumb, ["Root", "Level 1", "Level 2"])
    }

    func testIsAtRootTrueWithOneItem() {
        let stack = CommandPaletteStack()
        stack.push(CommandPaletteMenu(id: "1", title: "Root", sections: []))

        XCTAssertTrue(stack.isAtRoot)
    }

    func testIsAtRootFalseWithMultipleItems() {
        let stack = CommandPaletteStack()
        stack.push(CommandPaletteMenu(id: "1", title: "Root", sections: []))
        stack.push(CommandPaletteMenu(id: "2", title: "Sub", sections: []))

        XCTAssertFalse(stack.isAtRoot)
    }
}
