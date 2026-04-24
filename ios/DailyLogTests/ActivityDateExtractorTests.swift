@testable import DailyLog
import XCTest

final class ActivityDateExtractorTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        return calendar
    }()

    func testExtractsUniqueYearMonthDayComponents() {
        let activities = [
            makeActivity(on: date(2026, 4, 25, hour: 9)),
            makeActivity(on: date(2026, 4, 25, hour: 15)),
            makeActivity(on: date(2026, 4, 26, hour: 7)),
        ]

        let result = ActivityDateExtractor.extractDateComponents(from: activities, calendar: calendar)

        // Calendar.dateComponents(_:from:) can populate extra fields (e.g. isLeapMonth)
        // that vary between SDK versions, so compare only the identity triple.
        let keys = Set(result.map { components -> String in
            "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
        })
        XCTAssertEqual(keys, Set(["2026-4-25", "2026-4-26"]))
    }

    func testFiltersActivitiesByCalendarDay() {
        let morning = makeActivity(on: date(2026, 4, 25, hour: 8))
        let evening = makeActivity(on: date(2026, 4, 25, hour: 22))
        let nextDay = makeActivity(on: date(2026, 4, 26, hour: 1))

        let result = ActivityDateExtractor.activities(
            on: date(2026, 4, 25, hour: 12),
            from: [morning, evening, nextDay],
            calendar: calendar
        )

        XCTAssertEqual(Set(result.map(\.id)), Set([morning.id, evening.id]))
    }

    // MARK: - Helpers

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        let components = DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour
        )
        return calendar.date(from: components) ?? Date()
    }

    private func makeActivity(on date: Date) -> Activity {
        Activity(startAt: date, endAt: date.addingTimeInterval(3600))
    }
}
