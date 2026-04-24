@testable import DailyLog
import XCTest

final class PeriodActivitySummaryTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        calendar.firstWeekday = 1 // Sunday
        return calendar
    }()

    func testWeekRangeCoversSevenDaysStartingFromFirstWeekday() {
        let reference = date(2026, 4, 22, 12, 0) // Wednesday
        let range = PeriodActivitySummary.Period.week.range(containing: reference, calendar: calendar)

        XCTAssertEqual(range.start, date(2026, 4, 19))
        XCTAssertEqual(range.end, date(2026, 4, 26))
    }

    func testMonthRangeCoversCalendarMonth() {
        let reference = date(2026, 4, 22, 12, 0)
        let range = PeriodActivitySummary.Period.month.range(containing: reference, calendar: calendar)

        XCTAssertEqual(range.start, date(2026, 4, 1))
        XCTAssertEqual(range.end, date(2026, 5, 1))
    }

    func testWeekSummaryAggregatesByTemplate() {
        let work = ActivityTemplate(name: "仕事", colorHex: "#111111")
        let meal = ActivityTemplate(name: "食事", colorHex: "#222222", isMealType: true)

        let activities = [
            Activity(template: work, startAt: date(2026, 4, 20, 9, 0), endAt: date(2026, 4, 20, 12, 0)),
            Activity(template: work, startAt: date(2026, 4, 21, 13, 0), endAt: date(2026, 4, 21, 15, 0)),
            Activity(template: meal, startAt: date(2026, 4, 20, 12, 0), endAt: date(2026, 4, 20, 13, 0)),
        ]

        let summary = PeriodActivitySummary.summarize(
            activities: activities,
            period: .week,
            referenceDate: date(2026, 4, 22, 12, 0),
            calendar: calendar
        )

        XCTAssertEqual(summary.categories.count, 2)
        XCTAssertEqual(summary.categories[0].templateName, "仕事")
        XCTAssertEqual(summary.categories[0].totalSeconds, 5 * 3600, accuracy: 0.001)
        XCTAssertEqual(summary.categories[1].templateName, "食事")
        XCTAssertEqual(summary.categories[1].totalSeconds, 3600, accuracy: 0.001)
    }

    func testChildTemplateRollsUpUnderParent() {
        let work = ActivityTemplate(name: "仕事", colorHex: "#111111")
        let meeting = ActivityTemplate(name: "会議", colorHex: "#333333", parent: work)

        let activities = [
            Activity(template: work, startAt: date(2026, 4, 20, 9, 0), endAt: date(2026, 4, 20, 11, 0)),
            Activity(template: meeting, startAt: date(2026, 4, 20, 14, 0), endAt: date(2026, 4, 20, 15, 0)),
        ]

        let summary = PeriodActivitySummary.summarize(
            activities: activities,
            period: .week,
            referenceDate: date(2026, 4, 22, 12, 0),
            calendar: calendar
        )

        XCTAssertEqual(summary.categories.count, 1)
        let workCategory = summary.categories[0]
        XCTAssertEqual(workCategory.templateName, "仕事")
        XCTAssertEqual(workCategory.totalSeconds, 3 * 3600, accuracy: 0.001) // 2h parent + 1h child
        XCTAssertEqual(workCategory.children.count, 1)
        XCTAssertEqual(workCategory.children[0].templateName, "会議")
        XCTAssertEqual(workCategory.children[0].totalSeconds, 3600, accuracy: 0.001)
    }

    func testOnlyChildRecordedStillShowsParentRoot() {
        let work = ActivityTemplate(name: "仕事", colorHex: "#111111")
        let meeting = ActivityTemplate(name: "会議", colorHex: "#333333", parent: work)

        let activities = [
            Activity(template: meeting, startAt: date(2026, 4, 20, 14, 0), endAt: date(2026, 4, 20, 16, 0)),
        ]

        let summary = PeriodActivitySummary.summarize(
            activities: activities,
            period: .week,
            referenceDate: date(2026, 4, 22, 12, 0),
            calendar: calendar
        )

        XCTAssertEqual(summary.categories.count, 1)
        XCTAssertEqual(summary.categories[0].templateName, "仕事")
        XCTAssertEqual(summary.categories[0].totalSeconds, 2 * 3600, accuracy: 0.001)
        XCTAssertEqual(summary.categories[0].children.map(\.templateName), ["会議"])
    }

    func testMealStatsCountActivitiesAndPhotos() {
        let meal = ActivityTemplate(name: "食事", colorHex: "#F5A623", isMealType: true)

        let lunch = Activity(
            template: meal,
            startAt: date(2026, 4, 20, 12, 0),
            endAt: date(2026, 4, 20, 13, 0)
        )
        lunch.meal = Meal(activity: lunch, photoFilenames: ["a.jpg", "b.jpg"])

        let dinner = Activity(
            template: meal,
            startAt: date(2026, 4, 21, 19, 0),
            endAt: date(2026, 4, 21, 20, 0)
        )
        dinner.meal = Meal(activity: dinner, photoFilenames: ["c.jpg"])

        let summary = PeriodActivitySummary.summarize(
            activities: [lunch, dinner],
            period: .week,
            referenceDate: date(2026, 4, 22, 12, 0),
            calendar: calendar
        )

        XCTAssertEqual(summary.meal.activityCount, 2)
        XCTAssertEqual(summary.meal.photoCount, 3)
    }

    func testActivitiesOutsidePeriodAreExcluded() {
        let work = ActivityTemplate(name: "仕事", colorHex: "#111111")
        let before = Activity(template: work, startAt: date(2026, 4, 10, 9, 0), endAt: date(2026, 4, 10, 11, 0))
        let after = Activity(template: work, startAt: date(2026, 4, 27, 9, 0), endAt: date(2026, 4, 27, 11, 0))

        let summary = PeriodActivitySummary.summarize(
            activities: [before, after],
            period: .week,
            referenceDate: date(2026, 4, 22, 12, 0),
            calendar: calendar
        )

        XCTAssertTrue(summary.categories.isEmpty)
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
}
