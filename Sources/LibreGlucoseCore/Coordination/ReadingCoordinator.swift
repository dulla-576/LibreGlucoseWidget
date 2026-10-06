import Foundation

public enum RefreshOutcome: Equatable, Sendable {
    case updated(GlucoseReading)
    case cached(GlucoseReading)
    case signedOut
    case failed(RefreshFailure)
}

public enum RefreshFailure: Equatable, Sendable {
    case libreLinkUp(LibreLinkUpError)
    case secureStorage
    case unknown

    public var userMessage: String {
        switch self {
        case let .libreLinkUp(error):
            error.errorDescription ?? "LibreLinkUp could not load the latest reading."
        case .secureStorage:
            "Secure storage could not be read or updated."
        case .unknown:
            "The latest reading could not be loaded."
        }
    }
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
            return await cachedOrFailed(after: error)
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
                return await cachedOrFailed(after: error)
            }
        } catch {
            return await cachedOrFailed(after: error)
        }
    }

    public func signOut() async -> RefreshOutcome {
        var failed = false

        do { try await credentialStore.clearCredentials() } catch { failed = true }
        do { try await credentialStore.clearSession() } catch { failed = true }
        do { try await credentialStore.clearConnection() } catch { failed = true }
        do { try await readingCache.clear() } catch { failed = true }

        return failed ? .failed(.secureStorage) : .signedOut
    }

    private func persist(_ result: FetchResult) async throws {
        try await credentialStore.saveSession(result.session)
        try await credentialStore.saveConnection(result.connection)
        try await readingCache.save(result.reading)
    }

    private func cachedOrFailed(after error: Error) async -> RefreshOutcome {
        do {
            if let reading = try await readingCache.load() {
                return .cached(reading)
            }
        } catch {
            return .failed(.secureStorage)
        }
        return .failed(Self.failure(from: error))
    }

    private static func failure(from error: Error) -> RefreshFailure {
        if let libreLinkUpError = error as? LibreLinkUpError {
            return .libreLinkUp(libreLinkUpError)
        }
        if error is CredentialStoreError || error is ReadingCacheError {
            return .secureStorage
        }
        return .unknown
    }
}
