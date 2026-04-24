import Foundation

/// 週/月単位の Activity 集計。
/// - カテゴリ (テンプレート) 別合計: 親テンプレは自分 + 子の合算値を持つ
/// - 食事サマリー: 食事タイプ Activity の件数と写真枚数
enum PeriodActivitySummary {
    enum Period: String, Hashable, CaseIterable, Identifiable {
        case week
        case month

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .week: "週"
            case .month: "月"
            }
        }

        func range(
            containing date: Date,
            calendar: Calendar = .currentGregorian
        ) -> (start: Date, end: Date) {
            switch self {
            case .week:
                let start = WeekActivityLayout.weekStart(containing: date, calendar: calendar)
                let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
                return (start, end)
            case .month:
                let components = calendar.dateComponents([.year, .month], from: date)
                let start = calendar.date(from: components) ?? date
                let end = calendar.date(byAdding: .month, value: 1, to: start) ?? start
                return (start, end)
            }
        }

        func shift(_ delta: Int, from date: Date, calendar: Calendar = .currentGregorian) -> Date {
            switch self {
            case .week:
                calendar.date(byAdding: .day, value: 7 * delta, to: date) ?? date
            case .month:
                calendar.date(byAdding: .month, value: delta, to: date) ?? date
            }
        }
    }

    struct CategoryStats: Identifiable, Equatable {
        let id: UUID
        let templateName: String
        let colorHex: String
        let totalSeconds: TimeInterval
        let children: [CategoryStats]
    }

    struct MealStats: Equatable {
        let activityCount: Int
        let photoCount: Int
    }

    struct Summary: Equatable {
        let categories: [CategoryStats]
        let meal: MealStats
        let start: Date
        let end: Date
    }

    private struct Bucket {
        let template: ActivityTemplate
        var seconds: TimeInterval
    }

    static func summarize(
        activities: [Activity],
        period: Period,
        referenceDate: Date = Date(),
        calendar: Calendar = .currentGregorian,
        now: Date = Date()
    ) -> Summary {
        let (start, end) = period.range(containing: referenceDate, calendar: calendar)
        let (buckets, meal) = aggregateBuckets(activities: activities, start: start, end: end, now: now)
        let completeBuckets = fillMissingParents(in: buckets)
        let categories = buildCategoryTree(from: completeBuckets)
        return Summary(categories: categories, meal: meal, start: start, end: end)
    }

    private static func aggregateBuckets(
        activities: [Activity],
        start: Date,
        end: Date,
        now: Date
    ) -> (buckets: [UUID: Bucket], meal: MealStats) {
        var buckets: [UUID: Bucket] = [:]
        var mealCount = 0
        var photoCount = 0

        for activity in activities {
            let effectiveEnd = activity.endAt ?? now
            guard activity.startAt < end, effectiveEnd > start else { continue }
            let clippedStart = max(activity.startAt, start)
            let clippedEnd = min(effectiveEnd, end)
            let seconds = max(0, clippedEnd.timeIntervalSince(clippedStart))

            guard let template = activity.template else { continue }
            if var existing = buckets[template.id] {
                existing.seconds += seconds
                buckets[template.id] = existing
            } else {
                buckets[template.id] = Bucket(template: template, seconds: seconds)
            }
            if template.isMealType {
                mealCount += 1
                photoCount += activity.meal?.photoFilenames.count ?? 0
            }
        }

        return (buckets, MealStats(activityCount: mealCount, photoCount: photoCount))
    }

    private static func fillMissingParents(in buckets: [UUID: Bucket]) -> [UUID: Bucket] {
        var result = buckets
        for (_, bucket) in buckets {
            if let parent = bucket.template.parent, result[parent.id] == nil {
                result[parent.id] = Bucket(template: parent, seconds: 0)
            }
        }
        return result
    }

    private static func buildCategoryTree(from buckets: [UUID: Bucket]) -> [CategoryStats] {
        var childrenByParent: [UUID: [UUID]] = [:]
        var rootIDs: [UUID] = []
        for (id, bucket) in buckets {
            if let parent = bucket.template.parent {
                childrenByParent[parent.id, default: []].append(id)
            } else {
                rootIDs.append(id)
            }
        }
        return rootIDs
            .map { buildNode(id: $0, buckets: buckets, childrenByParent: childrenByParent) }
            .sorted { $0.totalSeconds > $1.totalSeconds }
    }

    private static func buildNode(
        id: UUID,
        buckets: [UUID: Bucket],
        childrenByParent: [UUID: [UUID]]
    ) -> CategoryStats {
        guard let bucket = buckets[id] else {
            return CategoryStats(
                id: id,
                templateName: "—",
                colorHex: "#7F8C8D",
                totalSeconds: 0,
                children: []
            )
        }
        let childIDs = childrenByParent[id] ?? []
        let children = childIDs
            .map { buildNode(id: $0, buckets: buckets, childrenByParent: childrenByParent) }
            .sorted { $0.totalSeconds > $1.totalSeconds }
        let childSum = children.reduce(0) { $0 + $1.totalSeconds }
        return CategoryStats(
            id: id,
            templateName: bucket.template.name,
            colorHex: bucket.template.colorHex,
            totalSeconds: bucket.seconds + childSum,
            children: children
        )
    }
}
