@testable import LauncherApp
import XCTest

final class SmallModelsTests: XCTestCase {
    // MARK: - JSONValue Tests

    func testJSONValueDecodesString() throws {
        let json = #""hello""#
        let value = try TestHelpers.decode(JSONValue.self, from: json)
        if case let .string(str) = value {
            XCTAssertEqual(str, "hello")
        } else {
            XCTFail("Expected string")
        }
    }

    func testJSONValueDecodesNumber() throws {
        let json = "42.5"
        let value = try TestHelpers.decode(JSONValue.self, from: json)
        if case let .number(num) = value {
            XCTAssertEqual(num, 42.5, accuracy: 0.001)
        } else {
            XCTFail("Expected number")
        }
    }

    func testJSONValueDecodesBool() throws {
        let jsonTrue = "true"
        let valueTrue = try TestHelpers.decode(JSONValue.self, from: jsonTrue)
        if case let .bool(b) = valueTrue {
            XCTAssertTrue(b)
        } else {
            XCTFail("Expected bool true")
        }

        let jsonFalse = "false"
        let valueFalse = try TestHelpers.decode(JSONValue.self, from: jsonFalse)
        if case let .bool(b) = valueFalse {
            XCTAssertFalse(b)
        } else {
            XCTFail("Expected bool false")
        }
    }

    func testJSONValueDecodesNull() throws {
        let json = "null"
        let value = try TestHelpers.decode(JSONValue.self, from: json)
        if case .null = value {
            // Success
        } else {
            XCTFail("Expected null")
        }
    }

    func testJSONValueDecodesObject() throws {
        let json = #"{"key": "value"}"#
        let value = try TestHelpers.decode(JSONValue.self, from: json)
        if case let .object(obj) = value {
            if case let .string(str)? = obj["key"] {
                XCTAssertEqual(str, "value")
            } else {
                XCTFail("Expected string value for key")
            }
        } else {
            XCTFail("Expected object")
        }
    }

    func testJSONValueDecodesArray() throws {
        let json = "[1, 2, 3]"
        let value = try TestHelpers.decode(JSONValue.self, from: json)
        if case let .array(arr) = value {
            XCTAssertEqual(arr.count, 3)
        } else {
            XCTFail("Expected array")
        }
    }

    func testJSONValueEncodesRoundTrip() throws {
        let original = JSONValue.object([
            "name": .string("test"),
            "count": .number(42),
            "active": .bool(true),
            "items": .array([.string("a"), .string("b")]),
            "meta": .null,
        ])

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(JSONValue.self, from: data)

        // Verify structure (can't use Equatable due to indirect enum)
        if case let .object(obj) = decoded {
            if case let .string(name)? = obj["name"] {
                XCTAssertEqual(name, "test")
            }
            if case let .number(count)? = obj["count"] {
                XCTAssertEqual(count, 42)
            }
        } else {
            XCTFail("Expected object after round-trip")
        }
    }

    // MARK: - LauncherMode Tests

    func testLauncherModeEnumCases() {
        let listMode = LauncherMode.list
        let detailMode = LauncherMode.detail

        // Verify enum case creation works correctly
        XCTAssertEqual(listMode, LauncherMode.list)
        XCTAssertEqual(detailMode, LauncherMode.detail)
        XCTAssertNotEqual(listMode, detailMode)
    }

    // MARK: - GroupedListRow Tests

    func testGroupedListRowHeaderId() {
        let header = GroupHeader(key: "work", displayName: "Work", taskCount: 5, isCollapsed: false)
        let row = GroupedListRow.header(header)
        XCTAssertEqual(row.id, "header-work")
    }

    func testGroupedListRowTaskId() {
        let task = makeApiTask(uuid: "task-uuid")
        let groupedTask = GroupedTask(task: task, flatIndex: 0, groupKey: "work")
        let row = GroupedListRow.task(groupedTask)
        XCTAssertEqual(row.id, "work-task-task-uuid")
    }

    // MARK: - GroupHeader Tests

    func testGroupHeaderIdWithKey() {
        let header = GroupHeader(key: "project", displayName: "Project", taskCount: 3, isCollapsed: false)
        XCTAssertEqual(header.id, "project")
    }

    func testGroupHeaderIdWithNilKey() {
        let header = GroupHeader(key: nil, displayName: "Ungrouped", taskCount: 2, isCollapsed: false)
        XCTAssertEqual(header.id, "__none__")
    }

    // MARK: - GroupedTask Tests

    func testGroupedTaskIdWithGroupKey() {
        let task = makeApiTask(uuid: "uuid-123")
        let groupedTask = GroupedTask(task: task, flatIndex: 5, groupKey: "work")
        XCTAssertEqual(groupedTask.id, "work-task-uuid-123")
    }

    func testGroupedTaskIdWithNilGroupKey() {
        let task = makeApiTask(uuid: "uuid-456")
        let groupedTask = GroupedTask(task: task, flatIndex: 3, groupKey: nil)
        XCTAssertEqual(groupedTask.id, "__none__-task-uuid-456")
    }

    // MARK: - ToastMessage Tests

    func testToastMessageInitWithDefaults() {
        let toast = ToastMessage(message: "Test message")
        XCTAssertEqual(toast.message, "Test message")
        XCTAssertEqual(toast.icon, .warning)
        XCTAssertNotNil(toast.id)
    }

    func testToastMessageInitWithCustomIcon() {
        let toast = ToastMessage(message: "Success!", icon: .success)
        XCTAssertEqual(toast.message, "Success!")
        XCTAssertEqual(toast.icon, .success)
    }

    func testToastMessageEquatable() {
        let id = UUID()
        let date = Date()
        let toast1 = ToastMessage(id: id, message: "Test", icon: .warning, createdAt: date)
        let toast2 = ToastMessage(id: id, message: "Test", icon: .warning, createdAt: date)
        XCTAssertEqual(toast1, toast2)
    }

    // MARK: - ToastIcon Tests

    func testToastIconEquatable() {
        XCTAssertEqual(ToastIcon.success, ToastIcon.success)
        XCTAssertEqual(ToastIcon.warning, ToastIcon.warning)
        XCTAssertEqual(ToastIcon.gitlab, ToastIcon.gitlab)
        XCTAssertNotEqual(ToastIcon.success, ToastIcon.warning)
    }

    // MARK: - BottomHint Tests

    func testBottomHintProperties() {
        let hint = BottomHint(key: "Esc", label: "Close")
        XCTAssertEqual(hint.key, "Esc")
        XCTAssertEqual(hint.label, "Close")
        XCTAssertNotNil(hint.id)
    }

    func testBottomHintEquatable() {
        let hint1 = BottomHint(key: "Esc", label: "Close")
        let hint2 = BottomHint(key: "Esc", label: "Close")
        // Different IDs so not equal
        XCTAssertNotEqual(hint1.id, hint2.id)
    }

    // MARK: - ApiErrorResponse Tests

    func testApiErrorResponseDecodes() throws {
        let json = """
        {
            "code": "VALIDATION_ERROR",
            "user_message": "Invalid input provided",
            "developer_message": "Field 'name' is required"
        }
        """
        let error = try TestHelpers.decode(ApiErrorResponse.self, from: json)
        XCTAssertEqual(error.code, "VALIDATION_ERROR")
        XCTAssertEqual(error.userMessage, "Invalid input provided")
        XCTAssertEqual(error.developerMessage, "Field 'name' is required")
    }

    // MARK: - CriteriaChip Tests

    func testCriteriaChipKindRawValues() {
        XCTAssertEqual(CriteriaChipKind.filter.rawValue, "filter")
        XCTAssertEqual(CriteriaChipKind.property.rawValue, "property")
    }

    func testCriteriaChipToneColorNotNil() {
        let tones: [CriteriaChipTone] = [
            .blue, .teal, .green, .yellow, .peach,
            .mauve, .lavender, .pink, .sky, .rosewater, .red,
        ]
        for tone in tones {
            XCTAssertNotNil(tone.color, "Color should not be nil for tone \(tone)")
        }
    }

    func testCriteriaChipId() {
        let chip = CriteriaChip(
            kind: .filter,
            label: "status:active",
            systemImage: "circle.fill",
            tone: .green
        )
        XCTAssertEqual(chip.id, "filter-circle.fill-status:active")
    }

    func testCriteriaChipHashable() {
        let chip1 = CriteriaChip(kind: .filter, label: "test", systemImage: "star", tone: .blue)
        let chip2 = CriteriaChip(kind: .filter, label: "test", systemImage: "star", tone: .blue)
        let set: Set<CriteriaChip> = [chip1, chip2]
        XCTAssertEqual(set.count, 1)
    }

    // MARK: - ActionModels Tests

    func testActionRequestEncodes() throws {
        let request = ActionRequest(
            action: "done",
            properties: .object(["uuid": .string("123")]),
            filter: nil
        )
        let data = try JSONEncoder().encode(request)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(json["action"] as? String, "done")
        XCTAssertNotNil(json["properties"])
    }

    func testActionResponseDecodes() throws {
        let json = """
        {
            "action": "done",
            "tasks": [
                {
                    "id": 1,
                    "uuid": "uuid-123",
                    "status": "completed",
                    "summary": "Test task",
                    "project": null,
                    "tags": [],
                    "date_created": "2024-01-15T10:30:00Z",
                    "date_completed": "2024-01-16T10:30:00Z",
                    "date_due": null,
                    "urgency": null
                }
            ],
            "events": [
                {"kind": "info", "message": "Task completed"}
            ]
        }
        """
        let response = try TestHelpers.decode(ActionResponse.self, from: json)
        XCTAssertEqual(response.action, "done")
        XCTAssertEqual(response.tasks.count, 1)
        XCTAssertEqual(response.events.count, 1)
        XCTAssertEqual(response.events.first?.kind, "info")
        XCTAssertEqual(response.events.first?.message, "Task completed")
    }

    func testApiEventDecodes() throws {
        let json = """
        {
            "kind": "warning",
            "message": "Task already completed"
        }
        """
        let event = try TestHelpers.decode(ApiEvent.self, from: json)
        XCTAssertEqual(event.kind, "warning")
        XCTAssertEqual(event.message, "Task already completed")
    }

    // MARK: - Helpers

    private func makeApiTask(uuid: String) -> ApiTask {
        TestHelpers.makeTask(id: uuid, status: "active", summary: "Test")
    }
}
