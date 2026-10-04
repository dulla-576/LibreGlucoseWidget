import Foundation
import XCTest
@testable import LibreGlucoseCore

final class LibreLinkUpAuthenticationTests: XCTestCase {
    func testLoginSendsExpectedRequestAndReturnsSession() async throws {
        let transport = MockHTTPTransport(responses: [response(fixture: "login-success")])
        let api = LibreLinkUpAPI(transport: transport)

        let session = try await api.login(
            credentials: Credentials(email: "person@example.test", password: "synthetic-password")
        )

        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests[0].url?.absoluteString, "https://api.libreview.io/llu/auth/login")
        XCTAssertEqual(requests[0].httpMethod, "POST")
        XCTAssertEqual(requests[0].value(forHTTPHeaderField: "product"), "llu.ios")
        XCTAssertEqual(requests[0].value(forHTTPHeaderField: "version"), "4.16.0")
        let body = try XCTUnwrap(requests[0].httpBody)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
        XCTAssertEqual(payload, [
            "email": "person@example.test",
            "password": "synthetic-password"
        ])
        XCTAssertEqual(session.token, "synthetic-token")
        XCTAssertEqual(session.userID, "synthetic-user")
        XCTAssertEqual(session.expiresAt, Date(timeIntervalSince1970: 1_800_000_000))
        XCTAssertEqual(session.baseURL.absoluteString, "https://api.libreview.io")
    }

    func testLoginFollowsOneSafeRegionalRedirect() async throws {
        let transport = MockHTTPTransport(responses: [
            response(fixture: "login-redirect-eu2"),
            response(fixture: "login-success")
        ])
        let api = LibreLinkUpAPI(transport: transport)

        let session = try await api.login(credentials: syntheticCredentials)

        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.map(\.url?.host), ["api.libreview.io", "api-eu2.libreview.io"])
        XCTAssertEqual(session.baseURL.absoluteString, "https://api-eu2.libreview.io")
    }

    func testLoginRejectsMaliciousRegionWithoutFollowingIt() async throws {
        let malicious = Data(#"{"status":0,"data":{"redirect":true,"region":"eu2.evil.example"}}"#.utf8)
        let transport = MockHTTPTransport(responses: [response(data: malicious)])
        let api = LibreLinkUpAPI(transport: transport)

        await assertLoginError(.invalidRegion, from: api)
        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.count, 1)
    }

    func testLoginRejectsNonHTTPSOrNonLibreViewEntryHost() async throws {
        let badURLs = [
            URL(string: "http://api.libreview.io")!,
            URL(string: "https://api.example.test")!
        ]

        for baseURL in badURLs {
            let transport = MockHTTPTransport(responses: [response(fixture: "login-success")])
            let api = LibreLinkUpAPI(
                transport: transport,
                configuration: LibreLinkUpConfiguration(entryBaseURL: baseURL)
            )
            await assertLoginError(.invalidConfiguration, from: api)
            let requests = await transport.recordedRequests()
            XCTAssertEqual(requests.count, 0)
        }
    }

    func testServiceStatusFourRequiresTermsAcceptance() async {
        let transport = MockHTTPTransport(responses: [response(fixture: "login-terms-required")])
        await assertLoginError(.termsRequired, from: LibreLinkUpAPI(transport: transport))
    }

    func testServiceStatusAndHTTP429AreRateLimited() async {
        let serviceTransport = MockHTTPTransport(responses: [response(fixture: "login-rate-limited")])
        await assertLoginError(.rateLimited, from: LibreLinkUpAPI(transport: serviceTransport))

        let httpTransport = MockHTTPTransport(responses: [response(data: Data(), statusCode: 429)])
        await assertLoginError(.rateLimited, from: LibreLinkUpAPI(transport: httpTransport))
    }

    private var syntheticCredentials: Credentials {
        Credentials(email: "person@example.test", password: "synthetic-password")
    }

    private func assertLoginError(
        _ expected: LibreLinkUpError,
        from api: LibreLinkUpAPI,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await api.login(credentials: syntheticCredentials)
            XCTFail("Expected login to fail", file: file, line: line)
        } catch let error as LibreLinkUpError {
            XCTAssertEqual(error, expected, file: file, line: line)
        } catch {
            XCTFail("Unexpected error type: \(type(of: error))", file: file, line: line)
        }
    }

    private func response(fixture name: String, statusCode: Int = 200) -> MockHTTPTransport.Stub {
        response(data: fixtureData(name), statusCode: statusCode)
    }

    private func response(data: Data, statusCode: Int = 200) -> MockHTTPTransport.Stub {
        let url = URL(string: "https://api.libreview.io")!
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        return .success(data, response)
    }

    private func fixtureData(_ name: String) -> Data {
        let url = Bundle.module.url(forResource: name, withExtension: "json")!
        return try! Data(contentsOf: url)
    }
}

private actor MockHTTPTransport: HTTPTransport {
    enum Stub: @unchecked Sendable {
        case success(Data, HTTPURLResponse)
        case failure(Error)
    }

    private var stubs: [Stub]
    private var requests: [URLRequest] = []

    init(responses: [Stub]) {
        stubs = responses
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        guard !stubs.isEmpty else {
            throw URLError(.badServerResponse)
        }
        switch stubs.removeFirst() {
        case let .success(data, response):
            return (data, response)
        case let .failure(error):
            throw error
        }
    }

    func recordedRequests() -> [URLRequest] {
        requests
    }
}
