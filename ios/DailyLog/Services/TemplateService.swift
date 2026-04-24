import Foundation
import SwiftData

@MainActor
struct TemplateService {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    func create(
        name: String,
        iconName: String = "circle",
        colorHex: String = "#4A90E2",
        reminderMinutes: Int? = nil,
        isMealType: Bool = false,
        parent: ActivityTemplate? = nil
    ) throws -> ActivityTemplate {
        let nextOrder = try (siblings(of: parent).map(\.sortOrder).max() ?? -1) + 1
        let template = ActivityTemplate(
            name: name,
            iconName: iconName,
            colorHex: colorHex,
            sortOrder: nextOrder,
            reminderMinutes: reminderMinutes,
            isMealType: isMealType,
            parent: parent
        )
        context.insert(template)
        try context.save()
        return template
    }

    func save() throws {
        try context.save()
    }

    func delete(_ template: ActivityTemplate) throws {
        context.delete(template)
        try context.save()
    }

    func reorder(
        siblings ordered: [ActivityTemplate],
        from source: IndexSet,
        to destination: Int
    ) throws {
        var array = ordered
        array.move(fromOffsets: source, toOffset: destination)
        for (index, template) in array.enumerated() {
            template.sortOrder = index
        }
        try context.save()
    }

    func siblings(of parent: ActivityTemplate?) throws -> [ActivityTemplate] {
        if let parent {
            return parent.children.sorted { $0.sortOrder < $1.sortOrder }
        } else {
            let all = try context.fetch(FetchDescriptor<ActivityTemplate>())
            return all
                .filter { $0.parent == nil }
                .sorted { $0.sortOrder < $1.sortOrder }
        }
    }
}
