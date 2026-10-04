import Foundation

public struct Credentials: Equatable, Sendable {
    public let email: String
    public let password: String

    public init(email: String, password: String) {
        self.email = email
        self.password = password
    }
}

public struct AuthSession: Codable, Equatable, Sendable {
    public let token: String
    public let userID: String
    public let expiresAt: Date
    public let baseURL: URL

    public init(token: String, userID: String, expiresAt: Date, baseURL: URL) {
        self.token = token
        self.userID = userID
        self.expiresAt = expiresAt
        self.baseURL = baseURL
    }
}

public struct Connection: Codable, Equatable, Sendable {
    public let patientID: String

    public init(patientID: String) {
        self.patientID = patientID
    }

    private enum CodingKeys: String, CodingKey {
        case patientID = "patientId"
    }
}

public struct LibreLinkUpConfiguration: Equatable, Sendable {
    public let entryBaseURL: URL
    public let product: String
    public let version: String

    public init(
        entryBaseURL: URL = URL(string: "https://api.libreview.io")!,
        product: String = "llu.ios",
        version: String = "4.16.0"
    ) {
        self.entryBaseURL = entryBaseURL
        self.product = product
        self.version = version
    }
}

struct LoginPayload: Encodable {
    let email: String
    let password: String
}

struct LoginResponse: Decodable {
    let status: Int
    let data: LoginData?
}

struct LoginData: Decodable {
    let redirect: Bool?
    let region: String?
    let user: LoginUser?
    let authTicket: LoginTicket?
}

struct LoginUser: Decodable {
    let id: String
}

struct LoginTicket: Decodable {
    let token: String
    let expires: TimeInterval
}

struct ConnectionsResponse: Decodable {
    let status: Int
    let data: [Connection]?
}

struct GraphResponse: Decodable {
    let status: Int
    let data: GraphData?
}

struct GraphData: Decodable {
    let connection: GraphConnection?
}

struct GraphConnection: Decodable {
    let uom: Int?
    let glucoseMeasurement: LibreGlucoseMeasurement?
}

struct LibreGlucoseMeasurement: Decodable {
    let factoryTimestamp: String?
    let timestamp: String?
    let value: Decimal?
    let trendArrow: Int?
    let glucoseUnits: Int?

    private enum CodingKeys: String, CodingKey {
        case factoryTimestamp = "FactoryTimestamp"
        case timestamp = "Timestamp"
        case value = "Value"
        case trendArrow = "TrendArrow"
        case glucoseUnits = "GlucoseUnits"
    }
}
