@testable import LauncherApp
import XCTest

final class ApiClientErrorTests: XCTestCase {
    // MARK: - ApiClientError.api Tests

    func testApiErrorWithAllFields() {
        let error = ApiClientError.api(
            message: "Validation failed",
            code: "VALIDATION_ERROR",
            developerMessage: "Field 'name' is required"
        )

        XCTAssertEqual(error.errorDescription, "Validation failed")
        XCTAssertEqual(error.code, "VALIDATION_ERROR")
        XCTAssertEqual(error.developerMessage, "Field 'name' is required")
    }

    func testApiErrorWithNilCode() {
        let error = ApiClientError.api(
            message: "Something went wrong",
            code: nil,
            developerMessage: nil
        )

        XCTAssertEqual(error.errorDescription, "Something went wrong")
        XCTAssertNil(error.code)
        XCTAssertNil(error.developerMessage)
    }

    func testApiErrorWithOnlyMessage() {
        let error = ApiClientError.api(
            message: "Task not found",
            code: nil,
            developerMessage: "UUID does not exist in database"
        )

        XCTAssertEqual(error.errorDescription, "Task not found")
        XCTAssertNil(error.code)
        XCTAssertEqual(error.developerMessage, "UUID does not exist in database")
    }

    // MARK: - ApiClientError.invalidResponse Tests

    func testInvalidResponseError() {
        let error = ApiClientError.invalidResponse

        XCTAssertEqual(error.errorDescription, "Invalid response from server")
        XCTAssertNil(error.code)
        XCTAssertNil(error.developerMessage)
    }

    // MARK: - LocalizedError Conformance Tests

    func testApiErrorConformsToLocalizedError() {
        let error: LocalizedError = ApiClientError.api(
            message: "Test error",
            code: "TEST",
            developerMessage: nil
        )

        XCTAssertEqual(error.errorDescription, "Test error")
    }

    func testInvalidResponseConformsToLocalizedError() {
        let error: LocalizedError = ApiClientError.invalidResponse

        XCTAssertEqual(error.errorDescription, "Invalid response from server")
    }

    // MARK: - Error Casting Tests

    func testApiErrorCanBeCastToError() {
        let error: Error = ApiClientError.api(
            message: "Generic error",
            code: nil,
            developerMessage: nil
        )

        XCTAssertNotNil(error as? ApiClientError)
    }

    func testErrorDescriptionAccessibleViaLocalizedDescription() {
        let error: Error = ApiClientError.api(
            message: "User-facing message",
            code: nil,
            developerMessage: nil
        )

        XCTAssertEqual(error.localizedDescription, "User-facing message")
    }
}
