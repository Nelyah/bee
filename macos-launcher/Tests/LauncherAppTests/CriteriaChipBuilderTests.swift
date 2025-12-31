@testable import LauncherApp
import XCTest

final class CriteriaChipBuilderTests: XCTestCase {
    func testPropertyChipsFromTagsAndStatus() {
        let properties: JSONValue = .object([
            "tags_add": .array([.string("home"), .string("work")]),
            "tags_remove": .array([.string("later")]),
            "status": .string("active"),
            "summary": .string("Finish the report"),
        ])

        let chips = CriteriaChipBuilder.propertyChips(from: properties)

        XCTAssertTrue(chips.contains { $0.label == "Tag +home" })
        XCTAssertTrue(chips.contains { $0.label == "Tag +work" })
        XCTAssertTrue(chips.contains { $0.label == "Tag -later" })
        XCTAssertTrue(chips.contains { $0.label == "Status: active" })
        XCTAssertTrue(chips.contains { $0.label.contains("Summary:") })
    }

    func testPropertyChipsIgnoreNullProjectAndShowNoneString() {
        let withNull: JSONValue = .object([
            "project": .null,
        ])
        let nullChips = CriteriaChipBuilder.propertyChips(from: withNull)
        XCTAssertFalse(nullChips.contains { $0.label.contains("Project:") })

        let withNone: JSONValue = .object([
            "project": .string("none"),
        ])
        let noneChips = CriteriaChipBuilder.propertyChips(from: withNone)
        XCTAssertTrue(noneChips.contains { $0.label == "Project: none" })
    }

    func testFilterChipsFromNestedFilters() {
        let tagFilter: JSONValue = .object([
            "type": .string("TagFilter"),
            "include": .bool(true),
            "tag_name": .string("urgent"),
        ])
        let statusFilter: JSONValue = .object([
            "type": .string("StatusFilter"),
            "status": .string("pending"),
        ])
        let rootFilter: JSONValue = .object([
            "type": .string("AndFilter"),
            "children": .array([tagFilter, statusFilter]),
        ])

        let chips = CriteriaChipBuilder.filterChips(from: rootFilter)

        XCTAssertTrue(chips.contains { $0.label == "Tag +urgent" })
        XCTAssertTrue(chips.contains { $0.label == "Status: pending" })
    }

    func testFilterChipsFromTokensKeepsStatusWhenTextPresent() {
        let tokens: [TokenSpan] = [
            TokenSpan(tokenType: .filterStatus, literal: "status:", start: 0, end: 7),
            TokenSpan(tokenType: .wordString, literal: "completed", start: 7, end: 16),
            TokenSpan(tokenType: .blank, literal: " ", start: 16, end: 17),
            TokenSpan(tokenType: .wordString, literal: "foo", start: 17, end: 20),
        ]

        let chips = CriteriaChipBuilder.filterChips(from: tokens, actionName: "list")

        XCTAssertTrue(chips.contains { $0.label == "Status: completed" })
        XCTAssertTrue(chips.contains { $0.label == "Text: foo" })
    }
}
