@testable import DailyLog
import SwiftData
import XCTest

@MainActor
final class ImportServiceTests: XCTestCase {
    private var sourceContainer: ModelContainer!
    private var destinationContainer: ModelContainer!
    private var tempRoot: URL!
    private var sourceStorage: PhotoStorage!
    private var destinationStorage: PhotoStorage!

    override func setUpWithError() throws {
        try super.setUpWithError()
        sourceContainer = try AppModelContainer.makeContainer(inMemory: true)
        destinationContainer = try AppModelContainer.makeContainer(inMemory: true)
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("ImportServiceTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        sourceStorage = PhotoStorage(rootURL: tempRoot.appendingPathComponent("src-photos"))
        destinationStorage = PhotoStorage(rootURL: tempRoot.appendingPathComponent("dst-photos"))
    }

    override func tearDownWithError() throws {
        if let tempRoot {
            try? FileManager.default.removeItem(at: tempRoot)
        }
        destinationStorage = nil
        sourceStorage = nil
        tempRoot = nil
        destinationContainer = nil
        sourceContainer = nil
        try super.tearDownWithError()
    }

    func testImportIntoEmptyContainerMergeMode() throws {
        let templateID = UUID()
        let activityID = UUID()

        let sourceContext = sourceContainer.mainContext
        let template = ActivityTemplate(id: templateID, name: "仕事", iconName: "briefcase.fill")
        sourceContext.insert(template)
        let activity = Activity(id: activityID, template: template, startAt: Date(timeIntervalSince1970: 1_700_000_000))
        sourceContext.insert(activity)
        try sourceContext.save()

        let archive = try ExportService(context: sourceContext, storage: sourceStorage).makeArchive()
        defer { try? FileManager.default.removeItem(at: archive) }

        let importer = ImportService(context: destinationContainer.mainContext, storage: destinationStorage)
        let result = try importer.importArchive(at: archive, mode: .merge)

        XCTAssertEqual(result.templatesImported, 1)
        XCTAssertEqual(result.activitiesImported, 1)

        let destTemplates = try destinationContainer.mainContext.fetch(FetchDescriptor<ActivityTemplate>())
        let destActivities = try destinationContainer.mainContext.fetch(FetchDescriptor<Activity>())
        XCTAssertEqual(destTemplates.map(\.id), [templateID])
        XCTAssertEqual(destActivities.map(\.id), [activityID])
        XCTAssertEqual(destActivities.first?.template?.id, templateID)
    }

    func testImportReplaceModeDeletesPreexistingRecords() throws {
        let destContext = destinationContainer.mainContext
        destContext.insert(ActivityTemplate(name: "残ると困る"))
        try destContext.save()

        // Empty source
        let emptyArchive = try ExportService(context: sourceContainer.mainContext, storage: sourceStorage).makeArchive()
        defer { try? FileManager.default.removeItem(at: emptyArchive) }

        let importer = ImportService(context: destContext, storage: destinationStorage)
        _ = try importer.importArchive(at: emptyArchive, mode: .replace)

        let remaining = try destContext.fetch(FetchDescriptor<ActivityTemplate>())
        XCTAssertTrue(remaining.isEmpty, "replace mode should wipe pre-existing templates")
    }

    func testImportUpdatesExistingTemplateByID() throws {
        let templateID = UUID()
        let destContext = destinationContainer.mainContext
        destContext.insert(ActivityTemplate(id: templateID, name: "旧名"))
        try destContext.save()

        let sourceContext = sourceContainer.mainContext
        sourceContext.insert(ActivityTemplate(id: templateID, name: "新名"))
        try sourceContext.save()

        let archive = try ExportService(context: sourceContext, storage: sourceStorage).makeArchive()
        defer { try? FileManager.default.removeItem(at: archive) }

        let importer = ImportService(context: destContext, storage: destinationStorage)
        _ = try importer.importArchive(at: archive, mode: .merge)

        let templates = try destContext.fetch(FetchDescriptor<ActivityTemplate>())
        XCTAssertEqual(templates.count, 1)
        XCTAssertEqual(templates.first?.name, "新名")
    }
}
