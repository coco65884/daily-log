import Foundation
import SwiftData

/// その日に書き残す自由メモ。`dayKey` (yyyy-MM-dd, ローカルタイム) を一意キーとして
/// 1日1メモを保持する。CloudKit 同期対象。
@Model
final class DailyMemo {
    @Attribute(.unique) var dayKey: String = ""
    var text: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        dayKey: String,
        text: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.dayKey = dayKey
        self.text = text
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    static func dayKey(for date: Date, calendar: Calendar = .currentGregorian) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
