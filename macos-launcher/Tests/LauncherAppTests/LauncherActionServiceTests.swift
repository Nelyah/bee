import XCTest
@testable import LauncherApp

@MainActor
final class LauncherActionServiceTests: XCTestCase {
    func testLoadConfigCachesReport() async throws {
        let mock = MockApiClient()
        let service = LauncherActionService(apiClient: mock)

        let config = try await service.loadConfig()

        XCTAssertEqual(config.columns, MockApiClient.sampleConfig.report.columns)
        XCTAssertEqual(service.reportConfig?.columns, MockApiClient.sampleConfig.report.columns)
    }

    func testResolveDefaultFilterReturnsParsedFilter() async {
        let mock = MockApiClient()
        mock.parseResult = .success(ParseResponse(
            action: "list",
            properties: nil,
            filter: .string("from-default"),
            tokens: []
        ))

        let service = LauncherActionService(apiClient: mock)
        service.setReportConfig(ReportConfig(
            filters: ["status:pending or status:active"],
            columns: ["id"],
            columnNames: ["ID"]
        ))

        let parsed = ParseResponse(action: "list", properties: nil, filter: nil, tokens: [])
        let filter = await service.resolveDefaultFilterIfNeeded(parsed: parsed, actionName: "list")

        XCTAssertEqual(mock.lastParseInput, "list status:pending or status:active")
        switch filter {
        case .string(let value):
            XCTAssertEqual(value, "from-default")
        default:
            XCTFail("Expected parsed default filter")
        }
    }
}
