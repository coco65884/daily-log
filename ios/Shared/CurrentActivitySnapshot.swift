import Foundation

/// 本体アプリが書き込み、ウィジェットが読み取る「進行中の行動」スナップショット。
///
/// フル SwiftData ストアをウィジェットに共有する代わりに、表示に必要な最小値だけを
/// App Group の UserDefaults に JSON でキャッシュする。
struct CurrentActivitySnapshot: Codable, Equatable {
    let templateName: String
    let iconName: String
    let colorHex: String
    let startAt: Date
    let isMealType: Bool

    private static let key = "current-activity-snapshot"

    static func load(from defaults: UserDefaults = AppGroupConfig.sharedDefaults) -> CurrentActivitySnapshot? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(CurrentActivitySnapshot.self, from: data)
    }

    static func store(
        _ snapshot: CurrentActivitySnapshot?,
        in defaults: UserDefaults = AppGroupConfig.sharedDefaults
    ) {
        if let snapshot, let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}
