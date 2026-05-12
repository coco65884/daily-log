import Foundation

enum DefaultTemplates {
    struct Preset {
        let name: String
        let iconName: String
        let colorHex: String
        let reminderMinutes: Int?
        let isMealType: Bool
    }

    static let presets: [Preset] = [
        Preset(name: "睡眠", iconName: "moon.fill", colorHex: "#6F5BE8", reminderMinutes: 600, isMealType: false),
        Preset(name: "食事", iconName: "fork.knife", colorHex: "#F5A623", reminderMinutes: 120, isMealType: true),
        Preset(name: "仕事", iconName: "briefcase.fill", colorHex: "#4A90E2", reminderMinutes: 600, isMealType: false),
        Preset(name: "勉強", iconName: "book.fill", colorHex: "#50C9BA", reminderMinutes: 480, isMealType: false),
        Preset(name: "運動", iconName: "figure.run", colorHex: "#E95E77", reminderMinutes: 120, isMealType: false),
        Preset(name: "移動", iconName: "tram.fill", colorHex: "#7F8C8D", reminderMinutes: 120, isMealType: false),
        Preset(
            name: "休憩",
            iconName: "cup.and.saucer.fill",
            colorHex: "#BFAE82",
            reminderMinutes: nil,
            isMealType: false
        ),
        Preset(
            name: "趣味",
            iconName: "gamecontroller.fill",
            colorHex: "#9B59B6",
            reminderMinutes: nil,
            isMealType: false
        ),
    ]

    /// 名前で一致する既存テンプレに、新デフォルトのアラート分数を再適用する。
    /// `nil` の preset (休憩/趣味) は対象外。
    static let reminderDefaultsByName: [String: Int] = Dictionary(
        uniqueKeysWithValues: presets.compactMap { preset in
            preset.reminderMinutes.map { (preset.name, $0) }
        }
    )
}
