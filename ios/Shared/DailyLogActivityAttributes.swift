import ActivityKit
import Foundation

/// ロック画面 / Dynamic Island 表示に使う ActivityKit の attributes。
///
/// 不変属性 (現在のテンプレ情報) は `ActivityAttributes` 側、可変な
/// `ContentState` 側には次候補リストを持たせる。
struct DailyLogActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let startAt: Date
        let nextCandidates: [NextActionCandidate]

        init(startAt: Date, nextCandidates: [NextActionCandidate] = []) {
            self.startAt = startAt
            self.nextCandidates = nextCandidates
        }
    }

    let templateName: String
    let iconName: String
    let colorHex: String
    let isMealType: Bool
}
