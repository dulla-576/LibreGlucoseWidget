import XCTest
@testable import LibreGlucoseCore

final class ScaffoldTests: XCTestCase {
    func testCoreModuleLoads() {
        XCTAssertEqual(LibreGlucoseCore.version, "0.1.0")
    }
}
