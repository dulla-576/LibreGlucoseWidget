import LibreGlucoseCore
import XCTest

final class ProjectIntegrationTests: XCTestCase {
    func testGeneratedProjectLinksCorePackage() {
        XCTAssertEqual(LibreGlucoseCore.version, "0.1.0")
    }
}
