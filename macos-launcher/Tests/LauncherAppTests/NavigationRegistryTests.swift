import Foundation
@testable import LauncherApp
import XCTest

/// Tests for the coordinate-based NavigationRegistry.
///
/// These tests verify:
/// - Registration and unregistration of targets
/// - Directional navigation using strict coordinate comparisons
/// - Alignment preference (targets on same row/column preferred)
/// - Edge cases (no targets, single target, overlapping coordinates)
final class NavigationRegistryTests: XCTestCase {
    private var registry: NavigationRegistry!

    override func setUp() {
        super.setUp()
        registry = NavigationRegistry()
    }

    override func tearDown() {
        registry = nil
        super.tearDown()
    }

    // MARK: - Registration Tests

    func testRegisterAddsTarget() {
        let item = DetailFocusableItem.uuid("test-uuid")
        registry.register(item, frame: CGRect(x: 0, y: 0, width: 100, height: 30))

        XCTAssertEqual(registry.targets.count, 1)
        XCTAssertNotNil(registry.targets["uuid-test-uuid"])
    }

    func testRegisterUpdatesExistingTarget() {
        let item = DetailFocusableItem.uuid("test-uuid")
        registry.register(item, frame: CGRect(x: 0, y: 0, width: 100, height: 30))
        registry.register(item, frame: CGRect(x: 50, y: 50, width: 100, height: 30))

        XCTAssertEqual(registry.targets.count, 1, "Should update, not add duplicate")
        XCTAssertEqual(registry.targets["uuid-test-uuid"]?.frame.origin.x, 50)
    }

    func testUnregisterRemovesTarget() {
        let item = DetailFocusableItem.uuid("test-uuid")
        registry.register(item, frame: CGRect(x: 0, y: 0, width: 100, height: 30))
        registry.unregister(id: "uuid-test-uuid")

        XCTAssertEqual(registry.targets.count, 0)
    }

    func testUnregisterClearsFocusIfFocusedTargetRemoved() {
        let item = DetailFocusableItem.uuid("test-uuid")
        registry.register(item, frame: CGRect(x: 0, y: 0, width: 100, height: 30))
        registry.focusOn(item)
        XCTAssertEqual(registry.focusedId, "uuid-test-uuid")

        registry.unregister(id: "uuid-test-uuid")

        XCTAssertNil(registry.focusedId)
    }

    func testClearAllRemovesAllTargets() {
        registry.register(.uuid("a"), frame: CGRect(x: 0, y: 0, width: 100, height: 30))
        registry.register(.uuid("b"), frame: CGRect(x: 0, y: 40, width: 100, height: 30))
        registry.focusFirst()

        registry.clearAll()

        XCTAssertEqual(registry.targets.count, 0)
        XCTAssertNil(registry.focusedId)
        XCTAssertFalse(registry.isNavigationActive)
    }

    // MARK: - Focus Tests

    func testFocusFirstSelectsTopLeftTarget() {
        // Register targets in random order
        registry.register(.uuid("bottom-right"), frame: CGRect(x: 200, y: 100, width: 100, height: 30))
        registry.register(.uuid("top-left"), frame: CGRect(x: 0, y: 0, width: 100, height: 30))
        registry.register(.uuid("top-right"), frame: CGRect(x: 200, y: 0, width: 100, height: 30))

        registry.focusFirst()

        XCTAssertEqual(registry.focusedId, "uuid-top-left")
        XCTAssertTrue(registry.isNavigationActive)
    }

    func testFocusLastSelectsBottomRightTarget() {
        registry.register(.uuid("top-left"), frame: CGRect(x: 0, y: 0, width: 100, height: 30))
        registry.register(.uuid("bottom-right"), frame: CGRect(x: 200, y: 100, width: 100, height: 30))
        registry.register(.uuid("bottom-left"), frame: CGRect(x: 0, y: 100, width: 100, height: 30))

        registry.focusLast()

        XCTAssertEqual(registry.focusedId, "uuid-bottom-right")
    }

    func testFocusOnSelectsSpecificItem() {
        let item = DetailFocusableItem.uuid("target")
        registry.register(.uuid("other"), frame: CGRect(x: 0, y: 0, width: 100, height: 30))
        registry.register(item, frame: CGRect(x: 0, y: 40, width: 100, height: 30))

        registry.focusOn(item)

        XCTAssertEqual(registry.focusedId, "uuid-target")
        XCTAssertTrue(registry.isNavigationActive)
    }

    func testFocusOnIgnoresUnregisteredItem() {
        registry.register(.uuid("registered"), frame: CGRect(x: 0, y: 0, width: 100, height: 30))
        registry.focusFirst()

        registry.focusOn(.uuid("not-registered"))

        XCTAssertEqual(registry.focusedId, "uuid-registered", "Should not change focus")
    }

    func testFocusedItemReturnsNilWhenNavigationInactive() {
        registry.register(.uuid("test"), frame: CGRect(x: 0, y: 0, width: 100, height: 30))
        registry.focusedId = "uuid-test"
        registry.deactivateNavigation()

        XCTAssertNil(registry.focusedItem)
    }

    // MARK: - Navigation Down (j key)

    func testNavigateDownMovesToStrictlyGreaterY() {
        registry.register(.uuid("top"), frame: CGRect(x: 50, y: 0, width: 100, height: 30))
        registry.register(.uuid("bottom"), frame: CGRect(x: 50, y: 50, width: 100, height: 30))
        registry.focusFirst()

        let result = registry.navigate(.down)

        XCTAssertTrue(result)
        XCTAssertEqual(registry.focusedId, "uuid-bottom")
    }

    func testNavigateDownStaysOnSameYCoordinate() {
        // Both targets at same Y - down should not move
        registry.register(.uuid("left"), frame: CGRect(x: 0, y: 50, width: 100, height: 30))
        registry.register(.uuid("right"), frame: CGRect(x: 200, y: 50, width: 100, height: 30))
        registry.focusOn(.uuid("left"))

        let result = registry.navigate(.down)

        XCTAssertTrue(result, "Should return true (handled)")
        XCTAssertEqual(registry.focusedId, "uuid-left", "Should stay on same target")
    }

    func testNavigateDownPrefersAlignedTarget() {
        // Three targets: current at top-center, two below (one aligned, one offset)
        registry.register(.uuid("current"), frame: CGRect(x: 100, y: 0, width: 100, height: 30))
        registry.register(.uuid("below-aligned"), frame: CGRect(x: 100, y: 50, width: 100, height: 30))
        registry.register(.uuid("below-offset"), frame: CGRect(x: 300, y: 50, width: 100, height: 30))
        registry.focusOn(.uuid("current"))

        registry.navigate(.down)

        XCTAssertEqual(registry.focusedId, "uuid-below-aligned", "Should prefer aligned target")
    }

    func testNavigateDownSelectsClosestWhenMultipleAligned() {
        registry.register(.uuid("top"), frame: CGRect(x: 50, y: 0, width: 100, height: 30))
        registry.register(.uuid("middle"), frame: CGRect(x: 50, y: 40, width: 100, height: 30))
        registry.register(.uuid("bottom"), frame: CGRect(x: 50, y: 100, width: 100, height: 30))
        registry.focusFirst()

        registry.navigate(.down)

        XCTAssertEqual(registry.focusedId, "uuid-middle", "Should select closest")
    }

    // MARK: - Navigation Up (k key)

    func testNavigateUpMovesToStrictlyLesserY() {
        registry.register(.uuid("top"), frame: CGRect(x: 50, y: 0, width: 100, height: 30))
        registry.register(.uuid("bottom"), frame: CGRect(x: 50, y: 50, width: 100, height: 30))
        registry.focusOn(.uuid("bottom"))

        let result = registry.navigate(.up)

        XCTAssertTrue(result)
        XCTAssertEqual(registry.focusedId, "uuid-top")
    }

    func testNavigateUpStaysWhenAtTop() {
        registry.register(.uuid("only"), frame: CGRect(x: 50, y: 0, width: 100, height: 30))
        registry.focusFirst()

        let result = registry.navigate(.up)

        XCTAssertTrue(result, "Should return true (handled)")
        XCTAssertEqual(registry.focusedId, "uuid-only", "Should stay on same target")
    }

    // MARK: - Navigation Right (l key)

    func testNavigateRightMovesToStrictlyGreaterX() {
        registry.register(.uuid("left"), frame: CGRect(x: 0, y: 50, width: 100, height: 30))
        registry.register(.uuid("right"), frame: CGRect(x: 200, y: 50, width: 100, height: 30))
        registry.focusOn(.uuid("left"))

        let result = registry.navigate(.right)

        XCTAssertTrue(result)
        XCTAssertEqual(registry.focusedId, "uuid-right")
    }

    func testNavigateRightStaysOnSameXCoordinate() {
        // Both targets at same X - right should not move
        registry.register(.uuid("top"), frame: CGRect(x: 50, y: 0, width: 100, height: 30))
        registry.register(.uuid("bottom"), frame: CGRect(x: 50, y: 100, width: 100, height: 30))
        registry.focusOn(.uuid("top"))

        registry.navigate(.right)

        XCTAssertEqual(registry.focusedId, "uuid-top", "Should stay on same target")
    }

    func testNavigateRightPrefersAlignedTarget() {
        // Current at left, two targets to the right (one same row, one different)
        registry.register(.uuid("current"), frame: CGRect(x: 0, y: 50, width: 100, height: 30))
        registry.register(.uuid("right-aligned"), frame: CGRect(x: 200, y: 50, width: 100, height: 30))
        registry.register(.uuid("right-offset"), frame: CGRect(x: 200, y: 150, width: 100, height: 30))
        registry.focusOn(.uuid("current"))

        registry.navigate(.right)

        XCTAssertEqual(registry.focusedId, "uuid-right-aligned")
    }

    // MARK: - Navigation Left (h key)

    func testNavigateLeftMovesToStrictlyLesserX() {
        registry.register(.uuid("left"), frame: CGRect(x: 0, y: 50, width: 100, height: 30))
        registry.register(.uuid("right"), frame: CGRect(x: 200, y: 50, width: 100, height: 30))
        registry.focusOn(.uuid("right"))

        let result = registry.navigate(.left)

        XCTAssertTrue(result)
        XCTAssertEqual(registry.focusedId, "uuid-left")
    }

    func testNavigateLeftStaysWhenAtLeftmost() {
        registry.register(.uuid("only"), frame: CGRect(x: 0, y: 50, width: 100, height: 30))
        registry.focusFirst()

        registry.navigate(.left)

        XCTAssertEqual(registry.focusedId, "uuid-only")
    }

    // MARK: - Activation Tests

    func testNavigateActivatesOnFirstPress() {
        registry.register(.uuid("target"), frame: CGRect(x: 0, y: 0, width: 100, height: 30))
        XCTAssertFalse(registry.isNavigationActive)

        let result = registry.navigate(.down)

        XCTAssertTrue(result)
        XCTAssertTrue(registry.isNavigationActive)
        XCTAssertNotNil(registry.focusedId, "Should have focused first target")
    }

    func testDeactivateNavigationHidesFocusRing() {
        registry.register(.uuid("target"), frame: CGRect(x: 0, y: 0, width: 100, height: 30))
        registry.focusFirst()
        XCTAssertTrue(registry.isNavigationActive)

        registry.deactivateNavigation()

        XCTAssertFalse(registry.isNavigationActive)
        XCTAssertNotNil(registry.focusedId, "focusedId preserved but focusedItem returns nil")
        XCTAssertNil(registry.focusedItem, "focusedItem should return nil when inactive")
    }

    // MARK: - Edge Cases

    func testNavigateWithNoTargetsReturnsFalse() {
        // Empty registry
        let result = registry.navigate(.down)

        // First press activates, but no targets to focus
        XCTAssertTrue(result, "Should return true for activation")
        XCTAssertNil(registry.focusedId)
    }

    func testNavigateWithSingleTargetStaysInPlace() {
        registry.register(.uuid("only"), frame: CGRect(x: 50, y: 50, width: 100, height: 30))
        registry.focusFirst()

        // Try all directions
        registry.navigate(.up)
        XCTAssertEqual(registry.focusedId, "uuid-only")

        registry.navigate(.down)
        XCTAssertEqual(registry.focusedId, "uuid-only")

        registry.navigate(.left)
        XCTAssertEqual(registry.focusedId, "uuid-only")

        registry.navigate(.right)
        XCTAssertEqual(registry.focusedId, "uuid-only")
    }

    func testAlignmentToleranceAllowsSlightOffset() {
        // The alignment tolerance is 20pt
        // Target slightly offset (15pt) should still be preferred over far target
        registry.register(.uuid("current"), frame: CGRect(x: 100, y: 0, width: 100, height: 30))
        registry.register(.uuid("below-slight-offset"), frame: CGRect(
            x: 115,
            y: 50,
            width: 100,
            height: 30
        )) // 15pt offset
        registry.register(.uuid("below-far"), frame: CGRect(
            x: 300,
            y: 40,
            width: 100,
            height: 30
        )) // closer Y but far X
        registry.focusOn(.uuid("current"))

        registry.navigate(.down)

        XCTAssertEqual(registry.focusedId, "uuid-below-slight-offset", "Should prefer aligned target within tolerance")
    }

    // MARK: - Complex Layout Tests

    func testNavigationInGridLayout() {
        // 3x3 grid of targets
        // [0,0] [1,0] [2,0]
        // [0,1] [1,1] [2,1]
        // [0,2] [1,2] [2,2]
        for row in 0 ..< 3 {
            for col in 0 ..< 3 {
                registry.register(
                    .uuid("\(col)-\(row)"),
                    frame: CGRect(x: CGFloat(col * 100), y: CGFloat(row * 50), width: 80, height: 40)
                )
            }
        }
        registry.focusOn(.uuid("1-1")) // Center

        // Move right
        registry.navigate(.right)
        XCTAssertEqual(registry.focusedId, "uuid-2-1")

        // Move down
        registry.navigate(.down)
        XCTAssertEqual(registry.focusedId, "uuid-2-2")

        // Move left
        registry.navigate(.left)
        XCTAssertEqual(registry.focusedId, "uuid-1-2")

        // Move up
        registry.navigate(.up)
        XCTAssertEqual(registry.focusedId, "uuid-1-1")
    }

    func testNavigationWithTwoColumnLayout() {
        // Simulates detail view: left column (properties) and right column (links)
        registry.register(.taskName("Task"), frame: CGRect(x: 0, y: 0, width: 200, height: 30))
        registry.register(.uuid("uuid"), frame: CGRect(x: 0, y: 40, width: 200, height: 30))
        registry.register(.project("Project"), frame: CGRect(x: 0, y: 80, width: 200, height: 30))

        // Right column - GitLab links at different Y positions
        let link1 = ExternalLinkDto(
            id: 1,
            provider: "gitlab",
            url: "https://example.com/1",
            externalKey: "mr:1",
            cachedResponse: nil,
            lastSyncedAt: nil,
            syncError: nil
        )
        let link2 = ExternalLinkDto(
            id: 2,
            provider: "gitlab",
            url: "https://example.com/2",
            externalKey: "mr:2",
            cachedResponse: nil,
            lastSyncedAt: nil,
            syncError: nil
        )
        registry.register(.gitlabMR(link1), frame: CGRect(x: 300, y: 0, width: 200, height: 30))
        registry.register(.gitlabMR(link2), frame: CGRect(x: 300, y: 40, width: 200, height: 30))

        // Start at task name
        registry.focusOn(.taskName("Task"))

        // Move right - should go to GitLab link on same row
        registry.navigate(.right)
        XCTAssertEqual(registry.focusedId, "gitlab-1")

        // Move down - should stay in right column
        registry.navigate(.down)
        XCTAssertEqual(registry.focusedId, "gitlab-2")

        // Move left - should go to left column
        registry.navigate(.left)
        XCTAssertEqual(registry.focusedId, "uuid-uuid", "Should move to left column at similar Y")
    }
}
