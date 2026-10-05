import Foundation

public enum CredentialStoreError: Error, Equatable, Sendable {
    case storageFailure
}

extension CredentialStoreError: LocalizedError {
    public var errorDescription: String? {
        "Secure account storage could not be accessed."
    }
}

public protocol CredentialStoreProtocol: Sendable {
    func credentials() async throws -> Credentials?
    func saveCredentials(_ credentials: Credentials) async throws
    func clearCredentials() async throws

    func session() async throws -> AuthSession?
    func saveSession(_ session: AuthSession) async throws
    func clearSession() async throws

    func connection() async throws -> Connection?
    func saveConnection(_ connection: Connection) async throws
    func clearConnection() async throws
}

public actor MemoryCredentialStore: CredentialStoreProtocol {
    private var storedCredentials: Credentials?
    private var storedSession: AuthSession?
    private var storedConnection: Connection?

    public init(
        credentials: Credentials? = nil,
        session: AuthSession? = nil,
        connection: Connection? = nil
    ) {
        self.storedCredentials = credentials
        self.storedSession = session
        self.storedConnection = connection
    }

    public func credentials() async throws -> Credentials? {
        storedCredentials
    }

    public func saveCredentials(_ credentials: Credentials) async throws {
        storedCredentials = credentials
    }

    public func clearCredentials() async throws {
        storedCredentials = nil
    }

    public func session() async throws -> AuthSession? {
        storedSession
    }

    public func saveSession(_ session: AuthSession) async throws {
        storedSession = session
    }

    public func clearSession() async throws {
        storedSession = nil
    }

    public func connection() async throws -> Connection? {
        storedConnection
    }

    public func saveConnection(_ connection: Connection) async throws {
        storedConnection = connection
    }

    public func clearConnection() async throws {
        storedConnection = nil
    }
}
