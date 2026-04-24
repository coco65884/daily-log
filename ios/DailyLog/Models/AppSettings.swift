import Foundation
import SwiftData

@Model
final class AppSettings {
    var id: UUID = UUID()
    var iCloudSyncEnabled: Bool = false
    var defaultReminderMinutes: Int = 30
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        iCloudSyncEnabled: Bool = false,
        defaultReminderMinutes: Int = 30,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.iCloudSyncEnabled = iCloudSyncEnabled
        self.defaultReminderMinutes = defaultReminderMinutes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
