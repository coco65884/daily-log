@testable import DailyLog
import SwiftData
import XCTest

final class ModelTests: XCTestCase {
    private var container: ModelContainer!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try AppModelContainer.makeContainer(inMemory: true)
    }

    override func tearDownWithError() throws {
        container = nil
        try super.tearDownWithError()
    }

    @MainActor
    func testCreateAndFetchTemplate() throws {
        let context = container.mainContext
        let template = ActivityTemplate(name: "読書", iconName: "book", colorHex: "#112233", sortOrder: 10)
        context.insert(template)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<ActivityTemplate>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.name, "読書")
        XCTAssertEqual(fetched.first?.iconName, "book")
        XCTAssertEqual(fetched.first?.sortOrder, 10)
    }

    @MainActor
    func testTemplateIsHiddenDefaultsToFalse() throws {
        let context = container.mainContext
        let template = ActivityTemplate(name: "勉強")
        context.insert(template)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<ActivityTemplate>())
        XCTAssertEqual(fetched.first?.isHidden, false)
    }

    @MainActor
    func testTemplateHierarchy() throws {
        let context = container.mainContext
        let parent = ActivityTemplate(name: "仕事")
        let child = ActivityTemplate(name: "会議", parent: parent)
        context.insert(parent)
        context.insert(child)
        try context.save()

        XCTAssertEqual(parent.children.count, 1)
        XCTAssertEqual(parent.children.first?.name, "会議")
        XCTAssertEqual(child.parent?.name, "仕事")
    }

    @MainActor
    func testActivityLifecycle() throws {
        let context = container.mainContext
        let template = ActivityTemplate(name: "勉強")
        context.insert(template)
        let start = Date()
        let activity = Activity(template: template, startAt: start)
        context.insert(activity)
        try context.save()

        XCTAssertTrue(activity.isInProgress)
        XCTAssertNil(activity.duration)

        let end = start.addingTimeInterval(1800)
        activity.endAt = end
        try context.save()

        XCTAssertFalse(activity.isInProgress)
        let duration = try XCTUnwrap(activity.duration)
        XCTAssertEqual(duration, 1800, accuracy: 0.001)
        XCTAssertEqual(activity.template?.name, "勉強")
    }

    @MainActor
    func testMealAttachment() throws {
        let context = container.mainContext
        let template = ActivityTemplate(name: "食事")
        let activity = Activity(template: template)
        let meal = Meal(activity: activity, shopName: "駅前定食屋", note: "唐揚げ定食")
        context.insert(template)
        context.insert(activity)
        context.insert(meal)
        try context.save()

        XCTAssertEqual(activity.meal?.shopName, "駅前定食屋")
        XCTAssertEqual(meal.activity?.template?.name, "食事")
    }

    @MainActor
    func testCascadeDeleteTemplateChildren() throws {
        let context = container.mainContext
        let parent = ActivityTemplate(name: "仕事")
        let child = ActivityTemplate(name: "会議", parent: parent)
        context.insert(parent)
        context.insert(child)
        try context.save()

        context.delete(parent)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<ActivityTemplate>())
        XCTAssertEqual(remaining.count, 0)
    }

    @MainActor
    func testNullifyTemplateOnDelete() throws {
        let context = container.mainContext
        let template = ActivityTemplate(name: "趣味")
        let activity = Activity(template: template)
        context.insert(template)
        context.insert(activity)
        try context.save()

        context.delete(template)
        try context.save()

        let activities = try context.fetch(FetchDescriptor<Activity>())
        XCTAssertEqual(activities.count, 1)
        XCTAssertNil(activities.first?.template)
    }

    @MainActor
    func testReminderDefaultsByNameMatchesPresets() {
        XCTAssertEqual(DefaultTemplates.reminderDefaultsByName["睡眠"], 600)
        XCTAssertEqual(DefaultTemplates.reminderDefaultsByName["食事"], 120)
        XCTAssertEqual(DefaultTemplates.reminderDefaultsByName["仕事"], 600)
        XCTAssertEqual(DefaultTemplates.reminderDefaultsByName["勉強"], 480)
        XCTAssertEqual(DefaultTemplates.reminderDefaultsByName["運動"], 120)
        XCTAssertEqual(DefaultTemplates.reminderDefaultsByName["移動"], 120)
        // 休憩・趣味は nil なので辞書に含まれない
        XCTAssertNil(DefaultTemplates.reminderDefaultsByName["休憩"])
        XCTAssertNil(DefaultTemplates.reminderDefaultsByName["趣味"])
    }

    @MainActor
    func testDefaultTemplateSeeding() throws {
        let seededContainer = try AppModelContainer.makeContainer(inMemory: false)
        let context = ModelContext(seededContainer)
        let templates = try context.fetch(FetchDescriptor<ActivityTemplate>(sortBy: [SortDescriptor(\.sortOrder)]))
        XCTAssertGreaterThanOrEqual(templates.count, DefaultTemplates.presets.count)
        XCTAssertEqual(templates.first?.name, DefaultTemplates.presets.first?.name)

        let settings = try context.fetch(FetchDescriptor<AppSettings>())
        XCTAssertEqual(settings.count, 1)
    }

    @MainActor
    func testAppSettingsDefaults() throws {
        let context = container.mainContext
        let settings = AppSettings()
        context.insert(settings)
        try context.save()

        XCTAssertFalse(settings.iCloudSyncEnabled)
        XCTAssertEqual(settings.defaultReminderMinutes, 30)
    }
}
