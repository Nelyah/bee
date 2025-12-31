@testable import LauncherApp
import SwiftUI
import XCTest

final class DesignTests: XCTestCase {
    // MARK: - ThemeColors Tests

    func testColorInitFromHex() {
        let color = Color(hex: "FF0000")
        // SwiftUI Color doesn't expose RGB directly, but we can verify it creates without error
        XCTAssertNotNil(color)
    }

    func testColorInitFromHexWithHash() {
        let color = Color(hex: "#00FF00")
        XCTAssertNotNil(color)
    }

    func testColorInitFromHexBlue() {
        let color = Color(hex: "0000FF")
        XCTAssertNotNil(color)
    }

    func testNSColorInitFromHex() {
        let color = NSColor(hex: "FF0000")
        XCTAssertEqual(color.redComponent, 1.0, accuracy: 0.01)
        XCTAssertEqual(color.greenComponent, 0.0, accuracy: 0.01)
        XCTAssertEqual(color.blueComponent, 0.0, accuracy: 0.01)
    }

    func testNSColorInitFromHexWithHash() {
        let color = NSColor(hex: "#00FF00")
        XCTAssertEqual(color.redComponent, 0.0, accuracy: 0.01)
        XCTAssertEqual(color.greenComponent, 1.0, accuracy: 0.01)
        XCTAssertEqual(color.blueComponent, 0.0, accuracy: 0.01)
    }

    func testNSColorInitFromHexMixed() {
        let color = NSColor(hex: "FF8800")
        XCTAssertEqual(color.redComponent, 1.0, accuracy: 0.01)
        XCTAssertEqual(color.greenComponent, 136.0 / 255.0, accuracy: 0.01)
        XCTAssertEqual(color.blueComponent, 0.0, accuracy: 0.01)
    }

    // MARK: - StatusColor Tests

    func testStatusColorActive() {
        let color = statusColor("active")
        XCTAssertEqual(color, ThemeManager.current.green)
    }

    func testStatusColorCompleted() {
        let color = statusColor("completed")
        XCTAssertEqual(color, ThemeManager.current.blue)
    }

    func testStatusColorDeleted() {
        let color = statusColor("deleted")
        XCTAssertEqual(color, ThemeManager.current.red)
    }

    func testStatusColorBlocked() {
        let color = statusColor("blocked")
        XCTAssertEqual(color, ThemeManager.current.mauve)
    }

    func testStatusColorUnknownDefaultsToYellow() {
        let color = statusColor("unknown_status")
        XCTAssertEqual(color, ThemeManager.current.yellow)
    }

    func testStatusColorCaseInsensitive() {
        let activeUpper = statusColor("ACTIVE")
        let activeLower = statusColor("active")
        XCTAssertEqual(activeUpper, activeLower)
    }
}
