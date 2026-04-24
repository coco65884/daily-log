import Foundation
import SwiftData
import ZIPFoundation

/// エクスポート ZIP を読み込んで SwiftData に書き戻す。
@MainActor
struct ImportService {
    enum Mode {
        /// 既存データを保持しつつ、import 分を新規追加 or 既存 ID の上書き。
        case merge
        /// 既存の全 Activity / Template / Meal / AppSettings を削除してから import。
        case replace
    }

    enum ImportError: LocalizedError {
        case missingDataJSON
        case unsupportedSchemaVersion(Int)

        var errorDescription: String? {
            switch self {
            case .missingDataJSON:
                "バックアップに data.json が含まれていません"
            case let .unsupportedSchemaVersion(version):
                "未対応のスキーマバージョン: \(version)"
            }
        }
    }

    struct ImportResult: Equatable {
        let templatesImported: Int
        let activitiesImported: Int
        let mealsImported: Int
        let photosRestored: Int
    }

    private let context: ModelContext
    private let storage: PhotoStorage?

    init(context: ModelContext, storage: PhotoStorage? = PhotoStorage.makeDefault()) {
        self.context = context
        self.storage = storage
    }

    @discardableResult
    func importArchive(at zipURL: URL, mode: Mode) throws -> ImportResult {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DailyLogImport-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try FileManager.default.unzipItem(at: zipURL, to: tempDir)

        guard let jsonURL = locateDataJSON(in: tempDir) else {
            throw ImportError.missingDataJSON
        }
        let snapshot = try loadSnapshot(from: jsonURL)
        guard snapshot.schemaVersion == ExportSnapshot.currentSchemaVersion else {
            throw ImportError.unsupportedSchemaVersion(snapshot.schemaVersion)
        }

        if mode == .replace {
            try deleteAllRecords()
        }

        let counts = try applySnapshot(snapshot)
        let photoCount = try restorePhotos(from: tempDir)
        try context.save()

        return ImportResult(
            templatesImported: counts.templates,
            activitiesImported: counts.activities,
            mealsImported: counts.meals,
            photosRestored: photoCount
        )
    }

    // MARK: - Extraction

    private func locateDataJSON(in directory: URL) -> URL? {
        let root = directory.appendingPathComponent("data.json")
        if FileManager.default.fileExists(atPath: root.path) {
            return root
        }
        let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil)
        while let url = enumerator?.nextObject() as? URL {
            if url.lastPathComponent == "data.json" {
                return url
            }
        }
        return nil
    }

    private func loadSnapshot(from url: URL) throws -> ExportSnapshot {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try decoder.decode(ExportSnapshot.self, from: data)
    }

    private func deleteAllRecords() throws {
        try context.delete(model: Activity.self)
        try context.delete(model: Meal.self)
        try context.delete(model: ActivityTemplate.self)
        try context.delete(model: AppSettings.self)
    }

    // MARK: - Apply

    private struct ImportCounts {
        let templates: Int
        let activities: Int
        let meals: Int
    }

    private func applySnapshot(_ snapshot: ExportSnapshot) throws -> ImportCounts {
        let templates = try applyTemplates(snapshot.templates)
        let activities = applyActivities(snapshot.activities, templates: templates)
        applyMeals(snapshot.meals, activities: activities)
        applySettings(snapshot.settings)
        return ImportCounts(
            templates: snapshot.templates.count,
            activities: snapshot.activities.count,
            meals: snapshot.meals.count
        )
    }

    private func applyTemplates(_ records: [ExportSnapshot.Template]) throws -> [UUID: ActivityTemplate] {
        let existing = try context.fetch(FetchDescriptor<ActivityTemplate>())
        var templatesByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        for record in records {
            let template = templatesByID[record.id] ?? ActivityTemplate(name: record.name)
            template.id = record.id
            template.name = record.name
            template.iconName = record.iconName
            template.colorHex = record.colorHex
            template.sortOrder = record.sortOrder
            template.reminderMinutes = record.reminderMinutes
            template.isMealType = record.isMealType
            template.createdAt = record.createdAt
            if templatesByID[record.id] == nil {
                context.insert(template)
                templatesByID[record.id] = template
            }
        }
        // Second pass so parents and children both exist.
        for record in records {
            templatesByID[record.id]?.parent = record.parentID.flatMap { templatesByID[$0] }
        }
        return templatesByID
    }

    private func applyActivities(
        _ records: [ExportSnapshot.ActivityRecord],
        templates: [UUID: ActivityTemplate]
    ) -> [UUID: Activity] {
        let existing = (try? context.fetch(FetchDescriptor<Activity>())) ?? []
        var activitiesByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        for record in records {
            let activity = activitiesByID[record.id] ?? Activity(startAt: record.startAt)
            activity.id = record.id
            activity.startAt = record.startAt
            activity.endAt = record.endAt
            activity.note = record.note
            activity.voiceNoteFilename = record.voiceNoteFilename
            activity.voiceTranscript = record.voiceTranscript
            activity.createdAt = record.createdAt
            activity.template = record.templateID.flatMap { templates[$0] }
            if activitiesByID[record.id] == nil {
                context.insert(activity)
                activitiesByID[record.id] = activity
            }
        }
        return activitiesByID
    }

    private func applyMeals(_ records: [ExportSnapshot.MealRecord], activities: [UUID: Activity]) {
        let existing = (try? context.fetch(FetchDescriptor<Meal>())) ?? []
        var mealsByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        for record in records {
            let meal = mealsByID[record.id] ?? Meal()
            meal.id = record.id
            meal.photoFilenames = record.photoFilenames
            meal.shopName = record.shopName
            meal.shopAddress = record.shopAddress
            meal.note = record.note
            meal.createdAt = record.createdAt
            meal.activity = record.activityID.flatMap { activities[$0] }
            if mealsByID[record.id] == nil {
                context.insert(meal)
                mealsByID[record.id] = meal
            }
        }
    }

    private func applySettings(_ records: [ExportSnapshot.SettingsRecord]) {
        for record in records {
            let settings = AppSettings(
                id: record.id,
                iCloudSyncEnabled: record.iCloudSyncEnabled,
                defaultReminderMinutes: record.defaultReminderMinutes,
                createdAt: record.createdAt,
                updatedAt: record.updatedAt
            )
            context.insert(settings)
        }
    }

    // MARK: - Photos

    private func restorePhotos(from extractDir: URL) throws -> Int {
        guard let storage else { return 0 }
        let photosRoot: URL? = {
            let direct = extractDir.appendingPathComponent("photos", isDirectory: true)
            if FileManager.default.fileExists(atPath: direct.path) { return direct }
            // Zip might have wrapped in a parent directory
            let enumerator = FileManager.default.enumerator(
                at: extractDir,
                includingPropertiesForKeys: [.isDirectoryKey]
            )
            while let url = enumerator?.nextObject() as? URL {
                let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
                if isDir, url.lastPathComponent == "photos" {
                    return url
                }
            }
            return nil
        }()
        guard let photosRoot else { return 0 }

        var restored = 0
        let files = try FileManager.default.contentsOfDirectory(
            at: photosRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        for source in files {
            let data = try Data(contentsOf: source)
            _ = try storage.saveJPEGPreservingFilename(data, filename: source.lastPathComponent)
            restored += 1
        }
        return restored
    }
}

extension PhotoStorage {
    /// インポート時にファイル名を維持したまま保存したいので、通常の `save*` とは別経路。
    @discardableResult
    func saveJPEGPreservingFilename(_ data: Data, filename: String) throws -> String {
        try FileManager.default.createDirectory(
            at: rootURL,
            withIntermediateDirectories: true
        )
        let url = rootURL.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return filename
    }
}
