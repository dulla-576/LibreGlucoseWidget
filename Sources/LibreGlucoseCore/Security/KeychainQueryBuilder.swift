import Foundation
import Security

public enum KeychainRecord: String, CaseIterable, Sendable {
    case credentials
    case session
    case connection
}

public struct KeychainQueryBuilder: Sendable {
    public let service: String
    public let accessGroup: String

    public init(service: String, accessGroup: String) {
        self.service = service
        self.accessGroup = accessGroup
    }

    public func addQuery(for record: KeychainRecord, data: Data) -> [String: Any] {
        var query = baseQuery(for: record)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        query[kSecValueData as String] = data
        return query
    }

    public func readQuery(for record: KeychainRecord) -> [String: Any] {
        var query = baseQuery(for: record)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        return query
    }

    public func deletionQuery(for record: KeychainRecord) -> [String: Any] {
        baseQuery(for: record)
    }

    public func updateAttributes(data: Data) -> [String: Any] {
        [kSecValueData as String: data]
    }

    private func baseQuery(for record: KeychainRecord) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: record.rawValue,
            kSecAttrAccessGroup as String: accessGroup
        ]
    }
}
