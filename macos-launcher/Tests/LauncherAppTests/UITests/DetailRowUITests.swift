@testable import LauncherAppKit
import SwiftUI
import ViewInspector
import XCTest

/// UI tests for DetailRow and CopyableDetailRow using ViewInspector.
///
/// These tests verify the view's structure, content display, and accessibility behavior.
final class DetailRowUITests: XCTestCase {
    // MARK: - DetailRow Tests

    func testDetailRowDisplaysLabel() throws {
        let sut = DetailRow(label: "Project", value: "bee", helpText: nil)

        let view = try sut.inspect()

        _ = try view.find(text: "PROJECT")
    }

    func testDetailRowDisplaysValue() throws {
        let sut = DetailRow(label: "Project", value: "bee", helpText: nil)

        let view = try sut.inspect()

        _ = try view.find(text: "bee")
    }

    // MARK: - CopyableDetailRow Tests

    func testCopyableDetailRowDisplaysLabel() throws {
        let sut = CopyableDetailRow(
            label: "UUID",
            value: "...12345678",
            fullValue: "abc-def-12345678",
            onCopy: { _ in }
        )

        let view = try sut.inspect()

        _ = try view.find(text: "UUID")
    }

    func testCopyableDetailRowDisplaysValue() throws {
        let sut = CopyableDetailRow(
            label: "UUID",
            value: "...12345678",
            fullValue: "abc-def-12345678",
            onCopy: { _ in }
        )

        let view = try sut.inspect()

        _ = try view.find(text: "...12345678")
    }

    func testCopyableDetailRowContainsButton() throws {
        let sut = CopyableDetailRow(
            label: "UUID",
            value: "...12345678",
            fullValue: "abc-def-12345678",
            onCopy: { _ in }
        )

        let view = try sut.inspect()

        // Verify the view contains a Button (for keyboard accessibility)
        _ = try view.find(ViewType.Button.self)
    }

    func testCopyableDetailRowButtonCallsOnCopy() throws {
        var copiedValue: String?
        let sut = CopyableDetailRow(
            label: "UUID",
            value: "...12345678",
            fullValue: "abc-def-12345678",
            onCopy: { value in copiedValue = value }
        )

        let view = try sut.inspect()
        let button = try view.find(ViewType.Button.self)
        try button.tap()

        XCTAssertEqual(copiedValue, "abc-def-12345678")
    }

    func testCopyableDetailRowHasAccessibilityLabel() throws {
        let sut = CopyableDetailRow(
            label: "UUID",
            value: "...12345678",
            fullValue: "abc-def-12345678",
            onCopy: { _ in }
        )

        let view = try sut.inspect()
        let button = try view.find(ViewType.Button.self)

        // Verify the button has an accessibility label
        let label = try button.accessibilityLabel().string()
        XCTAssertEqual(label, "Copy UUID")
    }

    func testCopyableDetailRowHasAccessibilityHint() throws {
        let sut = CopyableDetailRow(
            label: "UUID",
            value: "...12345678",
            fullValue: "abc-def-12345678",
            onCopy: { _ in }
        )

        let view = try sut.inspect()
        let button = try view.find(ViewType.Button.self)

        // Verify the button has an accessibility hint
        let hint = try button.accessibilityHint().string()
        XCTAssertEqual(hint, "Copies abc-def-12345678 to clipboard")
    }
}
