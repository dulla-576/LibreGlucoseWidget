import Foundation
import XCTest
@testable import LibreGlucoseCore

final class SecretRedactionTests: XCTestCase {
    func testPublicErrorsAndOutcomesDoNotExposeSensitiveSentinels() {
        let sentinels = [
            "sentinel-email@example.test",
            "sentinel-password",
            "sentinel-token",
            "sentinel-patient-id",
            "sentinel-glucose-body"
        ]
        let values: [Any] = [
            LibreLinkUpError.invalidConfiguration,
            LibreLinkUpError.invalidRegion,
            LibreLinkUpError.invalidCredentials,
            LibreLinkUpError.termsRequired,
            LibreLinkUpError.rateLimited,
            LibreLinkUpError.unauthorized,
            LibreLinkUpError.noConnections,
            LibreLinkUpError.malformedResponse,
            LibreLinkUpError.httpStatus(500),
            LibreLinkUpError.serviceStatus(9),
            LibreLinkUpError.transportFailure,
            ReadingCacheError.cacheFailure,
            CredentialStoreError.storageFailure,
            RefreshOutcome.failed(.libreLinkUp(.malformedResponse))
        ]

        for value in values {
            let description = String(describing: value)
            for sentinel in sentinels {
                XCTAssertFalse(description.contains(sentinel), "Leaked sentinel from \(type(of: value))")
            }
        }
    }
}
