import Foundation
import SwiftData

enum AppModelContainer {
    static let schema = Schema([
        ActivityTemplate.self,
        Activity.self,
        Meal.self,
        AppSettings.self
    ])

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: schema, configurations: configuration)
        if !inMemory {
            try seedIfNeeded(container: container)
        }
        return container
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
                    reminderMinutes: preset.reminderMinutes
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
