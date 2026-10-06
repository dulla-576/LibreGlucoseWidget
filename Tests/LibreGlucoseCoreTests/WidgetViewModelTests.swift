import Foundation
import XCTest
@testable import LibreGlucoseCore

final class WidgetViewModelTests: XCTestCase {
    func testFreshReadingContainsValueUnitArrowAndTimestampWithAge() {
        let reading = GlucoseReading(
            value: 123,
            unit: .mgDL,
            trend: .steady,
            timestamp: date(hour: 14, minute: 32)
        )

        let model = WidgetReadingViewModel.make(
            outcome: .updated(reading),
            fallback: nil,
            now: date(hour: 14, minute: 40),
            calendar: utcCalendar,
            locale: Locale(identifier: "en_US_POSIX")
        )

        XCTAssertEqual(
            model,
            .reading(value: "123", unit: "mg/dL", trend: "→", detail: "14:32 · 8 min ago", freshness: .fresh)
        )
    }

    func testReadingOlderThanSixtyMinutesShowsStaleAndSourceTime() {
        let reading = GlucoseReading(
            value: 6.8,
            unit: .mmolL,
            trend: .slowlyRising,
            timestamp: date(hour: 14, minute: 32)
        )

        let model = WidgetReadingViewModel.make(
            outcome: .updated(reading),
            fallback: nil,
            now: date(hour: 15, minute: 33),
            calendar: utcCalendar,
            locale: Locale(identifier: "en_US_POSIX")
        )

        XCTAssertEqual(
            model,
            .reading(value: "6.8", unit: "mmol/L", trend: "↗", detail: "STALE · 14:32", freshness: .stale)
        )
    }

    func testFailedRefreshKeepsCachedReadingAndItsTimestamp() {
        let cached = GlucoseReading(
            value: 118,
            unit: .mgDL,
            trend: .slowlyFalling,
            timestamp: date(hour: 14, minute: 32)
        )

        let model = WidgetReadingViewModel.make(
            outcome: .failed,
            fallback: cached,
            now: date(hour: 14, minute: 47),
            calendar: utcCalendar,
            locale: Locale(identifier: "en_US_POSIX")
        )

        guard case let .reading(value, unit, trend, detail, freshness) = model else {
            return XCTFail("Expected cached reading")
        }
        XCTAssertEqual(value, "118")
        XCTAssertEqual(unit, "mg/dL")
        XCTAssertEqual(trend, "↘")
        XCTAssertEqual(detail, "14:32 · 15 min ago")
        XCTAssertEqual(freshness, .fresh)
    }

    func testMissingCredentialsWithoutCacheRequestsReconnect() {
        let model = WidgetReadingViewModel.make(
            outcome: .signedOut,
            fallback: nil,
            now: date(hour: 14, minute: 40),
            calendar: utcCalendar,
            locale: Locale(identifier: "en_US_POSIX")
        )

        XCTAssertEqual(model, .reconnect)
        XCTAssertEqual(model.message, "Open app to reconnect")
    }

    func testFailedRefreshWithoutCacheIsUnavailable() {
        let model = WidgetReadingViewModel.make(
            outcome: .failed,
            fallback: nil,
            now: date(hour: 14, minute: 40),
            calendar: utcCalendar,
            locale: Locale(identifier: "en_US_POSIX")
        )

        XCTAssertEqual(model, .unavailable)
        XCTAssertEqual(model.message, "Reading unavailable")
    }

    func testUnknownTrendIsNeverGuessed() {
        let reading = GlucoseReading(
            value: 101,
            unit: .mgDL,
            trend: .unknown,
            timestamp: date(hour: 14, minute: 32)
        )

        let model = WidgetReadingViewModel.make(
            outcome: .cached(reading),
            fallback: nil,
            now: date(hour: 14, minute: 40),
            calendar: utcCalendar,
            locale: Locale(identifier: "en_US_POSIX")
        )

        guard case let .reading(_, _, trend, _, _) = model else {
            return XCTFail("Expected reading")
        }
        XCTAssertEqual(trend, "?")
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(hour: Int, minute: Int) -> Date {
        DateComponents(
            calendar: utcCalendar,
            timeZone: TimeZone(secondsFromGMT: 0),
            year: 2026,
            month: 10,
            day: 5,
            hour: hour,
            minute: minute
        ).date!
    }
}
