@testable import DailyLog
import XCTest

final class WeekActivityLayoutTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        calendar.firstWeekday = 1 // 日曜始まり (Japan)
        return calendar
    }()

    func testSingleActivityWithinOneDay() {
        let weekStart = sunday(2026, 4, 19)
        // Wednesday 14:00-16:30
        let activity = makeActivity(start: date(2026, 4, 22, 14, 0), duration: 2.5 * 3600)

        let spans = WeekActivityLayout.spans(for: [activity], weekStart: weekStart, calendar: calendar)

        XCTAssertEqual(spans.count, 1)
        let span = spans[0]
        XCTAssertEqual(span.weekdayIndex, 3) // Sun=0, ..., Wed=3
        XCTAssertEqual(span.startHours, 14, accuracy: 0.001)
        XCTAssertEqual(span.endHours, 16.5, accuracy: 0.001)
    }

    func testActivitySpanningMidnightSplitsAcrossDays() {
        let weekStart = sunday(2026, 4, 19)
        // Saturday 23:00 -> Sunday 02:00 (next week begins Sunday again)
        let activity = makeActivity(start: date(2026, 4, 25, 23, 0), duration: 3 * 3600)

        let spans = WeekActivityLayout.spans(for: [activity], weekStart: weekStart, calendar: calendar)

        XCTAssertEqual(spans.count, 1)
        // The second chunk would be 2026-04-26 which is Sunday of next week — outside current week
        let saturdaySpan = spans[0]
        XCTAssertEqual(saturdaySpan.weekdayIndex, 6)
        XCTAssertEqual(saturdaySpan.startHours, 23, accuracy: 0.001)
        XCTAssertEqual(saturdaySpan.endHours, 24, accuracy: 0.001)
    }

    func testActivitySpanningMidnightWithinSameWeek() {
        let weekStart = sunday(2026, 4, 19)
        // Monday 22:00 -> Tuesday 01:00
        let activity = makeActivity(start: date(2026, 4, 20, 22, 0), duration: 3 * 3600)

        let spans = WeekActivityLayout.spans(for: [activity], weekStart: weekStart, calendar: calendar)

        XCTAssertEqual(spans.count, 2)
        XCTAssertEqual(spans[0].weekdayIndex, 1)
        XCTAssertEqual(spans[0].startHours, 22, accuracy: 0.001)
        XCTAssertEqual(spans[0].endHours, 24, accuracy: 0.001)
        XCTAssertEqual(spans[1].weekdayIndex, 2)
        XCTAssertEqual(spans[1].startHours, 0, accuracy: 0.001)
        XCTAssertEqual(spans[1].endHours, 1, accuracy: 0.001)
    }

    func testActivityOutsideWeekIsExcluded() {
        let weekStart = sunday(2026, 4, 19)
        let before = makeActivity(start: date(2026, 4, 18, 10, 0), duration: 2 * 3600)
        let after = makeActivity(start: date(2026, 4, 27, 10, 0), duration: 2 * 3600)

        let spans = WeekActivityLayout.spans(for: [before, after], weekStart: weekStart, calendar: calendar)

        XCTAssertTrue(spans.isEmpty)
    }

    func testInProgressActivityClipsToNow() {
        let weekStart = sunday(2026, 4, 19)
        // Starts Monday 10:00, in progress; "now" is Monday 12:30
        let start = date(2026, 4, 20, 10, 0)
        let now = date(2026, 4, 20, 12, 30)
        let activity = Activity(startAt: start, endAt: nil)

        let spans = WeekActivityLayout.spans(
            for: [activity],
            weekStart: weekStart,
            calendar: calendar,
            now: now
        )

        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual(spans[0].startHours, 10, accuracy: 0.001)
        XCTAssertEqual(spans[0].endHours, 12.5, accuracy: 0.001)
    }

    func testWeekStartContainingUsesCalendarFirstWeekday() {
        // 2026-04-22 is Wednesday. Week starts on Sunday = 2026-04-19.
        let reference = date(2026, 4, 22, 12, 0)
        let weekStart = WeekActivityLayout.weekStart(containing: reference, calendar: calendar)
        XCTAssertEqual(weekStart, sunday(2026, 4, 19))
    }

    // MARK: - Helpers

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        let components = DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )
        return calendar.date(from: components) ?? Date()
    }

    private func sunday(_ year: Int, _ month: Int, _ day: Int) -> Date {
        date(year, month, day, 0, 0)
    }

    private func makeActivity(start: Date, duration: TimeInterval) -> Activity {
        Activity(startAt: start, endAt: start.addingTimeInterval(duration))
    }
}
