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
        let task = try decode(ApiTask.self, from: json)
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
        let task = try decode(ApiTask.self, from: json)
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
        let task = try decode(ApiTask.self, from: json)
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
        let annotation = try decode(TaskAnnotationDto.self, from: json)
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
        let annotation = try decode(TaskAnnotationDto.self, from: json)
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
        let history = try decode(TaskHistoryDto.self, from: json)
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
        let history = try decode(TaskHistoryDto.self, from: json)
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
            ]
        }
        """
        let detail = try decode(ApiTaskDetail.self, from: json)
        XCTAssertEqual(detail.dbId, 42)
        XCTAssertEqual(detail.uuid, "550e8400-e29b-41d4-a716-446655440000")
        XCTAssertEqual(detail.status, "active")
        XCTAssertEqual(detail.annotations.count, 1)
        XCTAssertEqual(detail.annotations.first?.value, "Started work")
        XCTAssertEqual(detail.history.count, 1)
        XCTAssertEqual(detail.history.first?.value, "created")
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
            "history": []
        }
        """
        let detail = try decode(ApiTaskDetail.self, from: json)
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
            "history": []
        }
        """
        let detail = try decode(ApiTaskDetail.self, from: json)
        XCTAssertTrue(detail.annotations.isEmpty)
        XCTAssertTrue(detail.history.isEmpty)
    }

    // MARK: - Helpers

    private func decode<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
        let data = json.data(using: .utf8)!
        return try JSONDecoder().decode(type, from: data)
    }
}
