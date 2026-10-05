import Foundation
import LibreGlucoseCore
import Security

actor KeychainCredentialStore: CredentialStoreProtocol {
    private let queryBuilder: KeychainQueryBuilder
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(service: String, accessGroup: String) {
        self.queryBuilder = KeychainQueryBuilder(service: service, accessGroup: accessGroup)
    }

    func credentials() async throws -> Credentials? {
        try read(Credentials.self, record: .credentials)
    }

    func saveCredentials(_ credentials: Credentials) async throws {
        try write(credentials, record: .credentials)
    }

    func clearCredentials() async throws {
        try delete(record: .credentials)
    }

    func session() async throws -> AuthSession? {
        try read(AuthSession.self, record: .session)
    }

    func saveSession(_ session: AuthSession) async throws {
        try write(session, record: .session)
    }

    func clearSession() async throws {
        try delete(record: .session)
    }

    func connection() async throws -> Connection? {
        try read(Connection.self, record: .connection)
    }

    func saveConnection(_ connection: Connection) async throws {
        try write(connection, record: .connection)
    }

    func clearConnection() async throws {
        try delete(record: .connection)
    }

    private func read<Value: Decodable>(_ type: Value.Type, record: KeychainRecord) throws -> Value? {
        let query = queryBuilder.readQuery(for: record)
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess, let data = result as? Data else {
            throw CredentialStoreError.storageFailure
        }
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw CredentialStoreError.storageFailure
        }
    }

    private func write<Value: Encodable>(_ value: Value, record: KeychainRecord) throws {
        let data: Data
        do {
            data = try encoder.encode(value)
        } catch {
            throw CredentialStoreError.storageFailure
        }

        let deletionQuery = queryBuilder.deletionQuery(for: record)
        let updateStatus = SecItemUpdate(
            deletionQuery as CFDictionary,
            queryBuilder.updateAttributes(data: data) as CFDictionary
        )
        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw CredentialStoreError.storageFailure
        }

        let addStatus = SecItemAdd(queryBuilder.addQuery(for: record, data: data) as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw CredentialStoreError.storageFailure
        }
    }

    private func delete(record: KeychainRecord) throws {
        let status = SecItemDelete(queryBuilder.deletionQuery(for: record) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CredentialStoreError.storageFailure
        }
    }
}
