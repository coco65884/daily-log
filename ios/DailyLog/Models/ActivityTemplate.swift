import Foundation
import SwiftData

@Model
final class ActivityTemplate {
    var id: UUID = UUID()
    var name: String = ""
    var iconName: String = "circle"
    var colorHex: String = "#4A90E2"
    var sortOrder: Int = 0
    var reminderMinutes: Int?
    var createdAt: Date = Date()

    var parent: ActivityTemplate?

    @Relationship(deleteRule: .cascade, inverse: \ActivityTemplate.parent)
    var children: [ActivityTemplate] = []

    @Relationship(deleteRule: .nullify, inverse: \Activity.template)
    var activities: [Activity] = []

    init(
        id: UUID = UUID(),
        name: String,
        iconName: String = "circle",
        colorHex: String = "#4A90E2",
        sortOrder: Int = 0,
        reminderMinutes: Int? = nil,
        parent: ActivityTemplate? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        self.reminderMinutes = reminderMinutes
        self.parent = parent
        self.createdAt = createdAt
    }
}
