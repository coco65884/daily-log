import Foundation
import UserNotifications

/// 行動の忘れアラートを扱う抽象。
///
/// 本番実装は `LocalNotificationNotifier`、テストはモックに差し替える。
@MainActor
protocol ActivityNotifier {
    func requestAuthorizationIfNeeded() async
    func scheduleReminder(for activity: Activity)
    func cancelReminder(for activity: Activity)
}

@MainActor
final class LocalNotificationNotifier: ActivityNotifier {
    static let shared = LocalNotificationNotifier()

    private let center = UNUserNotificationCenter.current()
    private let identifierPrefix = "activity-reminder-"

    private init() {}

    func requestAuthorizationIfNeeded() async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    func scheduleReminder(for activity: Activity) {
        guard
            let template = activity.template,
            let minutes = template.reminderMinutes,
            minutes > 0
        else {
            return
        }

        // Activity は Sendable ではないため、必要な値だけコピーして detached Task に渡す。
        let identifier = identifier(for: activity.id)
        let templateName = template.name

        Task {
            await self.scheduleInternal(
                identifier: identifier,
                templateName: templateName,
                minutes: minutes
            )
        }
    }

    func cancelReminder(for activity: Activity) {
        let identifier = identifier(for: activity.id)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    private func scheduleInternal(identifier: String, templateName: String, minutes: Int) async {
        let content = UNMutableNotificationContent()
        content.title = "まだ\(templateName)してる？"
        content.body = "\(minutes) 分経過しました。終わっていれば停止してください。"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(minutes) * 60,
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        _ = try? await center.add(request)
    }

    private func identifier(for activityID: UUID) -> String {
        identifierPrefix + activityID.uuidString
    }
}
