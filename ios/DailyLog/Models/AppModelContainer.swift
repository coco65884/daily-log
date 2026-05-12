import Foundation
import SwiftData

enum AppModelContainer {
    static let schema = Schema([
        ActivityTemplate.self,
        Activity.self,
        Meal.self,
        AppSettings.self,
    ])

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let cloudKit: ModelConfiguration.CloudKitDatabase = if inMemory || !AppPreferences.iCloudSyncEnabled {
            .none
        } else {
            .automatic
        }
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: cloudKit
        )
        let container = try ModelContainer(for: schema, configurations: configuration)
        if !inMemory {
            try seedIfNeeded(container: container)
            try applyAlertDefaultsV2IfNeeded(container: container)
        }
        return container
    }

    /// 既存テンプレのアラート分数を新デフォルト (#56) に再適用する。一度だけ走る。
    /// 「既存も全部上書き」のため、ユーザー手動変更も含めて新デフォルトで置換する。
    static func applyAlertDefaultsV2IfNeeded(container: ModelContainer) throws {
        guard !AppPreferences.alertDefaultsV2Applied else { return }
        let context = ModelContext(container)
        let templates = try context.fetch(FetchDescriptor<ActivityTemplate>())
        for template in templates {
            if let minutes = DefaultTemplates.reminderDefaultsByName[template.name] {
                template.reminderMinutes = minutes
            }
        }
        if context.hasChanges {
            try context.save()
        }
        AppPreferences.alertDefaultsV2Applied = true
    }

    static func reseedDefaultTemplates(in context: ModelContext) throws {
        let existingNames = try Set(context.fetch(FetchDescriptor<ActivityTemplate>()).map(\.name))
        let existingMaxSort = try context.fetch(FetchDescriptor<ActivityTemplate>()).map(\.sortOrder).max() ?? -1
        var nextSort = existingMaxSort + 1
        for preset in DefaultTemplates.presets where !existingNames.contains(preset.name) {
            context.insert(ActivityTemplate(
                name: preset.name,
                iconName: preset.iconName,
                colorHex: preset.colorHex,
                sortOrder: nextSort,
                reminderMinutes: preset.reminderMinutes,
                isMealType: preset.isMealType
            ))
            nextSort += 1
        }
        try context.save()
    }

    private static func seedIfNeeded(container: ModelContainer) throws {
        let context = ModelContext(container)
        let templateCount = try context.fetchCount(FetchDescriptor<ActivityTemplate>())
        if templateCount == 0 {
            for (index, preset) in DefaultTemplates.presets.enumerated() {
                let template = ActivityTemplate(
                    name: preset.name,
                    iconName: preset.iconName,
                    colorHex: preset.colorHex,
                    sortOrder: index,
                    reminderMinutes: preset.reminderMinutes,
                    isMealType: preset.isMealType
                )
                context.insert(template)
            }
        }

        let settingsCount = try context.fetchCount(FetchDescriptor<AppSettings>())
        if settingsCount == 0 {
            context.insert(AppSettings())
        }

        if context.hasChanges {
            try context.save()
        }
    }
}
