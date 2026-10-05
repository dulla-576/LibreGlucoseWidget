import Foundation

public enum ReadingCacheError: Error, Equatable, Sendable {
    case cacheFailure
}

extension ReadingCacheError: LocalizedError {
    public var errorDescription: String? {
        "The saved glucose reading could not be accessed."
    }
}

public protocol ReadingCacheProtocol: Sendable {
    func load() async throws -> GlucoseReading?
    func save(_ reading: GlucoseReading) async throws
    func clear() async throws
}

public actor FileReadingCache: ReadingCacheProtocol {
    private let fileURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(fileURL: URL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    public func load() async throws -> GlucoseReading? {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        do {
            return try decoder.decode(GlucoseReading.self, from: Data(contentsOf: fileURL))
        } catch {
            throw ReadingCacheError.cacheFailure
        }
    }

    public func save(_ reading: GlucoseReading) async throws {
        let directory = fileURL.deletingLastPathComponent()
        let temporaryURL = directory.appendingPathComponent(".\(fileURL.lastPathComponent).\(UUID().uuidString).tmp")

        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try encoder.encode(reading)
            try data.write(to: temporaryURL)
            if fileManager.fileExists(atPath: fileURL.path) {
                _ = try fileManager.replaceItemAt(fileURL, withItemAt: temporaryURL)
            } else {
                try fileManager.moveItem(at: temporaryURL, to: fileURL)
            }
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
            throw ReadingCacheError.cacheFailure
        }
    }

    public func clear() async throws {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return
        }
        do {
            try fileManager.removeItem(at: fileURL)
        } catch {
            throw ReadingCacheError.cacheFailure
        }
    }
}
