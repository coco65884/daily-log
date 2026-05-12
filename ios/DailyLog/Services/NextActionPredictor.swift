import Foundation
import SwiftData

/// 過去ログから「曜日 × 時間帯」に基づき次に来そうなアクションを予測する。
///
/// アルゴリズム:
/// 1. `now` の (曜日, 時間バケット) と一致する過去 Activity をテンプレ別にカウント
/// 2. カウント降順に並べる
/// 3. 同バケットで N 件に満たない場合は全期間頻度で穴埋め
/// 4. それでも不足するときは sortOrder 順で穴埋め
/// 5. 開始直後の自テンプレ + 非表示テンプレは除外
struct NextActionPredictor {
    static let defaultHourBucketSize = 1
    static let defaultLimit = 3

    let calendar: Calendar
    let hourBucketSize: Int

    init(calendar: Calendar = .current, hourBucketSize: Int = NextActionPredictor.defaultHourBucketSize) {
        self.calendar = calendar
        self.hourBucketSize = max(1, hourBucketSize)
    }

    @MainActor
    func predict(
        at now: Date,
        in context: ModelContext,
        excluding excludedTemplateID: UUID? = nil,
        limit: Int = NextActionPredictor.defaultLimit
    ) throws -> [ActivityTemplate] {
        let templates = try context.fetch(FetchDescriptor<ActivityTemplate>())
        let visibleTemplates = templates.filter { !$0.isHidden }
        guard !visibleTemplates.isEmpty else { return [] }

        let activities = try context.fetch(FetchDescriptor<Activity>())
        let targetBucket = bucket(for: now)
        let templateByID = Dictionary(uniqueKeysWithValues: visibleTemplates.map { ($0.id, $0) })

        let bucketCounts = countsByTemplate(in: activities) { activity in
            bucket(for: activity.startAt) == targetBucket
        }
        let overallCounts = countsByTemplate(in: activities) { _ in true }

        var picker = CandidatePicker(
            limit: limit,
            excluded: excludedTemplateID,
            templateByID: templateByID
        )
        picker.add(ranked: rank(counts: bucketCounts, templateByID: templateByID))
        picker.add(ranked: rank(counts: overallCounts, templateByID: templateByID))
        picker.padWithSortOrder(visibleTemplates.sorted { $0.sortOrder < $1.sortOrder })
        return picker.picked
    }

    private func countsByTemplate(
        in activities: [Activity],
        where predicate: (Activity) -> Bool
    ) -> [UUID: Int] {
        var counts: [UUID: Int] = [:]
        for activity in activities {
            guard let templateID = activity.template?.id else { continue }
            guard predicate(activity) else { continue }
            counts[templateID, default: 0] += 1
        }
        return counts
    }

    @MainActor
    private func rank(
        counts: [UUID: Int],
        templateByID: [UUID: ActivityTemplate]
    ) -> [UUID] {
        counts.sorted { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value > rhs.value }
            return (templateByID[lhs.key]?.sortOrder ?? .max) < (templateByID[rhs.key]?.sortOrder ?? .max)
        }
        .map(\.key)
    }

    func bucket(for date: Date) -> Bucket {
        let components = calendar.dateComponents([.weekday, .hour], from: date)
        let weekday = components.weekday ?? 1
        let hour = components.hour ?? 0
        return Bucket(weekday: weekday, hourBucket: hour / hourBucketSize)
    }

    struct Bucket: Hashable {
        let weekday: Int
        let hourBucket: Int
    }

    @MainActor
    fileprivate struct CandidatePicker {
        let limit: Int
        let excluded: UUID?
        let templateByID: [UUID: ActivityTemplate]
        private(set) var picked: [ActivityTemplate] = []
        private var pickedIDs = Set<UUID>()

        init(limit: Int, excluded: UUID?, templateByID: [UUID: ActivityTemplate]) {
            self.limit = limit
            self.excluded = excluded
            self.templateByID = templateByID
        }

        mutating func add(ranked ids: [UUID]) {
            for id in ids where picked.count < limit {
                addIfEligible(id: id)
            }
        }

        mutating func padWithSortOrder(_ visibleTemplates: [ActivityTemplate]) {
            for template in visibleTemplates where picked.count < limit {
                addIfEligible(id: template.id)
            }
        }

        private mutating func addIfEligible(id: UUID) {
            guard picked.count < limit else { return }
            guard id != excluded else { return }
            guard !pickedIDs.contains(id) else { return }
            guard let template = templateByID[id] else { return }
            picked.append(template)
            pickedIDs.insert(id)
        }
    }
}
