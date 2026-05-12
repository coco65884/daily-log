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
            let color = displayColor(for: activity.template)
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

    /// 表示色を決定する。親テンプレを持つ場合は親色を sortOrder で濃淡シフトした色を返す。
    private static func displayColor(for template: ActivityTemplate?) -> String {
        guard let template else { return "#7F8C8D" }
        guard let parent = template.parent else { return template.colorHex }
        let siblings = parent.children.sorted { $0.sortOrder < $1.sortOrder }
        let index = siblings.firstIndex(where: { $0.id == template.id }) ?? 0
        return HexColor.shaded(parentHex: parent.colorHex, childIndex: index)
    }
}
