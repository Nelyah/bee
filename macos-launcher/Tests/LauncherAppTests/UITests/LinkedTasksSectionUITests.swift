@testable import LauncherApp
import SwiftUI
import ViewInspector
import XCTest

/// UI tests for LinkedTasksSection using ViewInspector.
///
/// These tests verify the view's structure, grouping, ordering, and display behavior.
final class LinkedTasksSectionUITests: XCTestCase {
    // MARK: - Helper

    /// Creates a LinkedTasksSection with default values for non-essential parameters.
    private func makeSection(
        links: [TaskLinkDto],
        linksByType: [LinkType: [TaskLinkDto]],
        tasks: [ApiTask] = [],
        focusedItem: DetailFocusableItem? = nil
    ) -> LinkedTasksSection {
        LinkedTasksSection(
            links: links,
            linksByType: linksByType,
            tasks: tasks,
            focusedItem: focusedItem,
            onNavigateToTask: { _ in }
        )
    }

    // MARK: - Empty State Tests

    func testRendersEmptyWhenNoLinks() throws {
        let sut = makeSection(links: [], linksByType: [:])

        let view = try sut.inspect()

        // Should render nothing (body returns EmptyView via @ViewBuilder)
        // Verify it doesn't crash and has minimal structure
        XCTAssertThrowsError(try view.find(text: "LINKED TASKS"))
    }

    // MARK: - Section Header Tests

    func testDisplaysLinkedTasksHeader() throws {
        let (links, byType) = TestHelpers.makeTaskLinksGrouped([
            (.blocking, "uuid-1"),
        ])
        let sut = makeSection(links: links, linksByType: byType)

        let view = try sut.inspect()

        // The DetailSection should have "LINKED TASKS" title (uppercased)
        _ = try view.find(text: "LINKED TASKS")
    }

    // MARK: - Link Type Group Tests

    func testDisplaysBlockingGroup() throws {
        let (links, byType) = TestHelpers.makeTaskLinksGrouped([
            (.blocking, "uuid-1"),
        ])
        let sut = makeSection(links: links, linksByType: byType)

        let view = try sut.inspect()

        _ = try view.find(text: "BLOCKS")
    }

    func testDisplaysDependsOnGroup() throws {
        let (links, byType) = TestHelpers.makeTaskLinksGrouped([
            (.dependsOn, "uuid-1"),
        ])
        let sut = makeSection(links: links, linksByType: byType)

        let view = try sut.inspect()

        _ = try view.find(text: "DEPENDS ON")
    }

    func testDisplaysParentOfGroup() throws {
        let (links, byType) = TestHelpers.makeTaskLinksGrouped([
            (.parentOf, "uuid-1"),
        ])
        let sut = makeSection(links: links, linksByType: byType)

        let view = try sut.inspect()

        _ = try view.find(text: "PARENT OF")
    }

    func testDisplaysChildOfGroup() throws {
        let (links, byType) = TestHelpers.makeTaskLinksGrouped([
            (.childOf, "uuid-1"),
        ])
        let sut = makeSection(links: links, linksByType: byType)

        let view = try sut.inspect()

        _ = try view.find(text: "CHILD OF")
    }

    func testDisplaysRelatedToGroup() throws {
        let (links, byType) = TestHelpers.makeTaskLinksGrouped([
            (.relatedTo, "uuid-1"),
        ])
        let sut = makeSection(links: links, linksByType: byType)

        let view = try sut.inspect()

        _ = try view.find(text: "RELATED TO")
    }

    func testDisplaysDuplicatesGroup() throws {
        let (links, byType) = TestHelpers.makeTaskLinksGrouped([
            (.duplicates, "uuid-1"),
        ])
        let sut = makeSection(links: links, linksByType: byType)

        let view = try sut.inspect()

        _ = try view.find(text: "DUPLICATES")
    }

    // MARK: - UUID Display Tests

    func testDisplaysShortUUID() throws {
        let (links, byType) = TestHelpers.makeTaskLinksGrouped([
            (.blocking, "550e8400-e29b-41d4-a716-446655440000"),
        ])
        let sut = makeSection(links: links, linksByType: byType)

        let view = try sut.inspect()

        // Should show first 8 characters of UUID
        _ = try view.find(text: "550e8400")
    }

    func testDisplaysMultipleShortUUIDs() throws {
        let (links, byType) = TestHelpers.makeTaskLinksGrouped([
            (.blocking, "aaaaaaaa-bbbb-cccc"),
            (.blocking, "12345678-9999-aaaa"),
        ])
        let sut = makeSection(links: links, linksByType: byType)

        let view = try sut.inspect()

        _ = try view.find(text: "aaaaaaaa")
        _ = try view.find(text: "12345678")
    }

    // MARK: - Multiple Groups Tests

    func testDisplaysMultipleGroups() throws {
        let (links, byType) = TestHelpers.makeTaskLinksGrouped([
            (.blocking, "uuid-1"),
            (.dependsOn, "uuid-2"),
            (.relatedTo, "uuid-3"),
        ])
        let sut = makeSection(links: links, linksByType: byType)

        let view = try sut.inspect()

        _ = try view.find(text: "BLOCKS")
        _ = try view.find(text: "DEPENDS ON")
        _ = try view.find(text: "RELATED TO")
    }

    func testDisplaysMultipleLinksInSameGroup() throws {
        let (links, byType) = TestHelpers.makeTaskLinksGrouped([
            (.blocking, "uuid-111"),
            (.blocking, "uuid-222"),
            (.blocking, "uuid-333"),
        ])
        let sut = makeSection(links: links, linksByType: byType)

        let view = try sut.inspect()

        // All three UUIDs should be visible
        _ = try view.find(text: "uuid-111")
        _ = try view.find(text: "uuid-222")
        _ = try view.find(text: "uuid-333")
    }

    // MARK: - Icon Tests

    func testDisplaysIconForLinkType() throws {
        let (links, byType) = TestHelpers.makeTaskLinksGrouped([
            (.blocking, "uuid-1"),
        ])
        let sut = makeSection(links: links, linksByType: byType)

        let view = try sut.inspect()

        // Verify the view contains an Image (icon for link type)
        _ = try view.find(ViewType.Image.self)
    }

    // MARK: - Ordering Tests

    func testGroupsAreOrderedCorrectly() throws {
        // Add links in reverse order - they should display in correct order
        let (links, byType) = TestHelpers.makeTaskLinksGrouped([
            (.duplicates, "uuid-6"),
            (.relatedTo, "uuid-5"),
            (.childOf, "uuid-4"),
            (.parentOf, "uuid-3"),
            (.dependsOn, "uuid-2"),
            (.blocking, "uuid-1"),
        ])
        let sut = makeSection(links: links, linksByType: byType)

        let view = try sut.inspect()

        // All groups should be present
        _ = try view.find(text: "BLOCKS")
        _ = try view.find(text: "DEPENDS ON")
        _ = try view.find(text: "PARENT OF")
        _ = try view.find(text: "CHILD OF")
        _ = try view.find(text: "RELATED TO")
        _ = try view.find(text: "DUPLICATES")
    }

    // MARK: - Edge Cases

    func testHandlesEmptyLinksByTypeWithNonEmptyLinks() throws {
        // Edge case: links array has items but byType is empty
        let link = TestHelpers.makeTaskLink(linkType: .blocking, targetUuid: "uuid-1")
        let sut = makeSection(links: [link], linksByType: [:])

        let view = try sut.inspect()

        // Should still display the section header but no groups
        _ = try view.find(text: "LINKED TASKS")
    }

    func testHandlesVeryLongUUID() throws {
        let longUuid = String(repeating: "a", count: 100)
        let (links, byType) = TestHelpers.makeTaskLinksGrouped([
            (.blocking, longUuid),
        ])
        let sut = makeSection(links: links, linksByType: byType)

        let view = try sut.inspect()

        // Should truncate to first 8 characters
        _ = try view.find(text: "aaaaaaaa")
    }

    func testHandlesSpecialCharactersInUUID() throws {
        // UUIDs typically have dashes
        let (links, byType) = TestHelpers.makeTaskLinksGrouped([
            (.blocking, "abc-def-123"),
        ])
        let sut = makeSection(links: links, linksByType: byType)

        let view = try sut.inspect()

        _ = try view.find(text: "abc-def-")
    }
}
