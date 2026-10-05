import Foundation
import CryptoKit

public struct LibreLinkUpAPI: Sendable {
    private let transport: any HTTPTransport
    private let configuration: LibreLinkUpConfiguration
    private let localTimestampParser: LibreTimestampParser
    private let utcTimestampParser = LibreTimestampParser(timeZone: TimeZone(secondsFromGMT: 0)!)

    public init(
        transport: any HTTPTransport = URLSessionTransport(),
        configuration: LibreLinkUpConfiguration = LibreLinkUpConfiguration(),
        localTimeZone: TimeZone = .current
    ) {
        self.transport = transport
        self.configuration = configuration
        self.localTimestampParser = LibreTimestampParser(timeZone: localTimeZone)
    }

    public func login(credentials: Credentials) async throws -> AuthSession {
        guard Self.isAllowed(baseURL: configuration.entryBaseURL) else {
            throw LibreLinkUpError.invalidConfiguration
        }
        return try await login(credentials: credentials, baseURL: configuration.entryBaseURL, mayRedirect: true)
    }

    public func firstConnection(session: AuthSession) async throws -> Connection {
        let request = try authorizedRequest(
            session: session,
            pathComponents: ["llu", "connections"]
        )
        let data = try await sendAuthorized(request)
        let envelope: ConnectionsResponse = try decode(data)
        try validateServiceStatus(envelope.status)
        guard let connection = envelope.data?.first else {
            throw LibreLinkUpError.noConnections
        }
        return connection
    }

    public func latestReading(
        session: AuthSession,
        connection: Connection
    ) async throws -> GlucoseReading {
        guard !connection.patientID.isEmpty else {
            throw LibreLinkUpError.malformedResponse
        }
        let request = try authorizedRequest(
            session: session,
            pathComponents: ["llu", "connections", connection.patientID, "graph"]
        )
        let data = try await sendAuthorized(request)
        let envelope: GraphResponse = try decode(data)
        try validateServiceStatus(envelope.status)

        guard let graphConnection = envelope.data?.connection,
              let measurement = graphConnection.glucoseMeasurement,
              let value = measurement.value,
              let trend = measurement.trendArrow,
              let rawUnit = measurement.glucoseUnits ?? graphConnection.uom,
              let unit = Self.unit(from: rawUnit),
              let timestamp = parsedTimestamp(measurement) else {
            throw LibreLinkUpError.malformedResponse
        }

        return GlucoseReading(
            value: value,
            unit: unit,
            trend: GlucoseTrend(libreLinkUpValue: trend),
            timestamp: timestamp,
            connectionID: connection.patientID
        )
    }

    private func login(
        credentials: Credentials,
        baseURL: URL,
        mayRedirect: Bool
    ) async throws -> AuthSession {
        var request = URLRequest(url: baseURL.appendingPathComponent("llu/auth/login"))
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(
            LoginPayload(email: credentials.email, password: credentials.password)
        )
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(configuration.product, forHTTPHeaderField: "product")
        request.setValue(configuration.version, forHTTPHeaderField: "version")
        request.setValue("no-cache", forHTTPHeaderField: "cache-control")

        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await transport.send(request)
        } catch let error as LibreLinkUpError {
            throw error
        } catch {
            throw LibreLinkUpError.transportFailure
        }

        if response.statusCode == 429 {
            throw LibreLinkUpError.rateLimited
        }
        if response.statusCode == 401 || response.statusCode == 403 {
            throw LibreLinkUpError.invalidCredentials
        }
        guard (200..<300).contains(response.statusCode) else {
            throw LibreLinkUpError.httpStatus(response.statusCode)
        }

        let envelope: LoginResponse
        do {
            envelope = try JSONDecoder().decode(LoginResponse.self, from: data)
        } catch {
            throw LibreLinkUpError.malformedResponse
        }

        switch envelope.status {
        case 0:
            break
        case 4:
            throw LibreLinkUpError.termsRequired
        case 429:
            throw LibreLinkUpError.rateLimited
        case 2:
            throw LibreLinkUpError.invalidCredentials
        default:
            throw LibreLinkUpError.serviceStatus(envelope.status)
        }

        if envelope.data?.redirect == true || envelope.data?.region != nil && envelope.data?.authTicket == nil {
            guard mayRedirect,
                  let region = envelope.data?.region,
                  Self.isValid(region: region),
                  let regionalURL = URL(string: "https://api-\(region).libreview.io"),
                  Self.isAllowed(baseURL: regionalURL) else {
                throw LibreLinkUpError.invalidRegion
            }
            return try await login(credentials: credentials, baseURL: regionalURL, mayRedirect: false)
        }

        guard let ticket = envelope.data?.authTicket,
              let user = envelope.data?.user,
              !ticket.token.isEmpty,
              !user.id.isEmpty else {
            throw LibreLinkUpError.malformedResponse
        }

        return AuthSession(
            token: ticket.token,
            userID: user.id,
            expiresAt: Date(timeIntervalSince1970: ticket.expires),
            baseURL: baseURL
        )
    }

    private static func isValid(region: String) -> Bool {
        !region.isEmpty && region.unicodeScalars.allSatisfy {
            CharacterSet.alphanumerics.contains($0) || $0 == "-"
        }
    }

    private static func isAllowed(baseURL: URL) -> Bool {
        guard baseURL.scheme == "https", let host = baseURL.host else {
            return false
        }
        if host == "api.libreview.io" {
            return true
        }
        let suffix = ".libreview.io"
        guard host.hasPrefix("api-"), host.hasSuffix(suffix) else {
            return false
        }
        let region = String(host.dropFirst("api-".count).dropLast(suffix.count))
        return isValid(region: region)
    }

    private func authorizedRequest(
        session: AuthSession,
        pathComponents: [String]
    ) throws -> URLRequest {
        guard Self.isAllowed(baseURL: session.baseURL) else {
            throw LibreLinkUpError.invalidConfiguration
        }
        let url = pathComponents.reduce(session.baseURL) { partialURL, component in
            partialURL.appendingPathComponent(component)
        }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(configuration.product, forHTTPHeaderField: "product")
        request.setValue(configuration.version, forHTTPHeaderField: "version")
        request.setValue("no-cache", forHTTPHeaderField: "cache-control")
        request.setValue("Bearer \(session.token)", forHTTPHeaderField: "authorization")
        request.setValue(Self.sha256(session.userID), forHTTPHeaderField: "account-id")
        return request
    }

    private func sendAuthorized(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await transport.send(request)
        } catch let error as LibreLinkUpError {
            throw error
        } catch {
            throw LibreLinkUpError.transportFailure
        }

        if response.statusCode == 429 {
            throw LibreLinkUpError.rateLimited
        }
        if response.statusCode == 401 || response.statusCode == 403 {
            throw LibreLinkUpError.unauthorized
        }
        guard (200..<300).contains(response.statusCode) else {
            throw LibreLinkUpError.httpStatus(response.statusCode)
        }
        return data
    }

    private func decode<Response: Decodable>(_ data: Data) throws -> Response {
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw LibreLinkUpError.malformedResponse
        }
    }

    private func validateServiceStatus(_ status: Int) throws {
        switch status {
        case 0:
            return
        case 429:
            throw LibreLinkUpError.rateLimited
        default:
            throw LibreLinkUpError.serviceStatus(status)
        }
    }

    private func parsedTimestamp(_ measurement: LibreGlucoseMeasurement) -> Date? {
        if let factoryTimestamp = measurement.factoryTimestamp,
           let date = utcTimestampParser.parse(factoryTimestamp) {
            return date
        }
        if let timestamp = measurement.timestamp {
            return localTimestampParser.parse(timestamp)
        }
        return nil
    }

    private static func unit(from rawValue: Int) -> GlucoseUnit? {
        switch rawValue {
        case 0: .mmolL
        case 1: .mgDL
        default: nil
        }
    }

    private static func sha256(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
