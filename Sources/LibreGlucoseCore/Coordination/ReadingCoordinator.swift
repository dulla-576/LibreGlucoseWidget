import Foundation

public enum RefreshOutcome: Equatable, Sendable {
    case updated(GlucoseReading)
    case cached(GlucoseReading)
    case signedOut
    case failed
}

public actor ReadingCoordinator {
    private let dataSource: any GlucoseDataSource
    private let credentialStore: any CredentialStoreProtocol
    private let readingCache: any ReadingCacheProtocol

    public init(
        dataSource: any GlucoseDataSource,
        credentialStore: any CredentialStoreProtocol,
        readingCache: any ReadingCacheProtocol
    ) {
        self.dataSource = dataSource
        self.credentialStore = credentialStore
        self.readingCache = readingCache
    }

    public func refresh() async -> RefreshOutcome {
        let credentials: Credentials
        let session: AuthSession?
        do {
            guard let storedCredentials = try await credentialStore.credentials() else {
                return .signedOut
            }
            credentials = storedCredentials
            session = try await credentialStore.session()
        } catch {
            return await cachedOrFailed()
        }

        do {
            let result = try await dataSource.fetchLatest(credentials: credentials, session: session)
            try await persist(result)
            return .updated(result.reading)
        } catch LibreLinkUpError.unauthorized {
            do {
                try await credentialStore.clearSession()
                let result = try await dataSource.fetchLatest(credentials: credentials, session: nil)
                try await persist(result)
                return .updated(result.reading)
            } catch {
                return await cachedOrFailed()
            }
        } catch {
            return await cachedOrFailed()
        }
    }

    public func signOut() async -> RefreshOutcome {
        var failed = false

        do { try await credentialStore.clearCredentials() } catch { failed = true }
        do { try await credentialStore.clearSession() } catch { failed = true }
        do { try await credentialStore.clearConnection() } catch { failed = true }
        do { try await readingCache.clear() } catch { failed = true }

        return failed ? .failed : .signedOut
    }

    private func persist(_ result: FetchResult) async throws {
        try await credentialStore.saveSession(result.session)
        try await credentialStore.saveConnection(result.connection)
        try await readingCache.save(result.reading)
    }

    private func cachedOrFailed() async -> RefreshOutcome {
        do {
            if let reading = try await readingCache.load() {
                return .cached(reading)
            }
        } catch {
            return .failed
        }
        return .failed
    }
}
