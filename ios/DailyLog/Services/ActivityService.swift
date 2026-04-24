import Foundation
import SwiftData

/// 行動の開始/停止ロジック。
///
/// **不変条件**: 進行中の `Activity` (`endAt == nil`) は常に高々 1 件。
/// `start` は既存の進行中を全て停止してから新規作成する。
/// 忘れアラートのスケジュール/キャンセルを `ActivityNotifier` 経由で発火する。
@MainActor
struct ActivityService {
    private let context: ModelContext
    private let notifier: any ActivityNotifier

    init(context: ModelContext, notifier: any ActivityNotifier = LocalNotificationNotifier.shared) {
        self.context = context
        self.notifier = notifier
    }

    /// 既存の進行中があれば停止し、指定テンプレートで新しい Activity を開始する。
    @discardableResult
    func start(template: ActivityTemplate, at now: Date = Date()) throws -> Activity {
        let closed = try stopAllInProgress(at: now)
        for activity in closed {
            notifier.cancelReminder(for: activity)
        }
        let activity = Activity(template: template, startAt: now)
        context.insert(activity)
        try context.save()
        notifier.scheduleReminder(for: activity)
        return activity
    }

    /// 最も古い進行中を 1 件停止して返す。複数ある場合は防御的に全て停止する。
    @discardableResult
    func stopCurrent(at now: Date = Date()) throws -> Activity? {
        let closed = try stopAllInProgress(at: now)
        for activity in closed {
            notifier.cancelReminder(for: activity)
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
}
