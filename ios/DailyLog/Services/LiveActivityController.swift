import ActivityKit
import Foundation

/// 行動開始/停止に連動して ActivityKit の Live Activity を制御する。
///
/// `ActivityKit.Activity` と SwiftData の `Activity` クラスが同名なので、
/// 明示的なフルパスで参照する。
@MainActor
struct LiveActivityController {
    static let shared = LiveActivityController()

    func start(template: ActivityTemplate, startAt: Date) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = DailyLogActivityAttributes(
            templateName: template.name,
            iconName: template.iconName,
            colorHex: template.colorHex,
            isMealType: template.isMealType
        )
        let state = DailyLogActivityAttributes.ContentState(startAt: startAt)
        let content = ActivityContent(state: state, staleDate: nil)

        do {
            _ = try ActivityKit.Activity<DailyLogActivityAttributes>.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
        } catch {
            // ユーザー拒否など。失敗は silent (アプリ本体は動作継続)。
        }
    }

    func endAll() async {
        for activity in ActivityKit.Activity<DailyLogActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
