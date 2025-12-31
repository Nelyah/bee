@testable import LauncherApp
import XCTest

final class ConfigModelsTests: XCTestCase {
    // MARK: - ReportConfig Tests

    func testReportConfigDecodes() throws {
        let json = """
        {
            "filters": ["status:active"],
            "columns": ["id", "summary"],
            "column_names": ["ID", "Summary"]
        }
        """
        let config = try decode(ReportConfig.self, from: json)
        XCTAssertEqual(config.staticFilters, ["status:active"])
        XCTAssertEqual(config.columns, ["id", "summary"])
        XCTAssertEqual(config.columnNames, ["ID", "Summary"])
        XCTAssertNil(config.userFilter)
    }

    func testReportConfigDecodesWithUserFilter() throws {
        let json = """
        {
            "filters": [],
            "filter": {"type": "status", "value": "active"},
            "columns": ["id"],
            "column_names": ["ID"]
        }
        """
        let config = try decode(ReportConfig.self, from: json)
        XCTAssertTrue(config.staticFilters.isEmpty)
        XCTAssertNotNil(config.userFilter)
    }

    func testReportConfigDecodesWithMissingFilters() throws {
        let json = """
        {
            "columns": ["id"],
            "column_names": ["ID"]
        }
        """
        let config = try decode(ReportConfig.self, from: json)
        XCTAssertTrue(config.staticFilters.isEmpty)
    }

    func testReportConfigMemberwiseInit() {
        let config = ReportConfig(
            staticFilters: ["status:active"],
            userFilter: nil,
            columns: ["id"],
            columnNames: ["ID"]
        )
        XCTAssertEqual(config.staticFilters, ["status:active"])
        XCTAssertEqual(config.columns, ["id"])
        XCTAssertEqual(config.columnNames, ["ID"])
    }

    // MARK: - ReportSummary Tests

    func testReportSummaryDecodes() throws {
        let json = """
        {
            "name": "active",
            "filters": ["status:active"],
            "columns": ["id", "summary"],
            "column_names": ["ID", "Summary"],
            "is_default": true
        }
        """
        let summary = try decode(ReportSummary.self, from: json)
        XCTAssertEqual(summary.name, "active")
        XCTAssertEqual(summary.staticFilters, ["status:active"])
        XCTAssertEqual(summary.columns, ["id", "summary"])
        XCTAssertEqual(summary.columnNames, ["ID", "Summary"])
        XCTAssertTrue(summary.isDefault)
        XCTAssertFalse(summary.isUserReport)
        XCTAssertEqual(summary.id, "active")
    }

    func testReportSummaryDecodesUserReport() throws {
        let json = """
        {
            "name": "my-report",
            "filters": [],
            "filter": {"type": "project", "value": "test"},
            "columns": ["id"],
            "column_names": ["ID"],
            "is_default": false,
            "is_user_report": true
        }
        """
        let summary = try decode(ReportSummary.self, from: json)
        XCTAssertEqual(summary.name, "my-report")
        XCTAssertTrue(summary.isUserReport)
        XCTAssertNotNil(summary.userFilter)
    }

    func testReportSummaryMemberwiseInit() {
        let summary = ReportSummary(
            name: "test",
            staticFilters: ["status:active"],
            columns: ["id"],
            columnNames: ["ID"],
            isDefault: false,
            isUserReport: true
        )
        XCTAssertEqual(summary.name, "test")
        XCTAssertEqual(summary.staticFilters, ["status:active"])
        XCTAssertFalse(summary.isDefault)
        XCTAssertTrue(summary.isUserReport)
    }

    // MARK: - ConfigResponse Tests

    func testConfigResponseDecodes() throws {
        let json = """
        {
            "report": {
                "filters": ["status:active"],
                "columns": ["id"],
                "column_names": ["ID"]
            },
            "reports": [
                {
                    "name": "active",
                    "filters": ["status:active"],
                    "columns": ["id"],
                    "column_names": ["ID"],
                    "is_default": true
                }
            ]
        }
        """
        let response = try decode(ConfigResponse.self, from: json)
        XCTAssertEqual(response.report.staticFilters, ["status:active"])
        XCTAssertEqual(response.reports.count, 1)
        XCTAssertEqual(response.reports.first?.name, "active")
    }

    // MARK: - UserReportRequest Tests

    func testUserReportRequestEncodes() throws {
        let request = UserReportRequest(
            name: "my-report",
            filter: .object(["type": .string("project")]),
            columns: ["id", "summary"],
            columnNames: ["ID", "Summary"]
        )
        let data = try JSONEncoder().encode(request)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(json["name"] as? String, "my-report")
        XCTAssertEqual(json["columns"] as? [String], ["id", "summary"])
        XCTAssertEqual(json["column_names"] as? [String], ["ID", "Summary"])
        XCTAssertNotNil(json["filter"])
    }

    func testUserReportRequestEncodesWithNilFilter() throws {
        let request = UserReportRequest(
            name: "my-report",
            filter: nil,
            columns: ["id"],
            columnNames: ["ID"]
        )
        let data = try JSONEncoder().encode(request)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(json["name"] as? String, "my-report")
        // filter should be null or absent
    }

    // MARK: - UserReportDto Tests

    func testUserReportDtoDecodes() throws {
        let json = """
        {
            "name": "my-report",
            "filter": {"type": "project"},
            "columns": ["id"],
            "column_names": ["ID"],
            "created_at": "2024-01-15T10:30:00Z",
            "updated_at": "2024-01-16T11:00:00Z"
        }
        """
        let dto = try decode(UserReportDto.self, from: json)
        XCTAssertEqual(dto.name, "my-report")
        XCTAssertNotNil(dto.filter)
        XCTAssertEqual(dto.columns, ["id"])
        XCTAssertEqual(dto.columnNames, ["ID"])
        XCTAssertEqual(dto.createdAt, "2024-01-15T10:30:00Z")
        XCTAssertEqual(dto.updatedAt, "2024-01-16T11:00:00Z")
    }

    // MARK: - UserReportsListResponse Tests

    func testUserReportsListResponseDecodes() throws {
        let json = """
        {
            "reports": [
                {
                    "name": "report1",
                    "filter": null,
                    "columns": ["id"],
                    "column_names": ["ID"],
                    "created_at": "2024-01-15T10:30:00Z",
                    "updated_at": "2024-01-15T10:30:00Z"
                }
            ]
        }
        """
        let response = try decode(UserReportsListResponse.self, from: json)
        XCTAssertEqual(response.reports.count, 1)
        XCTAssertEqual(response.reports.first?.name, "report1")
    }

    // MARK: - Helpers

    private func decode<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
        let data = try XCTUnwrap(json.data(using: .utf8))
        return try JSONDecoder().decode(type, from: data)
    }
}
