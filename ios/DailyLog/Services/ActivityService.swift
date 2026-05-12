import Foundation
import SwiftData
import WidgetKit

/// 行動の開始/停止ロジック。
///
/// **不変条件**: 進行中の `Activity` (`endAt == nil`) は常に高々 1 件。
/// `start` は既存の進行中を全て停止してから新規作成する。
/// 忘れアラートのスケジュール/キャンセルを `ActivityNotifier` 経由で発火する。
/// 進行中スナップショットを App Group に書き込み、ウィジェットを再読み込みさせる。
@MainActor
struct ActivityService {
    private let context: ModelContext
    private let notifier: any ActivityNotifier

    init(context: ModelContext, notifier: (any ActivityNotifier)? = nil) {
        self.context = context
        // @MainActor singleton を default parameter にすると non-isolated 文脈の警告が出るため
        // init 本体 (この struct 自体 MainActor) で参照する。
        self.notifier = notifier ?? LocalNotificationNotifier.shared
    }

    /// 既存の進行中があれば停止し、指定テンプレートで新しい Activity を開始する。
    @discardableResult
    func start(template: ActivityTemplate, at now: Date = Date()) throws -> Activity {
        let closed = try stopAllInProgress(at: now)
        for activity in closed {
            notifier.cancelReminder(for: activity)
        }
        let candidates = (try? predictNextCandidates(excluding: template.id, at: now)) ?? []
        let activity = Activity(template: template, startAt: now)
        context.insert(activity)
        try context.save()
        if AppPreferences.notificationsEnabled {
            notifier.scheduleReminder(for: activity)
        }
        publishSnapshot(for: activity)
        // 過去分を await で片付けてから新規 Live Activity を request する。
        // 順序が逆だと、新規作成直後の endAll が今作ったものまで end してしまい、
        // ロック画面から消える (Issue #70)。
        Task { @MainActor in
            await LiveActivityController.shared.endAll()
            LiveActivityController.shared.start(
                template: template,
                startAt: now,
                nextCandidates: candidates
            )
        }
        return activity
    }

    private func predictNextCandidates(
        excluding excludedID: UUID,
        at now: Date,
        limit: Int = NextActionPredictor.defaultLimit
    ) throws -> [NextActionCandidate] {
        let predictor = NextActionPredictor()
        let templates = try predictor.predict(
            at: now,
            in: context,
            excluding: excludedID,
            limit: limit
        )
        return templates.map { template in
            NextActionCandidate(
                templateID: template.id,
                name: template.name,
                iconName: template.iconName,
                colorHex: template.colorHex
            )
        }
    }

    /// 最も古い進行中を 1 件停止して返す。複数ある場合は防御的に全て停止する。
    @discardableResult
    func stopCurrent(at now: Date = Date()) throws -> Activity? {
        let closed = try stopAllInProgress(at: now)
        for activity in closed {
            notifier.cancelReminder(for: activity)
        }
        if !closed.isEmpty {
            publishSnapshot(for: nil)
            Task { await LiveActivityController.shared.endAll() }
        }
        return closed.first
    }

    func fetchInProgress() throws -> [Activity] {
        let descriptor = FetchDescriptor<Activity>(
            predicate: #Predicate { $0.endAt == nil },
            sortBy: [SortDescriptor(\Activity.startAt)]
        )
        return try context.fetch(descriptor)
    }

    @discardableResult
    private func stopAllInProgress(at now: Date) throws -> [Activity] {
        let inProgress = try fetchInProgress()
        guard !inProgress.isEmpty else { return [] }
        for activity in inProgress {
            activity.endAt = now
        }
        try context.save()
        return inProgress
    }

    private func publishSnapshot(for activity: Activity?) {
        let snapshot: CurrentActivitySnapshot? = activity.flatMap { act in
            guard let template = act.template else { return nil }
            return CurrentActivitySnapshot(
                templateName: template.name,
                iconName: template.iconName,
                colorHex: template.colorHex,
                startAt: act.startAt,
                isMealType: template.isMealType
            )
        }
        CurrentActivitySnapshot.store(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
