import Foundation

/// 本体アプリとウィジェット拡張で共有する App Group 設定。
enum AppGroupConfig {
    static let identifier = "group.com.coco.daily-log"
    static let iCloudContainerIdentifier = "iCloud.com.coco.daily-log"

    static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }
}
