@testable import DailyLog
import SwiftData
import XCTest

@MainActor
final class ExportServiceTests: XCTestCase {
    private var container: ModelContainer!
    private var tempDir: URL!
    private var storage: PhotoStorage!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try AppModelContainer.makeContainer(inMemory: true)
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ExportServiceTests-\(UUID().uuidString)", isDirectory: true)
        storage = PhotoStorage(rootURL: tempDir)
    }

    override func tearDownWithError() throws {
        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        storage = nil
        container = nil
        tempDir = nil
        try super.tearDownWithError()
    }

    func testSnapshotCapturesAllModels() throws {
        let context = container.mainContext
        let template = ActivityTemplate(name: "仕事", iconName: "briefcase.fill", colorHex: "#4A90E2")
        context.insert(template)
        let activity = Activity(
            template: template,
            startAt: Date(timeIntervalSince1970: 1_700_000_000),
            endAt: Date(timeIntervalSince1970: 1_700_003_600),
            note: "メモ"
        )
        context.insert(activity)
        try context.save()

        let service = ExportService(
            context: context,
            storage: storage,
            now: { Date(timeIntervalSince1970: 1_700_010_000) }
        )
        let snapshot = try service.buildSnapshot()

        XCTAssertEqual(snapshot.schemaVersion, ExportSnapshot.currentSchemaVersion)
        XCTAssertEqual(snapshot.exportedAt, Date(timeIntervalSince1970: 1_700_010_000))
        XCTAssertTrue(snapshot.templates.contains { $0.id == template.id })
        XCTAssertTrue(snapshot.activities.contains { $0.id == activity.id && $0.templateID == template.id })
    }

    func testSnapshotIsRoundTripCodable() throws {
        let context = container.mainContext
        let template = ActivityTemplate(name: "読書", iconName: "book", colorHex: "#50C9BA")
        context.insert(template)
        try context.save()

        let service = ExportService(context: context, storage: storage)
        let snapshot = try service.buildSnapshot()

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let data = try encoder.encode(snapshot)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let decoded = try decoder.decode(ExportSnapshot.self, from: data)

        // Date encoding as Double seconds can round sub-ms bits; compare
        // structurally instead of requiring bit-exact Date equality.
        XCTAssertEqual(decoded.schemaVersion, snapshot.schemaVersion)
        XCTAssertEqual(decoded.templates.count, snapshot.templates.count)
        XCTAssertEqual(decoded.templates.first?.id, snapshot.templates.first?.id)
        XCTAssertEqual(decoded.templates.first?.name, snapshot.templates.first?.name)
        XCTAssertEqual(decoded.templates.first?.colorHex, snapshot.templates.first?.colorHex)
    }

    func testMakeArchiveProducesReadableZip() throws {
        let context = container.mainContext
        let template = ActivityTemplate(name: "仕事")
        context.insert(template)
        try context.save()

        let service = ExportService(context: context, storage: storage)
        let url = try service.makeArchive()
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attributes[.size] as? NSNumber)?.intValue ?? 0
        XCTAssertGreaterThan(size, 0)
    }
}
