@testable import DailyLog
import SwiftData
import XCTest

@MainActor
final class ActivityServiceTests: XCTestCase {
    private var container: ModelContainer!
    private var notifier: MockActivityNotifier!
    private var service: ActivityService!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try AppModelContainer.makeContainer(inMemory: true)
        notifier = MockActivityNotifier()
        service = ActivityService(context: container.mainContext, notifier: notifier)
    }

    override func tearDownWithError() throws {
        service = nil
        notifier = nil
        container = nil
        try super.tearDownWithError()
    }

    func testStartCreatesInProgressActivity() throws {
        let template = ActivityTemplate(name: "仕事", reminderMinutes: 60)
        container.mainContext.insert(template)

        let activity = try service.start(template: template)

        XCTAssertTrue(activity.isInProgress)
        XCTAssertEqual(activity.template?.name, "仕事")

        let open = try service.fetchInProgress()
        XCTAssertEqual(open.count, 1)
    }

    func testStartAutomaticallyStopsPreviousActivity() throws {
        let first = ActivityTemplate(name: "勉強", reminderMinutes: 45)
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
    }

    // MARK: - Reminder notifier integration

    func testStartSchedulesReminderForTemplateWithReminderMinutes() throws {
        let template = ActivityTemplate(name: "勉強", reminderMinutes: 45)
        container.mainContext.insert(template)

        let activity = try service.start(template: template)

        XCTAssertTrue(notifier.scheduledIDs.contains(activity.id))
    }

    func testStartDoesNotScheduleReminderWhenTemplateHasNone() throws {
        let template = ActivityTemplate(name: "睡眠", reminderMinutes: nil)
        container.mainContext.insert(template)

        let activity = try service.start(template: template)

        // The mock forwards to the real guard, mirroring production behaviour.
        XCTAssertFalse(notifier.scheduledIDs.contains(activity.id))
    }

    func testStartCancelsReminderForReplacedActivity() throws {
        let first = ActivityTemplate(name: "勉強", reminderMinutes: 45)
        let second = ActivityTemplate(name: "仕事", reminderMinutes: 60)
        container.mainContext.insert(first)
        container.mainContext.insert(second)

        let firstActivity = try service.start(template: first)
        let secondActivity = try service.start(template: second)

        XCTAssertTrue(notifier.cancelledIDs.contains(firstActivity.id))
        XCTAssertTrue(notifier.scheduledIDs.contains(secondActivity.id))
    }

    func testStopCurrentCancelsReminder() throws {
        let template = ActivityTemplate(name: "仕事", reminderMinutes: 60)
        container.mainContext.insert(template)

        let activity = try service.start(template: template)
        _ = try service.stopCurrent()

        XCTAssertTrue(notifier.cancelledIDs.contains(activity.id))
    }
}

@MainActor
private final class MockActivityNotifier: ActivityNotifier {
    private(set) var scheduledIDs: Set<UUID> = []
    private(set) var cancelledIDs: Set<UUID> = []

    func requestAuthorizationIfNeeded() async {}

    func scheduleReminder(for activity: Activity) {
        guard
            let template = activity.template,
            let minutes = template.reminderMinutes,
            minutes > 0
        else {
            return
        }
        scheduledIDs.insert(activity.id)
    }

    func cancelReminder(for activity: Activity) {
        cancelledIDs.insert(activity.id)
        scheduledIDs.remove(activity.id)
    }
}
