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

        let expected: Set<DateComponents> = [
            DateComponents(year: 2026, month: 4, day: 25),
            DateComponents(year: 2026, month: 4, day: 26),
        ]
        XCTAssertEqual(result, expected)
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
