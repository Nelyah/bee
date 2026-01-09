@testable import LauncherAppKit
import XCTest

final class CompletionModelsTests: XCTestCase {
    // MARK: - CompletionItem Tests

    func testCompletionItemDecodes() throws {
        let json = """
        {
            "value": "urgent",
            "count": 5
        }
        """
        let item = try TestHelpers.decode(CompletionItem.self, from: json)
        XCTAssertEqual(item.value, "urgent")
        XCTAssertEqual(item.count, 5)
    }

    func testCompletionItemDecodesWithNullCount() throws {
        let json = """
        {
            "value": "work",
            "count": null
        }
        """
        let item = try TestHelpers.decode(CompletionItem.self, from: json)
        XCTAssertEqual(item.value, "work")
        XCTAssertNil(item.count)
    }

    func testCompletionItemId() throws {
        let json = """
        {
            "value": "test-value",
            "count": null
        }
        """
        let item = try TestHelpers.decode(CompletionItem.self, from: json)
        XCTAssertEqual(item.id, "test-value")
    }

    // MARK: - CompletionsResponse Tests

    func testCompletionsResponseDecodes() throws {
        let json = """
        {
            "items": [
                {"value": "urgent", "count": 5},
                {"value": "work", "count": 3}
            ]
        }
        """
        let response = try TestHelpers.decode(CompletionsResponse.self, from: json)
        XCTAssertEqual(response.items.count, 2)
        XCTAssertEqual(response.items[0].value, "urgent")
        XCTAssertEqual(response.items[1].value, "work")
    }

    func testCompletionsResponseDecodesEmpty() throws {
        let json = """
        {
            "items": []
        }
        """
        let response = try TestHelpers.decode(CompletionsResponse.self, from: json)
        XCTAssertTrue(response.items.isEmpty)
    }

    // MARK: - CompletionContext Tests

    func testCompletionContextApiTypeAction() {
        XCTAssertEqual(CompletionContext.action.apiType, "actions")
    }

    func testCompletionContextApiTypeTag() {
        XCTAssertEqual(CompletionContext.tag.apiType, "tags")
    }

    func testCompletionContextApiTypeProject() {
        XCTAssertEqual(CompletionContext.project.apiType, "projects")
    }

    func testCompletionContextApiTypeStatus() {
        XCTAssertEqual(CompletionContext.status.apiType, "status")
    }

    func testCompletionContextApiTypeDate() {
        XCTAssertEqual(CompletionContext.date.apiType, "dates")
    }

    func testCompletionContextApiTypeTaskRef() {
        XCTAssertNil(CompletionContext.taskRef.apiType)
    }

    func testCompletionContextApiTypeNone() {
        XCTAssertNil(CompletionContext.none.apiType)
    }
}
