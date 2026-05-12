import ActivityKit
import Foundation
import os.log

/// 行動開始/停止に連動して ActivityKit の Live Activity を制御する。
///
/// `ActivityKit.Activity` と SwiftData の `Activity` クラスが同名なので、
/// 明示的なフルパスで参照する。
///
/// API は SwiftData モデルではなく value-type のパラメータを受け取る。
/// 非同期で利用する場面 (Task で endAll → start の直列化) で、呼び出し元の
/// 寿命が切れた managed object に依存しないようにするため。
@MainActor
struct LiveActivityController {
    static let shared = LiveActivityController()

    private static let log = Logger(subsystem: "com.coco.daily-log", category: "LiveActivity")

    func start(
        templateName: String,
        iconName: String,
        colorHex: String,
        isMealType: Bool,
        startAt: Date,
        nextCandidates: [NextActionCandidate] = []
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            Self.log.info("areActivitiesEnabled=false — Live Activity をスキップ。設定>DailyLog>Live Activities を確認。")
            return
        }

        let attributes = DailyLogActivityAttributes(
            templateName: templateName,
            iconName: iconName,
            colorHex: colorHex,
            isMealType: isMealType
        )
        let state = DailyLogActivityAttributes.ContentState(
            startAt: startAt,
            nextCandidates: nextCandidates
        )
        let content = ActivityContent(state: state, staleDate: nil)

        do {
            let activity = try ActivityKit.Activity<DailyLogActivityAttributes>.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            Self.log
                .info(
                    "Live Activity 開始: id=\(activity.id, privacy: .public) template=\(templateName, privacy: .public)"
                )
        } catch {
            Self.log.error("Live Activity の request に失敗: \(error.localizedDescription, privacy: .public)")
        }
    }

    func endAll() async {
        for activity in ActivityKit.Activity<DailyLogActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
