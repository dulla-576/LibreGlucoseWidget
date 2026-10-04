import Foundation

public struct LibreLinkUpAPI: Sendable {
    private let transport: any HTTPTransport
    private let configuration: LibreLinkUpConfiguration

    public init(
        transport: any HTTPTransport = URLSessionTransport(),
        configuration: LibreLinkUpConfiguration = LibreLinkUpConfiguration()
    ) {
        self.transport = transport
        self.configuration = configuration
    }

    public func login(credentials: Credentials) async throws -> AuthSession {
        guard Self.isAllowed(baseURL: configuration.entryBaseURL) else {
            throw LibreLinkUpError.invalidConfiguration
        }
        return try await login(credentials: credentials, baseURL: configuration.entryBaseURL, mayRedirect: true)
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
        return host == "api.libreview.io"
            || host.hasPrefix("api-") && host.hasSuffix(".libreview.io")
    }
}
