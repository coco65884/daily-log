@testable import DailyLog
import SwiftData
import XCTest

@MainActor
final class NextActionPredictorTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext {
        container.mainContext
    }

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        if let tz = TimeZone(identifier: "Asia/Tokyo") {
            cal.timeZone = tz
        }
        return cal
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try AppModelContainer.makeContainer(inMemory: true)
    }

    override func tearDownWithError() throws {
        container = nil
        try super.tearDownWithError()
    }

    func testPredictsByDayOfWeekAndHourBucket() throws {
        let cal = calendar
        let work = ActivityTemplate(name: "仕事", sortOrder: 0)
        let study = ActivityTemplate(name: "勉強", sortOrder: 1)
        let exercise = ActivityTemplate(name: "運動", sortOrder: 2)
        context.insert(work)
        context.insert(study)
        context.insert(exercise)

        // 月曜 21時台のログ: 勉強 x3, 仕事 x1
        let mondayBase = makeDate(year: 2026, month: 5, day: 11, hour: 21, calendar: cal)
        insertActivity(template: study, startAt: mondayBase)
        insertActivity(template: study, startAt: mondayBase.addingTimeInterval(60 * 60 * 24 * 7))
        insertActivity(template: study, startAt: mondayBase.addingTimeInterval(60 * 60 * 24 * 14))
        insertActivity(template: work, startAt: mondayBase.addingTimeInterval(60 * 60 * 24 * 21))

        // 月曜 9時台のログ (別バケット): 仕事 x5
        let mondayMorning = makeDate(year: 2026, month: 5, day: 11, hour: 9, calendar: cal)
        for offsetWeek in 0 ..< 5 {
            insertActivity(
                template: work,
                startAt: mondayMorning.addingTimeInterval(60 * 60 * 24 * 7 * Double(offsetWeek))
            )
        }

        try context.save()

        let predictor = NextActionPredictor(calendar: cal)
        let target = makeDate(year: 2026, month: 5, day: 18, hour: 21, calendar: cal)
        let result = try predictor.predict(at: target, in: context, excluding: nil, limit: 2)

        XCTAssertEqual(result.first?.name, "勉強", "月曜21時台で頻度最高は勉強")
        XCTAssertEqual(result.count, 2)
    }

    func testExcludesCurrentTemplate() throws {
        let cal = calendar
        let work = ActivityTemplate(name: "仕事", sortOrder: 0)
        let study = ActivityTemplate(name: "勉強", sortOrder: 1)
        context.insert(work)
        context.insert(study)

        let monday = makeDate(year: 2026, month: 5, day: 11, hour: 21, calendar: cal)
        insertActivity(template: study, startAt: monday)
        insertActivity(template: study, startAt: monday.addingTimeInterval(60 * 60 * 24 * 7))
        try context.save()

        let predictor = NextActionPredictor(calendar: cal)
        let target = makeDate(year: 2026, month: 5, day: 18, hour: 21, calendar: cal)
        let result = try predictor.predict(at: target, in: context, excluding: study.id, limit: 3)

        XCTAssertFalse(result.contains(where: { $0.id == study.id }), "現在テンプレは候補から除外")
        XCTAssertTrue(result.contains(where: { $0.id == work.id }), "他テンプレで穴埋め")
    }

    func testExcludesHiddenTemplates() throws {
        let cal = calendar
        let work = ActivityTemplate(name: "仕事", sortOrder: 0)
        let hiddenParent = ActivityTemplate(name: "運動", sortOrder: 1, isHidden: true)
        context.insert(work)
        context.insert(hiddenParent)

        let monday = makeDate(year: 2026, month: 5, day: 11, hour: 21, calendar: cal)
        insertActivity(template: hiddenParent, startAt: monday)
        try context.save()

        let predictor = NextActionPredictor(calendar: cal)
        let target = makeDate(year: 2026, month: 5, day: 18, hour: 21, calendar: cal)
        let result = try predictor.predict(at: target, in: context, excluding: nil, limit: 3)

        XCTAssertFalse(result.contains(where: { $0.id == hiddenParent.id }), "非表示テンプレは候補に出ない")
    }

    func testFallsBackToOverallFrequencyWhenBucketEmpty() throws {
        let cal = calendar
        let work = ActivityTemplate(name: "仕事", sortOrder: 0)
        let study = ActivityTemplate(name: "勉強", sortOrder: 1)
        context.insert(work)
        context.insert(study)

        // 全期間で勉強の方が多いが、月曜21時台のログはゼロ
        let randomDate = makeDate(year: 2026, month: 5, day: 12, hour: 14, calendar: cal)
        for offsetDay in 0 ..< 4 {
            insertActivity(template: study, startAt: randomDate.addingTimeInterval(60 * 60 * 24 * Double(offsetDay)))
        }
        insertActivity(template: work, startAt: randomDate)
        try context.save()

        let predictor = NextActionPredictor(calendar: cal)
        let target = makeDate(year: 2026, month: 5, day: 18, hour: 21, calendar: cal)
        let result = try predictor.predict(at: target, in: context, excluding: nil, limit: 1)

        XCTAssertEqual(result.first?.name, "勉強", "バケットが空なら全期間頻度で穴埋め")
    }

    func testReturnsEmptyWhenNoVisibleTemplates() throws {
        let cal = calendar
        let predictor = NextActionPredictor(calendar: cal)
        let target = makeDate(year: 2026, month: 5, day: 18, hour: 21, calendar: cal)
        let result = try predictor.predict(at: target, in: context, excluding: nil, limit: 3)
        XCTAssertTrue(result.isEmpty)
    }

    private func insertActivity(template: ActivityTemplate, startAt: Date) {
        let activity = Activity(template: template, startAt: startAt, endAt: startAt.addingTimeInterval(600))
        context.insert(activity)
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int, calendar: Calendar) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = 0
        guard let date = calendar.date(from: components) else {
            XCTFail("Failed to build date for \(year)-\(month)-\(day) \(hour):00")
            return Date()
        }
        return date
    }
}
