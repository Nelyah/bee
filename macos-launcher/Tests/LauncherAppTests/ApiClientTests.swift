import Foundation
@testable import LauncherApp
import XCTest

final class ApiClientTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        TestURLProtocol.requestHandler = nil
    }

    func testBaseURLUsesEnvironmentOverride() async throws {
        let expectation = expectation(description: "request handled")
        TestURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.host, "example.com")
            XCTAssertEqual(request.url?.path, "/v1/config")
            expectation.fulfill()
            return (
                HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!,
                Self.configPayload()
            )
        }

        let client = ApiClient(
            session: makeSession(),
            environment: ["BEE_API_BASE_URL": "http://example.com:9999"]
        )

        _ = try await client.fetchConfig()
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func testParseReturnsApiErrorMessageForNon2xx() async {
        TestURLProtocol.requestHandler = { request in
            let data = #"{"code":"parse_error","user_message":"bad things","developer_message":"details"}"#
                .data(using: .utf8)!
            return (
                HTTPURLResponse(
                    url: request.url!,
                    statusCode: 400,
                    httpVersion: nil,
                    headerFields: nil
                )!,
                data
            )
        }

        let client = ApiClient(
            baseURL: URL(string: "http://127.0.0.1:3000")!,
            session: makeSession()
        )

        do {
            _ = try await client.parse(input: "list")
            XCTFail("Expected ApiClientError")
        } catch let error as ApiClientError {
            switch error {
            case let .api(message, code, developerMessage):
                XCTAssertEqual(message, "bad things")
                XCTAssertEqual(code, "parse_error")
                XCTAssertEqual(developerMessage, "details")
            default:
                XCTFail("Expected api error message")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private func makeSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [TestURLProtocol.self]
    return URLSession(configuration: config)
}

final class TestURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = TestURLProtocol.requestHandler else {
            XCTFail("requestHandler not set")
            return
        }
        let (response, data) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private extension ApiClientTests {
    static func configPayload() -> Data {
        let json = """
        {
          "report": {
            "filters": [],
            "columns": ["id"],
            "column_names": ["ID"]
          },
          "reports": []
        }
        """
        return Data(json.utf8)
    }
}
