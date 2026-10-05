import Foundation
import XCTest
@testable import LibreGlucoseCore

final class ReadingCoordinatorTests: XCTestCase {
    func testSuccessfulRefreshStoresSessionConnectionAndReading() async throws {
        let store = MemoryCredentialStore(credentials: credentials)
        let cache = MemoryReadingCache()
        let source = QueueDataSource(results: [.success(fetchResult)])
        let coordinator = ReadingCoordinator(dataSource: source, credentialStore: store, readingCache: cache)

        let outcome = await coordinator.refresh()
        let storedSession = try await store.session()
        let storedConnection = try await store.connection()
        let storedReading = try await cache.load()

        XCTAssertEqual(outcome, .updated(reading))
        XCTAssertEqual(storedSession, freshSession)
        XCTAssertEqual(storedConnection, connection)
        XCTAssertEqual(storedReading, reading)
    }

    func testUnauthorizedSessionIsClearedThenReauthenticatedExactlyOnce() async throws {
        let store = MemoryCredentialStore(
            credentials: credentials,
            session: expiredSession,
            connection: Connection(patientID: "old-patient")
        )
        let cache = MemoryReadingCache()
        let source = QueueDataSource(results: [
            .failure(LibreLinkUpError.unauthorized),
            .success(fetchResult)
        ])
        let coordinator = ReadingCoordinator(dataSource: source, credentialStore: store, readingCache: cache)

        let outcome = await coordinator.refresh()
        let receivedSessions = await source.receivedSessions()
        let storedCredentials = try await store.credentials()
        let storedSession = try await store.session()
        let storedConnection = try await store.connection()

        XCTAssertEqual(outcome, .updated(reading))
        XCTAssertEqual(receivedSessions, [expiredSession, nil])
        XCTAssertEqual(storedCredentials, credentials)
        XCTAssertEqual(storedSession, freshSession)
        XCTAssertEqual(storedConnection, connection)
    }

    func testSecondUnauthorizedResultStopsWithoutAThirdAttempt() async {
        let store = MemoryCredentialStore(credentials: credentials, session: expiredSession)
        let cache = MemoryReadingCache()
        let source = QueueDataSource(results: [
            .failure(LibreLinkUpError.unauthorized),
            .failure(LibreLinkUpError.unauthorized)
        ])
        let coordinator = ReadingCoordinator(dataSource: source, credentialStore: store, readingCache: cache)

        let outcome = await coordinator.refresh()
        let callCount = await source.callCount()

        XCTAssertEqual(outcome, .failed)
        XCTAssertEqual(callCount, 2)
    }

    func testNetworkFailureReturnsLastCachedReading() async throws {
        let store = MemoryCredentialStore(credentials: credentials, session: freshSession)
        let cache = MemoryReadingCache(reading: cachedReading)
        let source = QueueDataSource(results: [.failure(LibreLinkUpError.transportFailure)])
        let coordinator = ReadingCoordinator(dataSource: source, credentialStore: store, readingCache: cache)

        let outcome = await coordinator.refresh()
        let storedReading = try await cache.load()

        XCTAssertEqual(outcome, .cached(cachedReading))
        XCTAssertEqual(storedReading, cachedReading)
    }

    func testRefreshWithoutCredentialsIsSignedOut() async {
        let store = MemoryCredentialStore()
        let cache = MemoryReadingCache(reading: cachedReading)
        let source = QueueDataSource(results: [])
        let coordinator = ReadingCoordinator(dataSource: source, credentialStore: store, readingCache: cache)

        let outcome = await coordinator.refresh()
        let callCount = await source.callCount()

        XCTAssertEqual(outcome, .signedOut)
        XCTAssertEqual(callCount, 0)
    }

    func testSignOutClearsCredentialsSessionConnectionAndReading() async throws {
        let store = MemoryCredentialStore(
            credentials: credentials,
            session: freshSession,
            connection: connection
        )
        let cache = MemoryReadingCache(reading: reading)
        let source = QueueDataSource(results: [])
        let coordinator = ReadingCoordinator(dataSource: source, credentialStore: store, readingCache: cache)

        let outcome = await coordinator.signOut()
        let storedCredentials = try await store.credentials()
        let storedSession = try await store.session()
        let storedConnection = try await store.connection()
        let storedReading = try await cache.load()

        XCTAssertEqual(outcome, .signedOut)
        XCTAssertNil(storedCredentials)
        XCTAssertNil(storedSession)
        XCTAssertNil(storedConnection)
        XCTAssertNil(storedReading)
    }

    private var credentials: Credentials {
        Credentials(email: "person@example.test", password: "synthetic-password")
    }

    private var expiredSession: AuthSession {
        AuthSession(
            token: "expired-token",
            userID: "synthetic-user",
            expiresAt: Date(timeIntervalSince1970: 1_600_000_000),
            baseURL: URL(string: "https://api-eu2.libreview.io")!
        )
    }

    private var freshSession: AuthSession {
        AuthSession(
            token: "fresh-token",
            userID: "synthetic-user",
            expiresAt: Date(timeIntervalSince1970: 1_900_000_000),
            baseURL: URL(string: "https://api-eu2.libreview.io")!
        )
    }

    private var connection: Connection {
        Connection(patientID: "patient-1")
    }

    private var reading: GlucoseReading {
        GlucoseReading(
            value: 123,
            unit: .mgDL,
            trend: .steady,
            timestamp: Date(timeIntervalSince1970: 1_800_000_000),
            connectionID: "patient-1"
        )
    }

    private var cachedReading: GlucoseReading {
        GlucoseReading(
            value: 119,
            unit: .mgDL,
            trend: .slowlyFalling,
            timestamp: Date(timeIntervalSince1970: 1_799_999_700),
            connectionID: "patient-1"
        )
    }

    private var fetchResult: FetchResult {
        FetchResult(reading: reading, session: freshSession, connection: connection)
    }
}

private actor QueueDataSource: GlucoseDataSource {
    private var results: [Result<FetchResult, Error>]
    private var sessions: [AuthSession?] = []

    init(results: [Result<FetchResult, Error>]) {
        self.results = results
    }

    func fetchLatest(credentials: Credentials, session: AuthSession?) async throws -> FetchResult {
        sessions.append(session)
        guard !results.isEmpty else {
            throw LibreLinkUpError.transportFailure
        }
        return try results.removeFirst().get()
    }

    func receivedSessions() -> [AuthSession?] {
        sessions
    }

    func callCount() -> Int {
        sessions.count
    }
}

private actor MemoryReadingCache: ReadingCacheProtocol {
    private var reading: GlucoseReading?

    init(reading: GlucoseReading? = nil) {
        self.reading = reading
    }

    func load() async throws -> GlucoseReading? {
        reading
    }

    func save(_ reading: GlucoseReading) async throws {
        self.reading = reading
    }

    func clear() async throws {
        reading = nil
    }
}
