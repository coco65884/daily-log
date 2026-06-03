import Foundation

/// 週ビューのチャート用に `Activity` を曜日 × 時間帯の区間に変換する。
enum WeekActivityLayout {
    struct Span: Identifiable, Equatable {
        let id: UUID
        let activityID: UUID
        let weekdayIndex: Int // 0 = 週頭の曜日 から 6 = 週末
        let startHours: Double // 0.0 ... 24.0
        let endHours: Double // startHours < endHours ≤ 24.0
        let colorHex: String
        let templateName: String
        let startDate: Date // このチャンクの実開始時刻
        let endDate: Date // このチャンクの実終了時刻
    }

    /// 指定週内の Activity を Span 配列に変換する。
    /// 日をまたぐ Activity は 1 日ごとに分割する。
    /// 進行中 (`endAt == nil`) は `now` で切ってそこまでを表示。
    static func spans(
        for activities: [Activity],
        weekStart: Date,
        calendar: Calendar = .currentGregorian,
        now: Date = Date()
    ) -> [Span] {
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
        var spans: [Span] = []

        for activity in activities {
            let effectiveEnd = activity.endAt ?? now
            // 週外は除外
            guard activity.startAt < weekEnd, effectiveEnd > weekStart else { continue }

            let clippedStart = max(activity.startAt, weekStart)
            let clippedEnd = min(effectiveEnd, weekEnd)
            guard clippedEnd > clippedStart else { continue }

            var cursor = clippedStart
            while cursor < clippedEnd {
                let dayStart = calendar.startOfDay(for: cursor)
                guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { break }
                let chunkEnd = min(clippedEnd, dayEnd)

                let weekdayIndex = Int(
                    (cursor.timeIntervalSince(weekStart) / 86400).rounded(.down)
                )
                guard weekdayIndex >= 0, weekdayIndex < 7 else {
                    cursor = dayEnd
                    continue
                }

                let startHours = hours(from: dayStart, to: cursor)
                let endHours = hours(from: dayStart, to: chunkEnd)

                spans.append(
                    Span(
                        id: UUID(),
                        activityID: activity.id,
                        weekdayIndex: weekdayIndex,
                        startHours: startHours,
                        endHours: endHours,
                        colorHex: activity.template?.colorHex ?? "#7F8C8D",
                        templateName: activity.template?.name ?? "—",
                        startDate: cursor,
                        endDate: chunkEnd
                    )
                )

                cursor = chunkEnd
            }
        }

        return spans
    }

    /// 指定日が属する週の先頭日 (00:00) を返す。
    /// カレンダーの `firstWeekday` に従う (日本は日曜始まり、ドイツは月曜始まり)。
    static func weekStart(
        containing date: Date,
        calendar: Calendar = .currentGregorian
    ) -> Date {
        let weekday = calendar.component(.weekday, from: date)
        let offset = (weekday - calendar.firstWeekday + 7) % 7
        let dayStart = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: -offset, to: dayStart) ?? dayStart
    }

    private static func hours(from start: Date, to end: Date) -> Double {
        end.timeIntervalSince(start) / 3600
    }
}
