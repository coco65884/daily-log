@testable import DailyLog
import SwiftData
import XCTest

@MainActor
final class ActivityServiceTests: XCTestCase {
    private var container: ModelContainer!
    private var service: ActivityService!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try AppModelContainer.makeContainer(inMemory: true)
        service = ActivityService(context: container.mainContext)
    }

    override func tearDownWithError() throws {
        service = nil
        container = nil
        try super.tearDownWithError()
    }

    func testStartCreatesInProgressActivity() throws {
        let template = ActivityTemplate(name: "仕事")
        container.mainContext.insert(template)

        let activity = try service.start(template: template)

        XCTAssertTrue(activity.isInProgress)
        XCTAssertEqual(activity.template?.name, "仕事")

        let open = try service.fetchInProgress()
        XCTAssertEqual(open.count, 1)
    }

    func testStartAutomaticallyStopsPreviousActivity() throws {
        let first = ActivityTemplate(name: "勉強")
        let second = ActivityTemplate(name: "休憩")
        container.mainContext.insert(first)
        container.mainContext.insert(second)

        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        let t1 = t0.addingTimeInterval(600)

        let firstActivity = try service.start(template: first, at: t0)
        let secondActivity = try service.start(template: second, at: t1)

        XCTAssertEqual(firstActivity.endAt, t1)
        XCTAssertFalse(firstActivity.isInProgress)
        XCTAssertTrue(secondActivity.isInProgress)

        let open = try service.fetchInProgress()
        XCTAssertEqual(open.count, 1)
        XCTAssertEqual(open.first?.template?.name, "休憩")
    }

    func testStopCurrentClosesOpenActivity() throws {
        let template = ActivityTemplate(name: "運動")
        container.mainContext.insert(template)

        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(1800)

        let activity = try service.start(template: template, at: start)
        let stopped = try service.stopCurrent(at: end)

        XCTAssertEqual(stopped?.id, activity.id)
        XCTAssertEqual(activity.endAt, end)
        XCTAssertFalse(activity.isInProgress)

        let open = try service.fetchInProgress()
        XCTAssertTrue(open.isEmpty)
    }

    func testStopCurrentWithNothingRunningReturnsNil() throws {
        let stopped = try service.stopCurrent()
        XCTAssertNil(stopped)
    }

    func testDefensivelyClosesMultipleInProgress() throws {
        // 何らかの理由で 2 件進行中になった状態を作り、stopCurrent が全て閉じることを確認
        let template = ActivityTemplate(name: "仕事")
        container.mainContext.insert(template)

        let a1 = Activity(template: template, startAt: Date(timeIntervalSinceNow: -120))
        let a2 = Activity(template: template, startAt: Date(timeIntervalSinceNow: -60))
        container.mainContext.insert(a1)
        container.mainContext.insert(a2)
        try container.mainContext.save()

        let endAt = Date()
        _ = try service.stopCurrent(at: endAt)

        XCTAssertFalse(a1.isInProgress)
        XCTAssertFalse(a2.isInProgress)
        XCTAssertEqual(a1.endAt, endAt)
        XCTAssertEqual(a2.endAt, endAt)

        let open = try service.fetchInProgress()
        XCTAssertTrue(open.isEmpty)
    }
}
