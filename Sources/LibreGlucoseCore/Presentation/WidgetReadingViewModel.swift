import Foundation

public enum WidgetReadingViewModel: Equatable, Sendable {
    case reading(
        value: String,
        unit: String,
        trend: String,
        detail: String,
        freshness: ReadingFreshness
    )
    case reconnect
    case unavailable

    public var message: String? {
        switch self {
        case .reading:
            nil
        case .reconnect:
            "Open app to reconnect"
        case .unavailable:
            "Reading unavailable"
        }
    }

    public static func make(
        outcome: RefreshOutcome,
        fallback: GlucoseReading?,
        now: Date = .now,
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> WidgetReadingViewModel {
        switch outcome {
        case let .updated(reading), let .cached(reading):
            readingModel(reading, now: now, calendar: calendar, locale: locale)
        case .signedOut:
            .reconnect
        case .failed:
            if let fallback {
                readingModel(fallback, now: now, calendar: calendar, locale: locale)
            } else {
                .unavailable
            }
        }
    }

    private static func readingModel(
        _ reading: GlucoseReading,
        now: Date,
        calendar: Calendar,
        locale: Locale
    ) -> WidgetReadingViewModel {
        let presentation = ReadingPresentation.make(
            reading: reading,
            now: now,
            calendar: calendar,
            locale: locale
        )
        let detail = presentation.isStale
            ? "STALE · \(presentation.timestampText)"
            : "\(presentation.timestampText) · \(presentation.ageText)"
        return .reading(
            value: presentation.valueText,
            unit: presentation.unitText,
            trend: presentation.trendArrow,
            detail: detail,
            freshness: presentation.freshness
        )
    }
}
