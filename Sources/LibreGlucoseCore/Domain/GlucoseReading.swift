import Foundation

public enum GlucoseUnit: String, Codable, Equatable, Sendable {
    case mgDL
    case mmolL

    public var displayText: String {
        switch self {
        case .mgDL: "mg/dL"
        case .mmolL: "mmol/L"
        }
    }
}

public enum GlucoseTrend: String, Codable, Equatable, Sendable {
    case rapidlyFalling
    case falling
    case slowlyFalling
    case steady
    case slowlyRising
    case rising
    case rapidlyRising
    case unknown

    public var arrow: String {
        switch self {
        case .rapidlyFalling: "↓↓"
        case .falling: "↓"
        case .slowlyFalling: "↘"
        case .steady: "→"
        case .slowlyRising: "↗"
        case .rising: "↑"
        case .rapidlyRising: "↑↑"
        case .unknown: "?"
        }
    }
}

public struct GlucoseReading: Codable, Equatable, Sendable {
    public let value: Decimal
    public let unit: GlucoseUnit
    public let trend: GlucoseTrend
    public let timestamp: Date
    public let connectionID: String?

    public init(
        value: Decimal,
        unit: GlucoseUnit,
        trend: GlucoseTrend,
        timestamp: Date,
        connectionID: String? = nil
    ) {
        self.value = value
        self.unit = unit
        self.trend = trend
        self.timestamp = timestamp
        self.connectionID = connectionID
    }
}
