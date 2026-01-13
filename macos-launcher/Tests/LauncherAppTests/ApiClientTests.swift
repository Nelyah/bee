import Foundation
@testable import LauncherAppKit
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
            guard let url = request.url,
                  let response = HTTPURLResponse(
                      url: url,
                      statusCode: 200,
                      httpVersion: nil,
                      headerFields: nil
                  )
            else {
                return (HTTPURLResponse(), Data())
            }
            return (response, Self.configPayload())
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
            let data = Data(#"{"code":"parse_error","user_message":"bad things","developer_message":"details"}"#.utf8)
            guard let url = request.url,
                  let response = HTTPURLResponse(
                      url: url,
                      statusCode: 400,
                      httpVersion: nil,
                      headerFields: nil
                  )
            else {
                return (HTTPURLResponse(), Data())
            }
            return (response, data)
        }

        guard let baseURL = URL(string: "http://127.0.0.1:3000") else {
            XCTFail("Invalid base URL")
            return
        }
        let client = ApiClient(
            baseURL: baseURL,
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

    func testParseUsesGlobalEndpointWithProfileClient() async throws {
        let expectation = expectation(description: "request handled")
        TestURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/v1/parse")
            expectation.fulfill()

            let responseJson = """
            {
              "action": "list",
              "properties": null,
              "filter": null,
              "tokens": []
            }
            """

            guard let url = request.url,
                  let response = HTTPURLResponse(
                      url: url,
                      statusCode: 200,
                      httpVersion: nil,
                      headerFields: nil
                  )
            else {
                return (HTTPURLResponse(), Data())
            }

            return (response, Data(responseJson.utf8))
        }

        guard let baseURL = URL(string: "http://127.0.0.1:3000") else {
            XCTFail("Invalid base URL")
            return
        }
        let client = ApiClient(
            baseURL: baseURL,
            session: makeSession(),
            profile: "test-profile"
        )

        _ = try await client.parse(input: "list")
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func testFetchExternalLinksUsesProfileEndpointWithProfileClient() async throws {
        let expectation = expectation(description: "request handled")
        TestURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.path, "/v1/profiles/test-profile/tasks/test-task/external-links")
            expectation.fulfill()

            guard let url = request.url,
                  let response = HTTPURLResponse(
                      url: url,
                      statusCode: 200,
                      httpVersion: nil,
                      headerFields: nil
                  )
            else {
                return (HTTPURLResponse(), Data())
            }

            return (response, Data("[]".utf8))
        }

        guard let baseURL = URL(string: "http://127.0.0.1:3000") else {
            XCTFail("Invalid base URL")
            return
        }
        let client = ApiClient(
            baseURL: baseURL,
            session: makeSession(),
            profile: "test-profile"
        )

        _ = try await client.fetchExternalLinks(taskUUID: "test-task")
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func testCreateProfilePostsToGlobalProfilesEndpoint() async throws {
        let expectation = expectation(description: "request handled")
        TestURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/v1/profiles")

            do {
                let body = try requestBodyData(for: request)
                let payload = try JSONDecoder().decode(ProfileCreateRequest.self, from: body)
                XCTAssertEqual(payload.key, "personal")
                XCTAssertEqual(payload.name, "Personal")
                XCTAssertNil(payload.description)
            } catch {
                XCTFail("Failed decoding payload: \(error)")
            }

            expectation.fulfill()

            let responseJson = """
            {
              "key": "personal",
              "name": "Personal",
              "description": "",
              "data_dir": "/tmp/bee",
              "config_dir": "/tmp/bee"
            }
            """

            guard let url = request.url,
                  let response = HTTPURLResponse(
                      url: url,
                      statusCode: 200,
                      httpVersion: nil,
                      headerFields: nil
                  )
            else {
                return (HTTPURLResponse(), Data())
            }

            return (response, Data(responseJson.utf8))
        }

        guard let baseURL = URL(string: "http://127.0.0.1:3000") else {
            XCTFail("Invalid base URL")
            return
        }
        let client = ApiClient(
            baseURL: baseURL,
            session: makeSession()
        )

        _ = try await client.createProfile(key: "personal", name: "Personal", description: nil)
        await fulfillment(of: [expectation], timeout: 1.0)
    }
}

private func makeSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [TestURLProtocol.self]
    return URLSession(configuration: config)
}

private enum RequestBodyError: Error {
    case missing
}

private func requestBodyData(for request: URLRequest) throws -> Data {
    if let body = request.httpBody {
        return body
    }

    guard let stream = request.httpBodyStream else {
        throw RequestBodyError.missing
    }

    stream.open()
    defer { stream.close() }

    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 1024)

    while stream.hasBytesAvailable {
        let read = stream.read(&buffer, maxLength: buffer.count)
        if read < 0 {
            throw stream.streamError ?? RequestBodyError.missing
        }
        if read == 0 {
            break
        }
        data.append(buffer, count: read)
    }

    return data
}

final class TestURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) -> (HTTPURLResponse, Data))?

    override static func canInit(with request: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
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
