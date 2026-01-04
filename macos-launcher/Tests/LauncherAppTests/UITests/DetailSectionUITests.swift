@testable import LauncherApp
import SwiftUI
import ViewInspector
import XCTest

/// UI tests for DetailSection and DetailSectionWithAction using ViewInspector.
///
/// These tests verify the section layout, title display, and action button behavior.
final class DetailSectionUITests: XCTestCase {
    // MARK: - DetailSection Tests

    func testDetailSectionDisplaysTitle() throws {
        let sut = DetailSection(title: "Test Section") {
            Text("Content")
        }

        let view = try sut.inspect()

        // Title should be uppercased
        _ = try view.find(text: "TEST SECTION")
    }

    func testDetailSectionDisplaysContent() throws {
        let sut = DetailSection(title: "Section") {
            Text("Hello World")
        }

        let view = try sut.inspect()

        _ = try view.find(text: "Hello World")
    }

    func testDetailSectionDisplaysMultipleContentItems() throws {
        let sut = DetailSection(title: "Items") {
            Text("Item 1")
            Text("Item 2")
            Text("Item 3")
        }

        let view = try sut.inspect()

        _ = try view.find(text: "Item 1")
        _ = try view.find(text: "Item 2")
        _ = try view.find(text: "Item 3")
    }

    func testDetailSectionWithEmptyTitle() throws {
        let sut = DetailSection(title: "") {
            Text("Content")
        }

        let view = try sut.inspect()

        // Should still render content
        _ = try view.find(text: "Content")
    }

    func testDetailSectionWithLongTitle() throws {
        let longTitle = "This is a very long section title that might wrap"
        let sut = DetailSection(title: longTitle) {
            Text("Content")
        }

        let view = try sut.inspect()

        _ = try view.find(text: longTitle.uppercased())
    }

    func testDetailSectionContainsVStack() throws {
        let sut = DetailSection(title: "Test") {
            Text("Content")
        }

        let view = try sut.inspect()

        // Verify the view contains a VStack for layout
        _ = try view.find(ViewType.VStack.self)
    }

    func testDetailSectionWithComplexContent() throws {
        let sut = DetailSection(title: "Complex") {
            VStack {
                HStack {
                    Text("Label:")
                    Text("Value")
                }
                Divider()
                Text("Additional info")
            }
        }

        let view = try sut.inspect()

        _ = try view.find(text: "COMPLEX")
        _ = try view.find(text: "Label:")
        _ = try view.find(text: "Value")
    }
}

// MARK: - DetailSectionWithAction Tests

final class DetailSectionWithActionUITests: XCTestCase {
    func testDisplaysTitle() throws {
        let sut = DetailSectionWithAction(
            title: "Actions",
            actionLabel: "Add",
            actionIcon: "plus",
            onAction: {}
        ) {
            Text("Content")
        }

        let view = try sut.inspect()

        _ = try view.find(text: "ACTIONS")
    }

    func testDisplaysContent() throws {
        let sut = DetailSectionWithAction(
            title: "Section",
            actionLabel: "Add",
            actionIcon: "plus",
            onAction: {}
        ) {
            Text("Section Content")
        }

        let view = try sut.inspect()

        _ = try view.find(text: "Section Content")
    }

    func testDisplaysActionLabel() throws {
        let sut = DetailSectionWithAction(
            title: "Section",
            actionLabel: "Add New",
            actionIcon: "plus.circle",
            onAction: {}
        ) {
            Text("Content")
        }

        let view = try sut.inspect()

        _ = try view.find(text: "Add New")
    }

    func testContainsButton() throws {
        let sut = DetailSectionWithAction(
            title: "Section",
            actionLabel: "Add",
            actionIcon: "plus",
            onAction: {}
        ) {
            Text("Content")
        }

        let view = try sut.inspect()

        _ = try view.find(ViewType.Button.self)
    }

    func testButtonTriggersAction() throws {
        var actionTriggered = false
        let sut = DetailSectionWithAction(
            title: "Section",
            actionLabel: "Add",
            actionIcon: "plus",
            onAction: { actionTriggered = true }
        ) {
            Text("Content")
        }

        let view = try sut.inspect()
        let button = try view.find(ViewType.Button.self)
        try button.tap()

        XCTAssertTrue(actionTriggered)
    }

    func testContainsActionIcon() throws {
        let sut = DetailSectionWithAction(
            title: "Section",
            actionLabel: "Add",
            actionIcon: "plus.circle",
            onAction: {}
        ) {
            Text("Content")
        }

        let view = try sut.inspect()

        // Should contain an Image for the icon
        _ = try view.find(ViewType.Image.self)
    }

    func testMultipleContentItems() throws {
        let sut = DetailSectionWithAction(
            title: "Items",
            actionLabel: "Add",
            actionIcon: "plus",
            onAction: {}
        ) {
            Text("Item A")
            Text("Item B")
        }

        let view = try sut.inspect()

        _ = try view.find(text: "Item A")
        _ = try view.find(text: "Item B")
    }

    func testEmptyActionLabel() throws {
        let sut = DetailSectionWithAction(
            title: "Section",
            actionLabel: "",
            actionIcon: "plus",
            onAction: {}
        ) {
            Text("Content")
        }

        let view = try sut.inspect()

        // Should still render without crashing
        _ = try view.find(text: "SECTION")
    }

    func testContainsVStackLayout() throws {
        let sut = DetailSectionWithAction(
            title: "Test",
            actionLabel: "Add",
            actionIcon: "plus",
            onAction: {}
        ) {
            Text("Content")
        }

        let view = try sut.inspect()

        _ = try view.find(ViewType.VStack.self)
    }

    func testLongActionLabel() throws {
        let sut = DetailSectionWithAction(
            title: "Section",
            actionLabel: "Add a New Item to the List",
            actionIcon: "plus",
            onAction: {}
        ) {
            Text("Content")
        }

        let view = try sut.inspect()

        _ = try view.find(text: "Add a New Item to the List")
    }
}
