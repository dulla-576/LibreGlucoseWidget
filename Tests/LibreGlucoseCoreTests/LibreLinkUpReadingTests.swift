import Foundation
import XCTest
@testable import LibreGlucoseCore

final class LibreLinkUpReadingTests: XCTestCase {
    func testFirstConnectionUsesAuthorizedHeadersAndSelectsFirstPatient() async throws {
        let transport = ReadingMockTransport(responses: [response(fixture: "connections-one")])
        let api = LibreLinkUpAPI(transport: transport)

        let connection = try await api.firstConnection(session: session)

        XCTAssertEqual(connection.patientID, "patient-1")
        XCTAssertEqual(connection.displayName, "Ada Lovelace")
        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests[0].url?.absoluteString, "https://api-eu2.libreview.io/llu/connections")
        XCTAssertEqual(requests[0].value(forHTTPHeaderField: "Authorization"), "Bearer synthetic-token")
        XCTAssertEqual(
            requests[0].value(forHTTPHeaderField: "Account-Id"),
            "14b2e141bf7cc394d669faf2cec08637d1003fe849a08cf0c43b8066677aeb6e"
        )
    }

    func testFirstConnectionThrowsWhenNoSharedProfileExists() async {
        let transport = ReadingMockTransport(responses: [response(fixture: "connections-empty")])
        let api = LibreLinkUpAPI(transport: transport)

        do {
            _ = try await api.firstConnection(session: session)
            XCTFail("Expected noConnections")
        } catch let error as LibreLinkUpError {
            XCTAssertEqual(error, .noConnections)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testLatestReadingPreservesMilligramsPerDeciliterAndBuildsGraphRequest() async throws {
        let transport = ReadingMockTransport(responses: [response(fixture: "graph-mgdl")])
        let api = LibreLinkUpAPI(transport: transport)

        let reading = try await api.latestReading(
            session: session,
            connection: Connection(patientID: "patient-1")
        )

        XCTAssertEqual(reading.value, Decimal(142))
        XCTAssertEqual(reading.unit, .mgDL)
        XCTAssertEqual(reading.trend, .rapidlyFalling)
        XCTAssertEqual(reading.timestamp, isoDate("2026-10-05T01:15:00Z"))
        XCTAssertEqual(reading.connectionID, "patient-1")
        let requests = await transport.recordedRequests()
        XCTAssertEqual(
            requests[0].url?.absoluteString,
            "https://api-eu2.libreview.io/llu/connections/patient-1/graph"
        )
        XCTAssertEqual(requests[0].value(forHTTPHeaderField: "Authorization"), "Bearer synthetic-token")
    }

    func testLatestReadingPreservesMillimolesPerLiter() async throws {
        let transport = ReadingMockTransport(responses: [response(fixture: "graph-mmoll")])
        let api = LibreLinkUpAPI(transport: transport)

        let reading = try await api.latestReading(
            session: session,
            connection: Connection(patientID: "patient-1")
        )

        XCTAssertEqual(reading.value, Decimal(string: "7.9", locale: Locale(identifier: "en_US_POSIX")))
        XCTAssertEqual(reading.unit, .mmolL)
        XCTAssertEqual(reading.trend, .rapidlyRising)
        XCTAssertEqual(reading.timestamp, isoDate("2026-10-05T01:15:00Z"))
    }

    func testLibreTrendMappingMatchesCurrentAPIValuesAndRejectsUnknownOnes() {
        XCTAssertEqual(GlucoseTrend(libreLinkUpValue: 1), .rapidlyFalling)
        XCTAssertEqual(GlucoseTrend(libreLinkUpValue: 2), .slowlyFalling)
        XCTAssertEqual(GlucoseTrend(libreLinkUpValue: 3), .steady)
        XCTAssertEqual(GlucoseTrend(libreLinkUpValue: 4), .slowlyRising)
        XCTAssertEqual(GlucoseTrend(libreLinkUpValue: 5), .rapidlyRising)
        XCTAssertEqual(GlucoseTrend(libreLinkUpValue: 0), .unknown)
        XCTAssertEqual(GlucoseTrend(libreLinkUpValue: 6), .unknown)
    }

    func testTimestampParserAcceptsISOAndLibreFormatsIncludingDST() throws {
        let utcParser = LibreTimestampParser(timeZone: TimeZone(secondsFromGMT: 0)!)
        XCTAssertEqual(utcParser.parse("2026-10-05T01:15:00Z"), isoDate("2026-10-05T01:15:00Z"))
        XCTAssertEqual(utcParser.parse("10/5/2026 1:15:00 AM"), isoDate("2026-10-05T01:15:00Z"))

        let berlin = try XCTUnwrap(TimeZone(identifier: "Europe/Berlin"))
        let berlinParser = LibreTimestampParser(timeZone: berlin)
        XCTAssertEqual(berlinParser.parse("3/29/2026 3:30:00 AM"), isoDate("2026-03-29T01:30:00Z"))
        XCTAssertNil(berlinParser.parse("not-a-date"))
    }

    private var session: AuthSession {
        AuthSession(
            token: "synthetic-token",
            userID: "synthetic-user",
            expiresAt: Date(timeIntervalSince1970: 1_800_000_000),
            baseURL: URL(string: "https://api-eu2.libreview.io")!
        )
    }

    private func response(fixture name: String, statusCode: Int = 200) -> ReadingMockTransport.Stub {
        let data = try! Data(contentsOf: Bundle.module.url(forResource: name, withExtension: "json")!)
        let url = URL(string: "https://api-eu2.libreview.io")!
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        return .success(data, response)
    }

    private func isoDate(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }
}

private actor ReadingMockTransport: HTTPTransport {
    enum Stub: @unchecked Sendable {
        case success(Data, HTTPURLResponse)
    }

    private var responses: [Stub]
    private var requests: [URLRequest] = []

    init(responses: [Stub]) {
        self.responses = responses
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        guard !responses.isEmpty else {
            throw URLError(.badServerResponse)
        }
        switch responses.removeFirst() {
        case let .success(data, response):
            return (data, response)
        }
    }

    func recordedRequests() -> [URLRequest] {
        requests
    }
}
