@testable import DailyLog
import XCTest

final class DayActivitySummaryTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        return calendar
    }()

    func testAggregatesByTemplate() {
        let work = ActivityTemplate(name: "仕事", colorHex: "#111111")
        let meal = ActivityTemplate(name: "食事", colorHex: "#222222")

        let day = date(2026, 4, 25)
        let activities = [
            makeActivity(template: work, start: date(2026, 4, 25, 9, 0), duration: 3600),
            makeActivity(template: work, start: date(2026, 4, 25, 13, 0), duration: 1800),
            makeActivity(template: meal, start: date(2026, 4, 25, 12, 0), duration: 1800),
        ]

        let slices = DayActivitySummary.slices(for: activities, on: day, calendar: calendar)

        XCTAssertEqual(slices.count, 2)
        // Sorted by totalSeconds descending: 仕事 (5400) > 食事 (1800)
        XCTAssertEqual(slices[0].templateName, "仕事")
        XCTAssertEqual(slices[0].totalSeconds, 5400, accuracy: 0.001)
        XCTAssertEqual(slices[1].templateName, "食事")
        XCTAssertEqual(slices[1].totalSeconds, 1800, accuracy: 0.001)
    }

    func testClipsAtDayBoundaries() {
        let work = ActivityTemplate(name: "仕事", colorHex: "#111111")
        let day = date(2026, 4, 25)

        // Starts 2026-04-24 23:00, ends 2026-04-25 02:00. Only 2h falls on day 25.
        let activity = makeActivity(
            template: work,
            start: date(2026, 4, 24, 23, 0),
            duration: 3 * 3600
        )

        let slices = DayActivitySummary.slices(for: [activity], on: day, calendar: calendar)

        XCTAssertEqual(slices.count, 1)
        XCTAssertEqual(slices[0].totalSeconds, 2 * 3600, accuracy: 0.001)
    }

    func testFullDaySpanningActivityCountsAtMost24Hours() {
        let sleep = ActivityTemplate(name: "睡眠", colorHex: "#111111")
        let day = date(2026, 4, 25)
        // 2026-04-24 22:00 -> 2026-04-26 06:00 (32h total) covers all of day 25.
        let activity = makeActivity(template: sleep, start: date(2026, 4, 24, 22, 0), duration: 32 * 3600)

        let slices = DayActivitySummary.slices(for: [activity], on: day, calendar: calendar)
        let total = slices.reduce(0) { $0 + $1.totalSeconds }

        XCTAssertEqual(slices.count, 1)
        XCTAssertEqual(slices[0].totalSeconds, 24 * 3600, accuracy: 0.001)
        XCTAssertLessThanOrEqual(total, 24 * 3600)
    }

    func testInProgressClipsToNow() {
        let work = ActivityTemplate(name: "仕事", colorHex: "#111111")
        let day = date(2026, 4, 25)
        let activity = Activity(template: work, startAt: date(2026, 4, 25, 8, 0), endAt: nil)

        let slices = DayActivitySummary.slices(
            for: [activity],
            on: day,
            calendar: calendar,
            now: date(2026, 4, 25, 10, 30)
        )

        XCTAssertEqual(slices[0].totalSeconds, 2.5 * 3600, accuracy: 0.001)
    }

    func testActivityWithoutTemplateIsBucketedAsUncategorized() {
        let day = date(2026, 4, 25)
        let activity = makeActivity(template: nil, start: date(2026, 4, 25, 10, 0), duration: 1800)

        let slices = DayActivitySummary.slices(for: [activity], on: day, calendar: calendar)

        XCTAssertEqual(slices.count, 1)
        XCTAssertEqual(slices[0].templateID, nil)
        XCTAssertEqual(slices[0].templateName, "（未分類）")
    }

    func testActivitiesOutsideTheDayAreExcluded() {
        let work = ActivityTemplate(name: "仕事", colorHex: "#111111")
        let day = date(2026, 4, 25)
        let before = makeActivity(template: work, start: date(2026, 4, 23, 10, 0), duration: 3600)
        let after = makeActivity(template: work, start: date(2026, 4, 27, 10, 0), duration: 3600)

        let slices = DayActivitySummary.slices(for: [before, after], on: day, calendar: calendar)

        XCTAssertTrue(slices.isEmpty)
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

    private func makeActivity(template: ActivityTemplate?, start: Date, duration: TimeInterval) -> Activity {
        Activity(template: template, startAt: start, endAt: start.addingTimeInterval(duration))
    }
}
