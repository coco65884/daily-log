import Foundation

/// エクスポートファイルの最上位スキーマ。`#21` (エクスポート) と `#23` (インポート) で共用。
struct ExportSnapshot: Codable, Equatable {
    static let currentSchemaVersion = 1

    struct Template: Codable, Equatable {
        let id: UUID
        let name: String
        let iconName: String
        let colorHex: String
        let sortOrder: Int
        let reminderMinutes: Int?
        let isMealType: Bool
        let parentID: UUID?
        let createdAt: Date
    }

    struct ActivityRecord: Codable, Equatable {
        let id: UUID
        let templateID: UUID?
        let startAt: Date
        let endAt: Date?
        let note: String
        let voiceNoteFilename: String?
        let voiceTranscript: String?
        let mealID: UUID?
        let createdAt: Date
    }

    struct MealRecord: Codable, Equatable {
        let id: UUID
        let activityID: UUID?
        let photoFilenames: [String]
        let shopName: String?
        let shopAddress: String?
        let note: String
        let createdAt: Date
    }

    struct SettingsRecord: Codable, Equatable {
        let id: UUID
        let iCloudSyncEnabled: Bool
        let defaultReminderMinutes: Int
        let createdAt: Date
        let updatedAt: Date
    }

    let schemaVersion: Int
    let exportedAt: Date
    let templates: [Template]
    let activities: [ActivityRecord]
    let meals: [MealRecord]
    let settings: [SettingsRecord]
}
