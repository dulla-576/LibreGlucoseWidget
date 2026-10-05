import Foundation
import Security
import XCTest
@testable import LibreGlucoseCore

final class KeychainQueryTests: XCTestCase {
    func testAddQueryUsesDeviceOnlyAfterFirstUnlockAndSharedAccessGroup() {
        let builder = KeychainQueryBuilder(
            service: "com.example.libreglucose",
            accessGroup: "TEAMID.group.com.example.libreglucose"
        )
        let query = builder.addQuery(for: .credentials, data: Data("opaque".utf8))

        XCTAssertEqual(query[kSecClass as String] as? String, kSecClassGenericPassword as String)
        XCTAssertEqual(query[kSecAttrService as String] as? String, "com.example.libreglucose")
        XCTAssertEqual(query[kSecAttrAccount as String] as? String, "credentials")
        XCTAssertEqual(
            query[kSecAttrAccessGroup as String] as? String,
            "TEAMID.group.com.example.libreglucose"
        )
        XCTAssertEqual(
            query[kSecAttrAccessible as String] as? String,
            kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String
        )
        XCTAssertEqual(query[kSecValueData as String] as? Data, Data("opaque".utf8))
        XCTAssertNil(query[kSecAttrSynchronizable as String])
    }

    func testReadQueryRequestsOneDataResultWithoutICloudSynchronization() {
        let builder = KeychainQueryBuilder(
            service: "com.example.libreglucose",
            accessGroup: "TEAMID.group.com.example.libreglucose"
        )
        let query = builder.readQuery(for: .session)

        XCTAssertEqual(query[kSecReturnData as String] as? Bool, true)
        XCTAssertEqual(query[kSecMatchLimit as String] as? String, kSecMatchLimitOne as String)
        XCTAssertNil(query[kSecAttrSynchronizable as String])
    }

    func testDeletionQueriesTargetOnlyCredentialOrSessionRecord() {
        let builder = KeychainQueryBuilder(
            service: "com.example.libreglucose",
            accessGroup: "TEAMID.group.com.example.libreglucose"
        )

        let credentialQuery = builder.deletionQuery(for: .credentials)
        let sessionQuery = builder.deletionQuery(for: .session)

        XCTAssertEqual(credentialQuery[kSecAttrAccount as String] as? String, "credentials")
        XCTAssertEqual(sessionQuery[kSecAttrAccount as String] as? String, "session")
        XCTAssertEqual(credentialQuery[kSecAttrAccessGroup as String] as? String, sessionQuery[kSecAttrAccessGroup as String] as? String)
        XCTAssertNil(credentialQuery[kSecValueData as String])
        XCTAssertNil(sessionQuery[kSecValueData as String])
        XCTAssertNil(credentialQuery[kSecReturnData as String])
        XCTAssertNil(sessionQuery[kSecReturnData as String])
    }
}
