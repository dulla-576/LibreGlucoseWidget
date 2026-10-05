import Foundation
import XCTest
@testable import LibreGlucoseCore

final class ReadingPresentationTests: XCTestCase {
    private let locale = Locale(identifier: "en_US_POSIX")
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testReadingRoundTripsThroughJSON() throws {
        let reading = GlucoseReading(
            value: Decimal(string: "6.2")!,
            unit: .mmolL,
            trend: .slowlyRising,
            timestamp: Date(timeIntervalSince1970: 1_800_000_000),
            connectionID: "synthetic-connection"
        )

        let data = try JSONEncoder().encode(reading)
        let decoded = try JSONDecoder().decode(GlucoseReading.self, from: data)

        XCTAssertEqual(decoded, reading)
    }

    func testUnitsAndValuesArePresentedWithoutConversion() {
        let mg = makePresentation(value: 112, unit: .mgDL)
        let mmol = makePresentation(value: Decimal(string: "6.2")!, unit: .mmolL)

        XCTAssertEqual(mg.valueText, "112")
        XCTAssertEqual(mg.unitText, "mg/dL")
        XCTAssertEqual(mmol.valueText, "6.2")
        XCTAssertEqual(mmol.unitText, "mmol/L")
    }

    func testEveryTrendHasAnExplicitArrowAndUnknownIsNotGuessed() {
        let pairs: [(GlucoseTrend, String)] = [
            (.rapidlyFalling, "↓↓"),
            (.falling, "↓"),
            (.slowlyFalling, "↘"),
            (.steady, "→"),
            (.slowlyRising, "↗"),
            (.rising, "↑"),
            (.rapidlyRising, "↑↑"),
            (.unknown, "?")
        ]

        for (trend, expected) in pairs {
            XCTAssertEqual(makePresentation(trend: trend).trendArrow, expected)
        }
    }

    func testEightMinuteOldReadingShowsAbsoluteTimeAndRelativeAge() {
        let timestamp = date(hour: 14, minute: 32)
        let now = calendar.date(byAdding: .minute, value: 8, to: timestamp)!

        let presentation = ReadingPresentation.make(
            reading: makeReading(timestamp: timestamp),
            now: now,
            calendar: calendar,
            locale: locale
        )

        XCTAssertEqual(presentation.timestampText, "14:32")
        XCTAssertEqual(presentation.ageText, "8 min ago")
        XCTAssertEqual(presentation.freshness, .fresh)
    }

    func testExactlySixtyMinutesIsDelayedButNotStale() {
        let timestamp = date(hour: 12, minute: 0)
        let now = calendar.date(byAdding: .minute, value: 60, to: timestamp)!

        let presentation = makePresentation(timestamp: timestamp, now: now)

        XCTAssertEqual(presentation.freshness, .delayed)
        XCTAssertFalse(presentation.isStale)
    }

    func testSixtyMinutesAndOneSecondIsStale() {
        let timestamp = date(hour: 12, minute: 0)
        let now = timestamp.addingTimeInterval(3_601)

        let presentation = makePresentation(timestamp: timestamp, now: now)

        XCTAssertEqual(presentation.freshness, .stale)
        XCTAssertTrue(presentation.isStale)
        XCTAssertEqual(presentation.staleText, "STALE")
    }

    func testFutureTimestampClampsAgeToZeroAndRemainsFresh() {
        let now = date(hour: 12, minute: 0)
        let future = now.addingTimeInterval(30)

        let presentation = makePresentation(timestamp: future, now: now)

        XCTAssertEqual(presentation.ageMinutes, 0)
        XCTAssertEqual(presentation.ageText, "now")
        XCTAssertEqual(presentation.freshness, .fresh)
    }

    private func makePresentation(
        value: Decimal = 112,
        unit: GlucoseUnit = .mgDL,
        trend: GlucoseTrend = .steady,
        timestamp: Date? = nil,
        now: Date? = nil
    ) -> ReadingPresentation {
        let sourceTime = timestamp ?? date(hour: 14, minute: 32)
        return ReadingPresentation.make(
            reading: makeReading(value: value, unit: unit, trend: trend, timestamp: sourceTime),
            now: now ?? sourceTime.addingTimeInterval(8 * 60),
            calendar: calendar,
            locale: locale
        )
    }

    private func makeReading(
        value: Decimal = 112,
        unit: GlucoseUnit = .mgDL,
        trend: GlucoseTrend = .steady,
        timestamp: Date
    ) -> GlucoseReading {
        GlucoseReading(
            value: value,
            unit: unit,
            trend: trend,
            timestamp: timestamp,
            connectionID: "synthetic-connection"
        )
    }

    private func date(hour: Int, minute: Int) -> Date {
        calendar.date(from: DateComponents(year: 2027, month: 1, day: 15, hour: hour, minute: minute))!
    }
}
