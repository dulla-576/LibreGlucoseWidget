import Foundation
import XCTest
@testable import LibreGlucoseCore

final class ReadingCacheTests: XCTestCase {
    func testFileCacheRoundTripsAndAtomicallyReplacesReading() async throws {
        let location = temporaryDirectory().appendingPathComponent("reading.json")
        let cache = FileReadingCache(fileURL: location)
        let first = reading(value: 111)
        let replacement = reading(value: 123)

        try await cache.save(first)
        let loadedFirst = try await cache.load()
        XCTAssertEqual(loadedFirst, first)

        try await cache.save(replacement)
        let loadedReplacement = try await cache.load()
        XCTAssertEqual(loadedReplacement, replacement)
        XCTAssertEqual(
            try FileManager.default.contentsOfDirectory(atPath: location.deletingLastPathComponent().path),
            ["reading.json"]
        )
    }

    func testCorruptCacheThrowsTypedFailureWithoutCrashing() async throws {
        let directory = temporaryDirectory()
        let location = directory.appendingPathComponent("reading.json")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("definitely-not-json".utf8).write(to: location)
        let cache = FileReadingCache(fileURL: location)

        do {
            _ = try await cache.load()
            XCTFail("Expected cacheFailure")
        } catch let error as ReadingCacheError {
            XCTAssertEqual(error, .cacheFailure)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("LibreGlucoseCoreTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    private func reading(value: Decimal) -> GlucoseReading {
        GlucoseReading(
            value: value,
            unit: .mgDL,
            trend: .steady,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            connectionID: "patient-1"
        )
    }
}
