import Foundation

/// 記録済み Activity から「年月日」単位の `DateComponents` 集合を作る。
/// UICalendarView の decoration 表示や day-view の検索に使う。
enum ActivityDateExtractor {
    static func extractDateComponents(
        from activities: [Activity],
        calendar: Calendar = .currentGregorian
    ) -> Set<DateComponents> {
        let components = activities.map { activity in
            calendar.dateComponents([.year, .month, .day], from: activity.startAt)
        }
        return Set(components)
    }

    static func activities(
        on day: Date,
        from activities: [Activity],
        calendar: Calendar = .currentGregorian
    ) -> [Activity] {
        let target = calendar.dateComponents([.year, .month, .day], from: day)
        return activities.filter { activity in
            let candidate = calendar.dateComponents([.year, .month, .day], from: activity.startAt)
            return candidate == target
        }
    }
}

extension Calendar {
    /// 端末のタイムゾーンに従うグレゴリオ暦。ホーム/カレンダー表示で使う既定値。
    static var currentGregorian: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }
}
