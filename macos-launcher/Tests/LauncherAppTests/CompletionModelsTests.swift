@testable import LauncherApp
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
        let item = try decode(CompletionItem.self, from: json)
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
        let item = try decode(CompletionItem.self, from: json)
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
        let item = try decode(CompletionItem.self, from: json)
        XCTAssertEqual(item.id, "test-value")
    }

    func testCompletionItemEquatable() {
        let item1 = makeCompletionItem(value: "test", count: 5)
        let item2 = makeCompletionItem(value: "test", count: 5)
        let item3 = makeCompletionItem(value: "other", count: 5)

        XCTAssertEqual(item1, item2)
        XCTAssertNotEqual(item1, item3)
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
        let response = try decode(CompletionsResponse.self, from: json)
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
        let response = try decode(CompletionsResponse.self, from: json)
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

    func testCompletionContextEquatable() {
        XCTAssertEqual(CompletionContext.action, CompletionContext.action)
        XCTAssertNotEqual(CompletionContext.action, CompletionContext.tag)
    }

    // MARK: - Helpers

    private func decode<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
        let data = try XCTUnwrap(json.data(using: .utf8))
        return try JSONDecoder().decode(type, from: data)
    }
}

// Helper to create CompletionItem for tests
private func makeCompletionItem(value: String, count: Int?) -> CompletionItem {
    let json = if let count {
        #"{"value": "\#(value)", "count": \#(count)}"#
    } else {
        #"{"value": "\#(value)", "count": null}"#
    }
    guard let data = json.data(using: .utf8),
          let item = try? JSONDecoder().decode(CompletionItem.self, from: data)
    else {
        fatalError("Failed to create test CompletionItem - this is a test helper bug")
    }
    return item
}
