import Foundation

public struct FetchResult: Equatable, Sendable {
    public let reading: GlucoseReading
    public let session: AuthSession
    public let connection: Connection

    public init(reading: GlucoseReading, session: AuthSession, connection: Connection) {
        self.reading = reading
        self.session = session
        self.connection = connection
    }
}

public protocol GlucoseDataSource: Sendable {
    func fetchLatest(credentials: Credentials, session: AuthSession?) async throws -> FetchResult
}

public struct LibreLinkUpDataSource: GlucoseDataSource, Sendable {
    private let api: LibreLinkUpAPI
    private let now: @Sendable () -> Date

    public init(
        api: LibreLinkUpAPI = LibreLinkUpAPI(),
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.api = api
        self.now = now
    }

    public func fetchLatest(
        credentials: Credentials,
        session: AuthSession?
    ) async throws -> FetchResult {
        let activeSession: AuthSession
        if let session, session.expiresAt > now() {
            activeSession = session
        } else {
            activeSession = try await api.login(credentials: credentials)
        }

        let connection = try await api.firstConnection(session: activeSession)
        let reading = try await api.latestReading(session: activeSession, connection: connection)
        return FetchResult(reading: reading, session: activeSession, connection: connection)
    }
}
