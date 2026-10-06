import Foundation
import LibreGlucoseCore

enum SharedContainerError: Error, LocalizedError {
    case appGroupUnavailable
    case keychainGroupUnavailable

    var errorDescription: String? {
        switch self {
        case .appGroupUnavailable:
            "The shared App Group is unavailable. Check the signing entitlements."
        case .keychainGroupUnavailable:
            "The shared Keychain group is unavailable. Check the signing entitlements."
        }
    }
}

enum SharedContainer {
    static let appGroupIdentifier = "group.com.abdullah.libreglucosewidget"
    static let keychainService = "com.abdullah.libreglucosewidget.librelinkup"
    static let widgetKind = "LibreGlucoseLockWidget"

    static func makeCredentialStore(bundle: Bundle = .main) throws -> KeychainCredentialStore {
        guard let accessGroup = bundle.object(forInfoDictionaryKey: "LibreKeychainAccessGroup") as? String,
              !accessGroup.isEmpty,
              !accessGroup.contains("$(") else {
            throw SharedContainerError.keychainGroupUnavailable
        }
        return KeychainCredentialStore(service: keychainService, accessGroup: accessGroup)
    }

    static func makeReadingCache(fileManager: FileManager = .default) throws -> ProtectedReadingCache {
        guard let containerURL = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            throw SharedContainerError.appGroupUnavailable
        }
        return ProtectedReadingCache(
            fileURL: containerURL.appendingPathComponent("latest-reading.json")
        )
    }
}

actor ProtectedReadingCache: ReadingCacheProtocol {
    private let cache: FileReadingCache
    private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
        self.cache = FileReadingCache(fileURL: fileURL)
    }

    func load() async throws -> GlucoseReading? {
        try await cache.load()
    }

    func save(_ reading: GlucoseReading) async throws {
        try await cache.save(reading)
        do {
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: fileURL.path
            )
        } catch {
            try? await cache.clear()
            throw ReadingCacheError.cacheFailure
        }
    }

    func clear() async throws {
        try await cache.clear()
    }
}
