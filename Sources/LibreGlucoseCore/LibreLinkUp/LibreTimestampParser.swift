import Foundation

public struct LibreTimestampParser: Sendable {
    private let timeZone: TimeZone

    public init(timeZone: TimeZone = .current) {
        self.timeZone = timeZone
    }

    public func parse(_ value: String) -> Date? {
        let fractionalISO = ISO8601DateFormatter()
        fractionalISO.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalISO.date(from: value) {
            return date
        }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: value) {
            return date
        }

        let libre = DateFormatter()
        libre.locale = Locale(identifier: "en_US_POSIX")
        libre.calendar = Calendar(identifier: .gregorian)
        libre.timeZone = timeZone
        libre.dateFormat = "M/d/yyyy h:mm:ss a"
        libre.isLenient = false
        return libre.date(from: value)
    }
}
