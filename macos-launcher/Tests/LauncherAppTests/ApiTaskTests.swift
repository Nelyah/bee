@testable import LauncherApp
import XCTest

final class ApiTaskTests: XCTestCase {
    // MARK: - ApiTask Tests

    func testApiTaskDecodes() throws {
        let json = """
        {
            "id": 42,
            "uuid": "550e8400-e29b-41d4-a716-446655440000",
            "status": "active",
            "summary": "Complete documentation",
            "project": "work",
            "tags": ["urgent", "docs"],
            "date_created": "2024-01-15T10:30:00Z",
            "date_completed": null,
            "date_due": "2024-01-20T00:00:00Z",
            "urgency": 5
        }
        """
        let task = try TestHelpers.decode(ApiTask.self, from: json)
        XCTAssertEqual(task.dbId, 42)
        XCTAssertEqual(task.uuid, "550e8400-e29b-41d4-a716-446655440000")
        XCTAssertEqual(task.status, "active")
        XCTAssertEqual(task.summary, "Complete documentation")
        XCTAssertEqual(task.project, "work")
        XCTAssertEqual(task.tags, ["urgent", "docs"])
        XCTAssertEqual(task.dateCreated, "2024-01-15T10:30:00Z")
        XCTAssertNil(task.dateCompleted)
        XCTAssertEqual(task.dateDue, "2024-01-20T00:00:00Z")
        XCTAssertEqual(task.urgency, 5)
    }

    func testApiTaskId() throws {
        let json = """
        {
            "id": 1,
            "uuid": "test-uuid",
            "status": "active",
            "summary": "Test",
            "project": null,
            "tags": [],
            "date_created": "2024-01-15T10:30:00Z",
            "date_completed": null,
            "date_due": null,
            "urgency": null
        }
        """
        let task = try TestHelpers.decode(ApiTask.self, from: json)
        XCTAssertEqual(task.id, "test-uuid")
    }

    func testApiTaskDecodesWithNullDbId() throws {
        let json = """
        {
            "id": null,
            "uuid": "test-uuid",
            "status": "active",
            "summary": "Test",
            "project": null,
            "tags": [],
            "date_created": "2024-01-15T10:30:00Z",
            "date_completed": null,
            "date_due": null,
            "urgency": null
        }
        """
        let task = try TestHelpers.decode(ApiTask.self, from: json)
        XCTAssertNil(task.dbId)
    }

    // MARK: - TaskAnnotationDto Tests

    func testTaskAnnotationDtoDecodes() throws {
        let json = """
        {
            "value": "Added new feature",
            "time": "2024-01-15T10:30:00Z"
        }
        """
        let annotation = try TestHelpers.decode(TaskAnnotationDto.self, from: json)
        XCTAssertEqual(annotation.value, "Added new feature")
        XCTAssertEqual(annotation.time, "2024-01-15T10:30:00Z")
    }

    func testTaskAnnotationDtoId() throws {
        let json = """
        {
            "value": "Test annotation",
            "time": "2024-01-15T10:30:00Z"
        }
        """
        let annotation = try TestHelpers.decode(TaskAnnotationDto.self, from: json)
        XCTAssertEqual(annotation.id, "2024-01-15T10:30:00Z-Test annotation")
    }

    // MARK: - TaskHistoryDto Tests

    func testTaskHistoryDtoDecodes() throws {
        let json = """
        {
            "value": "status changed to completed",
            "datetime": "2024-01-16T14:00:00Z"
        }
        """
        let history = try TestHelpers.decode(TaskHistoryDto.self, from: json)
        XCTAssertEqual(history.value, "status changed to completed")
        XCTAssertEqual(history.datetime, "2024-01-16T14:00:00Z")
    }

    func testTaskHistoryDtoId() throws {
        let json = """
        {
            "value": "created",
            "datetime": "2024-01-15T10:30:00Z"
        }
        """
        let history = try TestHelpers.decode(TaskHistoryDto.self, from: json)
        XCTAssertEqual(history.id, "2024-01-15T10:30:00Z-created")
    }

    // MARK: - ApiTaskDetail Tests

    func testApiTaskDetailDecodes() throws {
        let json = """
        {
            "id": 42,
            "uuid": "550e8400-e29b-41d4-a716-446655440000",
            "status": "active",
            "summary": "Complete documentation",
            "project": "work",
            "tags": ["urgent"],
            "date_created": "2024-01-15T10:30:00Z",
            "date_completed": null,
            "date_due": "2024-01-20T00:00:00Z",
            "urgency": 5,
            "annotations": [
                {"value": "Started work", "time": "2024-01-15T11:00:00Z"}
            ],
            "history": [
                {"value": "created", "datetime": "2024-01-15T10:30:00Z"}
            ],
            "links": [
                {"link_type": "depends_on", "target_uuid": "other-task-uuid"}
            ]
        }
        """
        let detail = try TestHelpers.decode(ApiTaskDetail.self, from: json)
        XCTAssertEqual(detail.dbId, 42)
        XCTAssertEqual(detail.uuid, "550e8400-e29b-41d4-a716-446655440000")
        XCTAssertEqual(detail.status, "active")
        XCTAssertEqual(detail.annotations.count, 1)
        XCTAssertEqual(detail.annotations.first?.value, "Started work")
        XCTAssertEqual(detail.history.count, 1)
        XCTAssertEqual(detail.history.first?.value, "created")
        XCTAssertEqual(detail.links.count, 1)
        XCTAssertEqual(detail.links.first?.linkType, "depends_on")
    }

    func testApiTaskDetailId() throws {
        let json = """
        {
            "id": 1,
            "uuid": "detail-uuid",
            "status": "active",
            "summary": "Test",
            "project": null,
            "tags": [],
            "date_created": "2024-01-15T10:30:00Z",
            "date_completed": null,
            "date_due": null,
            "urgency": null,
            "annotations": [],
            "history": [],
            "links": []
        }
        """
        let detail = try TestHelpers.decode(ApiTaskDetail.self, from: json)
        XCTAssertEqual(detail.id, "detail-uuid")
    }

    func testApiTaskDetailDecodesWithEmptyArrays() throws {
        let json = """
        {
            "id": 1,
            "uuid": "test-uuid",
            "status": "active",
            "summary": "Test",
            "project": null,
            "tags": [],
            "date_created": "2024-01-15T10:30:00Z",
            "date_completed": null,
            "date_due": null,
            "urgency": null,
            "annotations": [],
            "history": [],
            "links": []
        }
        """
        let detail = try TestHelpers.decode(ApiTaskDetail.self, from: json)
        XCTAssertTrue(detail.annotations.isEmpty)
        XCTAssertTrue(detail.history.isEmpty)
        XCTAssertTrue(detail.links.isEmpty)
    }

    // MARK: - TaskLinkDto Tests

    func testTaskLinkDtoDecodes() throws {
        let json = """
        {
            "link_type": "depends_on",
            "target_uuid": "target-task-uuid"
        }
        """
        let link = try TestHelpers.decode(TaskLinkDto.self, from: json)
        XCTAssertEqual(link.linkType, "depends_on")
        XCTAssertEqual(link.targetUuid, "target-task-uuid")
        XCTAssertEqual(link.type, .dependsOn)
    }

    func testTaskLinkDtoId() throws {
        let json = """
        {
            "link_type": "blocking",
            "target_uuid": "some-uuid"
        }
        """
        let link = try TestHelpers.decode(TaskLinkDto.self, from: json)
        XCTAssertEqual(link.id, "blocking-some-uuid")
    }

    func testLinkTypeDisplayNames() {
        XCTAssertEqual(LinkType.dependsOn.displayName, "Depends on")
        XCTAssertEqual(LinkType.blocking.displayName, "Blocks")
        XCTAssertEqual(LinkType.parentOf.displayName, "Parent of")
        XCTAssertEqual(LinkType.childOf.displayName, "Child of")
        XCTAssertEqual(LinkType.relatedTo.displayName, "Related to")
        XCTAssertEqual(LinkType.duplicates.displayName, "Duplicates")
    }
}

// MARK: - LinkType Comprehensive Tests

final class LinkTypeTests: XCTestCase {
    // MARK: - Raw Values

    func testRawValues() {
        XCTAssertEqual(LinkType.dependsOn.rawValue, "depends_on")
        XCTAssertEqual(LinkType.blocking.rawValue, "blocking")
        XCTAssertEqual(LinkType.parentOf.rawValue, "parent_of")
        XCTAssertEqual(LinkType.childOf.rawValue, "child_of")
        XCTAssertEqual(LinkType.relatedTo.rawValue, "related_to")
        XCTAssertEqual(LinkType.duplicates.rawValue, "duplicates")
    }

    func testInitFromRawValue() {
        XCTAssertEqual(LinkType(rawValue: "depends_on"), .dependsOn)
        XCTAssertEqual(LinkType(rawValue: "blocking"), .blocking)
        XCTAssertEqual(LinkType(rawValue: "parent_of"), .parentOf)
        XCTAssertEqual(LinkType(rawValue: "child_of"), .childOf)
        XCTAssertEqual(LinkType(rawValue: "related_to"), .relatedTo)
        XCTAssertEqual(LinkType(rawValue: "duplicates"), .duplicates)
    }

    func testUnknownRawValueReturnsNil() {
        XCTAssertNil(LinkType(rawValue: "unknown"))
        XCTAssertNil(LinkType(rawValue: ""))
        XCTAssertNil(LinkType(rawValue: "dependson")) // Missing underscore
        XCTAssertNil(LinkType(rawValue: "Depends_On")) // Wrong case
    }

    // MARK: - Icon Names

    func testIconNames() {
        XCTAssertEqual(LinkType.dependsOn.iconName, "arrow.left")
        XCTAssertEqual(LinkType.blocking.iconName, "arrow.right")
        XCTAssertEqual(LinkType.parentOf.iconName, "arrow.up")
        XCTAssertEqual(LinkType.childOf.iconName, "arrow.down")
        XCTAssertEqual(LinkType.relatedTo.iconName, "link")
        XCTAssertEqual(LinkType.duplicates.iconName, "doc.on.doc")
    }

    func testAllIconNamesAreValidSFSymbols() {
        // All icon names should be non-empty
        for linkType in LinkType.allCases {
            XCTAssertFalse(linkType.iconName.isEmpty, "\(linkType) should have non-empty icon name")
        }
    }

    // MARK: - Display Names

    func testDisplayNamesUseActiveVoice() {
        // All display names should use active voice (not passive)
        for linkType in LinkType.allCases {
            XCTAssertFalse(linkType.displayName.contains("by"), "\(linkType) display name should use active voice")
        }
    }

    func testDisplayNamesAreNonEmpty() {
        for linkType in LinkType.allCases {
            XCTAssertFalse(linkType.displayName.isEmpty, "\(linkType) should have non-empty display name")
        }
    }

    // MARK: - CaseIterable

    func testAllCasesContainsSixTypes() {
        XCTAssertEqual(LinkType.allCases.count, 6)
    }

    func testAllCasesOrder() {
        let expected: [LinkType] = [.dependsOn, .blocking, .parentOf, .childOf, .relatedTo, .duplicates]
        XCTAssertEqual(LinkType.allCases, expected)
    }

    // MARK: - Equatable

    func testLinkTypeEquatable() {
        XCTAssertEqual(LinkType.blocking, LinkType.blocking)
        XCTAssertNotEqual(LinkType.blocking, LinkType.dependsOn)
    }

    // MARK: - Hashable

    func testLinkTypeHashable() {
        let set: Set<LinkType> = [.blocking, .dependsOn, .blocking]
        XCTAssertEqual(set.count, 2)
    }
}

// MARK: - TaskLinkDto Comprehensive Tests

final class TaskLinkDtoTests: XCTestCase {
    // MARK: - Decoding

    func testDecodesAllLinkTypes() throws {
        let testCases: [(json: String, expectedType: LinkType)] = [
            (#"{"link_type": "depends_on", "target_uuid": "uuid1"}"#, .dependsOn),
            (#"{"link_type": "blocking", "target_uuid": "uuid2"}"#, .blocking),
            (#"{"link_type": "parent_of", "target_uuid": "uuid3"}"#, .parentOf),
            (#"{"link_type": "child_of", "target_uuid": "uuid4"}"#, .childOf),
            (#"{"link_type": "related_to", "target_uuid": "uuid5"}"#, .relatedTo),
            (#"{"link_type": "duplicates", "target_uuid": "uuid6"}"#, .duplicates),
        ]

        for (json, expectedType) in testCases {
            let link = try TestHelpers.decode(TaskLinkDto.self, from: json)
            XCTAssertEqual(link.type, expectedType, "Failed for \(json)")
        }
    }

    func testTypeReturnsNilForUnknownLinkType() throws {
        let json = #"{"link_type": "unknown_type", "target_uuid": "uuid"}"#
        let link = try TestHelpers.decode(TaskLinkDto.self, from: json)
        XCTAssertNil(link.type)
        XCTAssertEqual(link.linkType, "unknown_type")
    }

    func testDecodesWithSpecialCharactersInUUID() throws {
        let json = #"{"link_type": "blocking", "target_uuid": "550e8400-e29b-41d4-a716-446655440000"}"#
        let link = try TestHelpers.decode(TaskLinkDto.self, from: json)
        XCTAssertEqual(link.targetUuid, "550e8400-e29b-41d4-a716-446655440000")
    }

    // MARK: - Identifiable

    func testIdIsDeterministic() throws {
        let json = #"{"link_type": "blocking", "target_uuid": "test-uuid"}"#
        let link1 = try TestHelpers.decode(TaskLinkDto.self, from: json)
        let link2 = try TestHelpers.decode(TaskLinkDto.self, from: json)
        XCTAssertEqual(link1.id, link2.id)
    }

    func testIdCombinesLinkTypeAndTargetUuid() throws {
        let json = #"{"link_type": "parent_of", "target_uuid": "child-uuid"}"#
        let link = try TestHelpers.decode(TaskLinkDto.self, from: json)
        XCTAssertEqual(link.id, "parent_of-child-uuid")
    }

    func testIdDifferentForDifferentLinks() throws {
        let json1 = #"{"link_type": "blocking", "target_uuid": "uuid1"}"#
        let json2 = #"{"link_type": "blocking", "target_uuid": "uuid2"}"#
        let json3 = #"{"link_type": "depends_on", "target_uuid": "uuid1"}"#

        let link1 = try TestHelpers.decode(TaskLinkDto.self, from: json1)
        let link2 = try TestHelpers.decode(TaskLinkDto.self, from: json2)
        let link3 = try TestHelpers.decode(TaskLinkDto.self, from: json3)

        XCTAssertNotEqual(link1.id, link2.id)
        XCTAssertNotEqual(link1.id, link3.id)
    }

    // MARK: - Snake Case Decoding

    func testDecodesSnakeCaseKeys() throws {
        // Verify that CodingKeys mapping works correctly
        let json = #"{"link_type": "related_to", "target_uuid": "abc123"}"#
        let link = try TestHelpers.decode(TaskLinkDto.self, from: json)

        XCTAssertEqual(link.linkType, "related_to")
        XCTAssertEqual(link.targetUuid, "abc123")
    }

    // MARK: - Edge Cases

    func testEmptyTargetUuid() throws {
        let json = #"{"link_type": "blocking", "target_uuid": ""}"#
        let link = try TestHelpers.decode(TaskLinkDto.self, from: json)
        XCTAssertEqual(link.targetUuid, "")
        XCTAssertEqual(link.id, "blocking-")
    }

    func testEmptyLinkType() throws {
        let json = #"{"link_type": "", "target_uuid": "uuid"}"#
        let link = try TestHelpers.decode(TaskLinkDto.self, from: json)
        XCTAssertNil(link.type)
        XCTAssertEqual(link.linkType, "")
    }
}
