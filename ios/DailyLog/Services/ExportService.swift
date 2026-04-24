import Foundation
import SwiftData

/// 全 SwiftData レコードと写真を ZIP にまとめる。
@MainActor
struct ExportService {
    private let context: ModelContext
    private let storage: PhotoStorage?
    private let now: () -> Date

    init(
        context: ModelContext,
        storage: PhotoStorage? = PhotoStorage.makeDefault(),
        now: @escaping () -> Date = Date.init
    ) {
        self.context = context
        self.storage = storage
        self.now = now
    }

    /// 一時ディレクトリに ZIP を作って URL を返す。呼び出し側はシェア後に削除する。
    func makeArchive() throws -> URL {
        let snapshot = try buildSnapshot()

        let tempRoot = FileManager.default.temporaryDirectory
        let sessionDir = tempRoot.appendingPathComponent("DailyLogExport-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: sessionDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: sessionDir) }

        try writeSnapshotJSON(snapshot, in: sessionDir)
        try copyPhotos(for: snapshot, to: sessionDir)

        let zipURL = tempRoot.appendingPathComponent("DailyLog-\(timestampFilename()).zip")
        try zipDirectory(sessionDir, to: zipURL)
        return zipURL
    }

    func buildSnapshot() throws -> ExportSnapshot {
        let templates = try context.fetch(FetchDescriptor<ActivityTemplate>())
        let activities = try context.fetch(FetchDescriptor<Activity>())
        let meals = try context.fetch(FetchDescriptor<Meal>())
        let settings = try context.fetch(FetchDescriptor<AppSettings>())

        return ExportSnapshot(
            schemaVersion: ExportSnapshot.currentSchemaVersion,
            exportedAt: now(),
            templates: templates.map { template in
                ExportSnapshot.Template(
                    id: template.id,
                    name: template.name,
                    iconName: template.iconName,
                    colorHex: template.colorHex,
                    sortOrder: template.sortOrder,
                    reminderMinutes: template.reminderMinutes,
                    isMealType: template.isMealType,
                    parentID: template.parent?.id,
                    createdAt: template.createdAt
                )
            },
            activities: activities.map { activity in
                ExportSnapshot.ActivityRecord(
                    id: activity.id,
                    templateID: activity.template?.id,
                    startAt: activity.startAt,
                    endAt: activity.endAt,
                    note: activity.note,
                    voiceNoteFilename: activity.voiceNoteFilename,
                    voiceTranscript: activity.voiceTranscript,
                    mealID: activity.meal?.id,
                    createdAt: activity.createdAt
                )
            },
            meals: meals.map { meal in
                ExportSnapshot.MealRecord(
                    id: meal.id,
                    activityID: meal.activity?.id,
                    photoFilenames: meal.photoFilenames,
                    shopName: meal.shopName,
                    shopAddress: meal.shopAddress,
                    note: meal.note,
                    createdAt: meal.createdAt
                )
            },
            settings: settings.map { settings in
                ExportSnapshot.SettingsRecord(
                    id: settings.id,
                    iCloudSyncEnabled: settings.iCloudSyncEnabled,
                    defaultReminderMinutes: settings.defaultReminderMinutes,
                    createdAt: settings.createdAt,
                    updatedAt: settings.updatedAt
                )
            }
        )
    }

    private func writeSnapshotJSON(_ snapshot: ExportSnapshot, in directory: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(snapshot)
        let url = directory.appendingPathComponent("data.json")
        try data.write(to: url, options: .atomic)
    }

    private func copyPhotos(for snapshot: ExportSnapshot, to directory: URL) throws {
        guard let storage else { return }
        let filenames = Set(snapshot.meals.flatMap(\.photoFilenames))
        guard !filenames.isEmpty else { return }
        let photosDir = directory.appendingPathComponent("photos", isDirectory: true)
        try FileManager.default.createDirectory(at: photosDir, withIntermediateDirectories: true)
        for filename in filenames {
            let source = storage.url(for: filename)
            guard FileManager.default.fileExists(atPath: source.path) else { continue }
            let destination = photosDir.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: source, to: destination)
        }
    }

    private func zipDirectory(_ sourceDir: URL, to destinationURL: URL) throws {
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        let coordinator = NSFileCoordinator()
        var coordinatorError: NSError?
        var innerError: Error?
        coordinator.coordinate(
            readingItemAt: sourceDir,
            options: [.forUploading],
            error: &coordinatorError
        ) { tempZipURL in
            do {
                try FileManager.default.copyItem(at: tempZipURL, to: destinationURL)
            } catch {
                innerError = error
            }
        }
        if let coordinatorError { throw coordinatorError }
        if let innerError { throw innerError }
    }

    private func timestampFilename() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: now())
    }
}
