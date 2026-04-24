import Foundation
import SwiftData

@Model
final class Activity {
    var id: UUID = UUID()
    var startAt: Date = Date()
    var endAt: Date?
    var note: String = ""
    var voiceNoteFilename: String?
    var voiceTranscript: String?
    var createdAt: Date = Date()

    var template: ActivityTemplate?

    @Relationship(deleteRule: .cascade, inverse: \Meal.activity)
    var meal: Meal?

    init(
        id: UUID = UUID(),
        template: ActivityTemplate? = nil,
        startAt: Date = Date(),
        endAt: Date? = nil,
        note: String = "",
        voiceNoteFilename: String? = nil,
        voiceTranscript: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.template = template
        self.startAt = startAt
        self.endAt = endAt
        self.note = note
        self.voiceNoteFilename = voiceNoteFilename
        self.voiceTranscript = voiceTranscript
        self.createdAt = createdAt
    }

    var isInProgress: Bool {
        endAt == nil
    }

    var duration: TimeInterval? {
        guard let endAt else { return nil }
        return endAt.timeIntervalSince(startAt)
    }
}
