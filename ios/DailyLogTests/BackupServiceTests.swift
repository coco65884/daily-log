@testable import DailyLog
import SwiftData
import XCTest

@MainActor
final class BackupServiceTests: XCTestCase {
    private var container: ModelContainer!
    private var rootDirectory: URL!
    private var storage: PhotoStorage!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try AppModelContainer.makeContainer(inMemory: true)
        rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BackupServiceTests-\(UUID().uuidString)", isDirectory: true)
        storage = PhotoStorage(rootURL: rootDirectory.appendingPathComponent("photos"))
    }

    override func tearDownWithError() throws {
        if let rootDirectory {
            try? FileManager.default.removeItem(at: rootDirectory)
        }
        storage = nil
        rootDirectory = nil
        container = nil
        try super.tearDownWithError()
    }

    func testPerformBackupProducesZipInTarget() throws {
        let context = container.mainContext
        context.insert(ActivityTemplate(name: "仕事"))
        try context.save()

        let target = rootDirectory.appendingPathComponent("backups")
        let service = BackupService(
            exporter: ExportService(context: context, storage: storage),
            targetDirectory: target
        )

        let url = try service.performBackup()

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(url.pathExtension, "zip")
        let list = try service.listBackups()
        XCTAssertEqual(list.count, 1)
    }

    func testPrunesOldBackupsBeyondLimit() throws {
        let context = container.mainContext
        context.insert(ActivityTemplate(name: "X"))
        try context.save()

        let target = rootDirectory.appendingPathComponent("backups")
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)

        // Seed 5 existing backup files with distinct timestamps (oldest first).
        var seededURLs: [URL] = []
        for index in 0 ..< 5 {
            let name = "DailyLog-2026010\(index)-000000.zip"
            let url = target.appendingPathComponent(name)
            try Data("old".utf8).write(to: url)
            // Nudge modification date so ordering is predictable.
            let date = Date(timeIntervalSince1970: 1_700_000_000 + Double(index) * 60)
            try FileManager.default.setAttributes(
                [.creationDate: date, .modificationDate: date],
                ofItemAtPath: url.path
            )
            seededURLs.append(url)
        }

        let service = BackupService(
            exporter: ExportService(context: context, storage: storage),
            targetDirectory: target,
            maxRetained: 3
        )
        _ = try service.performBackup()

        let remaining = try service.listBackups()
        XCTAssertEqual(remaining.count, 3)
        // Oldest two should be deleted.
        XCTAssertFalse(FileManager.default.fileExists(atPath: seededURLs[0].path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: seededURLs[1].path))
    }

    func testListBackupsReturnsEmptyWhenDirectoryMissing() throws {
        let context = container.mainContext
        let target = rootDirectory.appendingPathComponent("nonexistent")
        let service = BackupService(
            exporter: ExportService(context: context, storage: storage),
            targetDirectory: target
        )
        XCTAssertEqual(try service.listBackups(), [])
    }
}
