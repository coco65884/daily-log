import Foundation

/// Live Activity / ロック画面に表示する「次の候補アクション」の最小情報。
///
/// テンプレ ID を持つことで、ロック画面ボタンから直接そのアクションを開始できる
/// (StartTemplateIntent 経由)。
struct NextActionCandidate: Codable, Hashable, Identifiable {
    var id: UUID {
        templateID
    }

    let templateID: UUID
    let name: String
    let iconName: String
    let colorHex: String
}
