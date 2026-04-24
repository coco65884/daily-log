@testable import DailyLog
import SwiftData
import XCTest

@MainActor
final class TemplateServiceTests: XCTestCase {
    private var container: ModelContainer!
    private var service: TemplateService!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try AppModelContainer.makeContainer(inMemory: true)
        service = TemplateService(context: container.mainContext)
    }

    override func tearDownWithError() throws {
        service = nil
        container = nil
        try super.tearDownWithError()
    }

    func testCreateAssignsIncrementingSortOrder() throws {
        let first = try service.create(name: "A")
        let second = try service.create(name: "B")
        let third = try service.create(name: "C")

        XCTAssertEqual(first.sortOrder, 0)
        XCTAssertEqual(second.sortOrder, 1)
        XCTAssertEqual(third.sortOrder, 2)
    }

    func testCreateWithParentUsesParentSiblingSortOrder() throws {
        let parent = try service.create(name: "親")
        let child1 = try service.create(name: "子1", parent: parent)
        let child2 = try service.create(name: "子2", parent: parent)

        // Children are scoped to their parent's siblings, not the global list.
        XCTAssertEqual(child1.sortOrder, 0)
        XCTAssertEqual(child2.sortOrder, 1)
        XCTAssertEqual(child1.parent?.id, parent.id)
    }

    func testCreateMealTypeFlag() throws {
        let meal = try service.create(name: "ランチ", isMealType: true)
        XCTAssertTrue(meal.isMealType)
    }

    func testReorderUpdatesSortOrder() throws {
        let first = try service.create(name: "A")
        let second = try service.create(name: "B")
        let third = try service.create(name: "C")
        let siblings = try service.siblings(of: nil)

        try service.reorder(siblings: siblings, from: IndexSet(integer: 2), to: 0)

        XCTAssertEqual(third.sortOrder, 0)
        XCTAssertEqual(first.sortOrder, 1)
        XCTAssertEqual(second.sortOrder, 2)

        let reloaded = try service.siblings(of: nil)
        XCTAssertEqual(reloaded.map(\.name), ["C", "A", "B"])
    }

    func testDeleteRemovesTemplate() throws {
        let template = try service.create(name: "消えるやつ")
        try service.delete(template)

        let remaining = try service.siblings(of: nil)
        XCTAssertTrue(remaining.allSatisfy { $0.name != "消えるやつ" })
    }

    func testDeleteParentCascadesChildren() throws {
        let parent = try service.create(name: "親")
        _ = try service.create(name: "子", parent: parent)

        try service.delete(parent)

        let all = try container.mainContext.fetch(FetchDescriptor<ActivityTemplate>())
        XCTAssertFalse(all.contains { $0.name == "親" })
        XCTAssertFalse(all.contains { $0.name == "子" })
    }

    func testSiblingsOfNilReturnsRootTemplatesInOrder() throws {
        _ = try service.create(name: "root1")
        let parent = try service.create(name: "root2")
        _ = try service.create(name: "child", parent: parent)

        let roots = try service.siblings(of: nil)
        XCTAssertEqual(roots.map(\.name), ["root1", "root2"])
    }
}
