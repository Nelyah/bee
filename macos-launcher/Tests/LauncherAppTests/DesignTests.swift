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

    // MARK: - DesignTokens Tests

    func testSpacingValuesArePositive() {
        XCTAssertGreaterThan(DesignTokens.Spacing.extraSmall, 0)
        XCTAssertGreaterThan(DesignTokens.Spacing.small, 0)
        XCTAssertGreaterThan(DesignTokens.Spacing.medium, 0)
        XCTAssertGreaterThan(DesignTokens.Spacing.large, 0)
        XCTAssertGreaterThan(DesignTokens.Spacing.extraLarge, 0)
        XCTAssertGreaterThan(DesignTokens.Spacing.extraExtraLarge, 0)
    }

    func testSpacingValuesAreOrdered() {
        XCTAssertLessThan(DesignTokens.Spacing.extraSmall, DesignTokens.Spacing.small)
        XCTAssertLessThan(DesignTokens.Spacing.small, DesignTokens.Spacing.medium)
        XCTAssertLessThan(DesignTokens.Spacing.medium, DesignTokens.Spacing.large)
        XCTAssertLessThan(DesignTokens.Spacing.large, DesignTokens.Spacing.extraLarge)
        XCTAssertLessThan(DesignTokens.Spacing.extraLarge, DesignTokens.Spacing.extraExtraLarge)
    }

    func testRadiusValuesArePositive() {
        XCTAssertGreaterThan(DesignTokens.Radius.small, 0)
        XCTAssertGreaterThan(DesignTokens.Radius.medium, 0)
        XCTAssertGreaterThan(DesignTokens.Radius.large, 0)
        XCTAssertGreaterThan(DesignTokens.Radius.extraLarge, 0)
    }

    func testRadiusValuesAreOrdered() {
        XCTAssertLessThan(DesignTokens.Radius.small, DesignTokens.Radius.medium)
        XCTAssertLessThan(DesignTokens.Radius.medium, DesignTokens.Radius.large)
        XCTAssertLessThan(DesignTokens.Radius.large, DesignTokens.Radius.extraLarge)
    }

    func testTypeScaleValuesArePositive() {
        XCTAssertGreaterThan(DesignTokens.TypeScale.caption, 0)
        XCTAssertGreaterThan(DesignTokens.TypeScale.label, 0)
        XCTAssertGreaterThan(DesignTokens.TypeScale.bodySm, 0)
        XCTAssertGreaterThan(DesignTokens.TypeScale.body, 0)
        XCTAssertGreaterThan(DesignTokens.TypeScale.bodyLg, 0)
        XCTAssertGreaterThan(DesignTokens.TypeScale.title, 0)
        XCTAssertGreaterThan(DesignTokens.TypeScale.input, 0)
    }

    func testTypeScaleCaptionIsSmallest() {
        XCTAssertLessThan(DesignTokens.TypeScale.caption, DesignTokens.TypeScale.label)
        XCTAssertLessThan(DesignTokens.TypeScale.label, DesignTokens.TypeScale.bodySm)
        XCTAssertLessThan(DesignTokens.TypeScale.bodySm, DesignTokens.TypeScale.body)
    }

    func testTypeScaleTitleIsLarge() {
        XCTAssertGreaterThan(DesignTokens.TypeScale.title, DesignTokens.TypeScale.body)
    }

    // MARK: - ThemeManager Tests

    func testThemeManagerCurrentIsNotNil() {
        XCTAssertNotNil(ThemeManager.current)
    }

    func testThemeManagerAvailableContainsThemes() {
        XCTAssertFalse(ThemeManager.available.isEmpty)
        XCTAssertGreaterThanOrEqual(ThemeManager.available.count, 2)
    }

    func testThemeManagerAvailableThemesHaveAllColors() {
        for theme in ThemeManager.available {
            // Verify all theme colors are accessible (would crash if nil)
            _ = theme.base
            _ = theme.mantle
            _ = theme.crust
            _ = theme.surface0
            _ = theme.surface1
            _ = theme.surface2
            _ = theme.text
            _ = theme.subtext0
            _ = theme.subtext1
            _ = theme.overlay0
            _ = theme.red
            _ = theme.green
            _ = theme.blue
            _ = theme.yellow
            _ = theme.mauve
            _ = theme.teal
            _ = theme.peach
            _ = theme.lavender
            _ = theme.pink
            _ = theme.sky
            _ = theme.rosewater
            _ = theme.flamingo
        }
    }

    func testOneDarkThemeColors() {
        let theme = OneDarkTheme()
        XCTAssertNotNil(theme.base)
        XCTAssertNotNil(theme.text)
        XCTAssertNotNil(theme.name)
    }

    func testCatppuccinThemeColors() {
        let theme = CatppuccinTheme()
        XCTAssertNotNil(theme.base)
        XCTAssertNotNil(theme.text)
        XCTAssertNotNil(theme.name)
    }
}
