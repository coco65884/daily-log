import ActivityKit
import Foundation

/// ロック画面 / Dynamic Island 表示に使う ActivityKit の attributes。
///
/// 不変属性 (テンプレ情報) は `ActivityAttributes` 側、時刻のみ動的な
/// `ContentState` 側にまとめる。
struct DailyLogActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let startAt: Date
    }

    let templateName: String
    let iconName: String
    let colorHex: String
    let isMealType: Bool
}
