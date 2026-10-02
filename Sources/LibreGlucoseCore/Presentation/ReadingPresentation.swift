import Foundation

public enum ReadingFreshness: String, Codable, Equatable, Sendable {
    case fresh
    case delayed
    case stale

    public static func classify(age: TimeInterval) -> ReadingFreshness {
        let clampedAge = max(0, age)
        if clampedAge > 60 * 60 {
            return .stale
        }
        if clampedAge > 20 * 60 {
            return .delayed
        }
        return .fresh
    }
}

public struct ReadingPresentation: Equatable, Sendable {
    public let valueText: String
    public let unitText: String
    public let trendArrow: String
    public let timestampText: String
    public let ageText: String
    public let ageMinutes: Int
    public let freshness: ReadingFreshness

    public var isStale: Bool { freshness == .stale }
    public var staleText: String? { isStale ? "STALE" : nil }

    public static func make(
        reading: GlucoseReading,
        now: Date = .now,
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> ReadingPresentation {
        let age = max(0, now.timeIntervalSince(reading.timestamp))
        let ageMinutes = Int(age / 60)

        let valueFormatter = NumberFormatter()
        valueFormatter.locale = locale
        valueFormatter.numberStyle = .decimal
        valueFormatter.usesGroupingSeparator = false
        valueFormatter.minimumFractionDigits = 0
        valueFormatter.maximumFractionDigits = reading.unit == .mgDL ? 0 : 1

        let timeFormatter = DateFormatter()
        timeFormatter.locale = locale
        timeFormatter.calendar = calendar
        timeFormatter.timeZone = calendar.timeZone
        timeFormatter.dateFormat = "HH:mm"

        return ReadingPresentation(
            valueText: valueFormatter.string(from: NSDecimalNumber(decimal: reading.value)) ?? "—",
            unitText: reading.unit.displayText,
            trendArrow: reading.trend.arrow,
            timestampText: timeFormatter.string(from: reading.timestamp),
            ageText: ageMinutes == 0 ? "now" : "\(ageMinutes) min ago",
            ageMinutes: ageMinutes,
            freshness: .classify(age: age)
        )
    }
}
