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
        spans(for: activities, rangeStart: weekStart, dayCount: 7, calendar: calendar, now: now)
    }

    /// 指定月 (referenceDate が属する月) の Activity を Span 配列に変換する。
    /// `weekdayIndex` は月内の日付インデックス (0 = 1 日)。
    static func monthSpans(
        for activities: [Activity],
        monthContaining referenceDate: Date,
        calendar: Calendar = .currentGregorian,
        now: Date = Date()
    ) -> [Span] {
        let (start, dayCount) = monthRange(containing: referenceDate, calendar: calendar)
        return spans(for: activities, rangeStart: start, dayCount: dayCount, calendar: calendar, now: now)
    }

    /// `referenceDate` が属する月の初日 (00:00) と日数を返す。
    static func monthRange(
        containing referenceDate: Date,
        calendar: Calendar = .currentGregorian
    ) -> (start: Date, dayCount: Int) {
        let components = calendar.dateComponents([.year, .month], from: referenceDate)
        let start = calendar.date(from: components) ?? calendar.startOfDay(for: referenceDate)
        let dayCount = calendar.range(of: .day, in: .month, for: start)?.count ?? 30
        return (start, dayCount)
    }

    /// `rangeStart` から `dayCount` 日分の Activity を Span 配列に変換する汎用版。
    /// 日をまたぐ Activity は 1 日ごとに分割し、`weekdayIndex` は rangeStart からの経過日数。
    static func spans(
        for activities: [Activity],
        rangeStart: Date,
        dayCount: Int,
        calendar: Calendar = .currentGregorian,
        now: Date = Date()
    ) -> [Span] {
        let rangeEnd = calendar.date(byAdding: .day, value: dayCount, to: rangeStart) ?? rangeStart
        var spans: [Span] = []

        for activity in activities {
            let effectiveEnd = activity.endAt ?? now
            // 範囲外は除外
            guard activity.startAt < rangeEnd, effectiveEnd > rangeStart else { continue }

            let clippedStart = max(activity.startAt, rangeStart)
            let clippedEnd = min(effectiveEnd, rangeEnd)
            guard clippedEnd > clippedStart else { continue }

            var cursor = clippedStart
            while cursor < clippedEnd {
                let dayStart = calendar.startOfDay(for: cursor)
                guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { break }
                let chunkEnd = min(clippedEnd, dayEnd)

                let weekdayIndex = Int(
                    (cursor.timeIntervalSince(rangeStart) / 86400).rounded(.down)
                )
                guard weekdayIndex >= 0, weekdayIndex < dayCount else {
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
