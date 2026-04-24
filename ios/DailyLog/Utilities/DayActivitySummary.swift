import Foundation

/// 1 日分の Activity をテンプレート別に集計して円グラフ用のスライスに変換する。
enum DayActivitySummary {
    struct Slice: Identifiable, Equatable {
        let id = UUID()
        let templateID: UUID? // nil は未分類
        let templateName: String
        let colorHex: String
        let totalSeconds: TimeInterval
    }

    /// 指定日の Activity をテンプレートごとに合算。合計秒数降順でソート。
    /// 日付境界をまたぐ Activity はその日に属する時間分のみを計上する。
    /// 進行中 Activity は `now` でクリップ。
    static func slices(
        for activities: [Activity],
        on day: Date,
        calendar: Calendar = .currentGregorian,
        now: Date = Date()
    ) -> [Slice] {
        let dayStart = calendar.startOfDay(for: day)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }

        struct Bucket {
            var name: String
            var colorHex: String
            var seconds: TimeInterval
        }

        var buckets: [UUID?: Bucket] = [:]

        for activity in activities {
            let effectiveEnd = activity.endAt ?? now
            let clippedStart = max(activity.startAt, dayStart)
            let clippedEnd = min(effectiveEnd, dayEnd)
            guard clippedEnd > clippedStart else { continue }
            let seconds = clippedEnd.timeIntervalSince(clippedStart)

            let key: UUID? = activity.template?.id
            let name = activity.template?.name ?? "（未分類）"
            let color = activity.template?.colorHex ?? "#7F8C8D"
            if var existing = buckets[key] {
                existing.seconds += seconds
                buckets[key] = existing
            } else {
                buckets[key] = Bucket(name: name, colorHex: color, seconds: seconds)
            }
        }

        return buckets
            .map { key, bucket in
                Slice(
                    templateID: key,
                    templateName: bucket.name,
                    colorHex: bucket.colorHex,
                    totalSeconds: bucket.seconds
                )
            }
            .sorted { $0.totalSeconds > $1.totalSeconds }
    }
}
