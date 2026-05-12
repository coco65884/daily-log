import Foundation

/// アプリ起動時点で必要になる軽量な設定値。
///
/// `AppSettings` (SwiftData) は ModelContainer が用意されて初めて読めるため、
/// CloudKit 切替のようにコンテナ初期化時に必要な値は UserDefaults で保持する。
enum AppPreferences {
    enum Keys {
        static let iCloudSyncEnabled = "pref.iCloudSyncEnabled"
        static let notificationsEnabled = "pref.notificationsEnabled"
        static let alertDefaultsV2Applied = "pref.alertDefaultsV2Applied"
    }

    private static var store: UserDefaults {
        .standard
    }

    static var iCloudSyncEnabled: Bool {
        get { store.bool(forKey: Keys.iCloudSyncEnabled) }
        set { store.set(newValue, forKey: Keys.iCloudSyncEnabled) }
    }

    static var notificationsEnabled: Bool {
        get {
            if let value = store.object(forKey: Keys.notificationsEnabled) as? Bool {
                return value
            }
            return true
        }
        set { store.set(newValue, forKey: Keys.notificationsEnabled) }
    }

    static var alertDefaultsV2Applied: Bool {
        get { store.bool(forKey: Keys.alertDefaultsV2Applied) }
        set { store.set(newValue, forKey: Keys.alertDefaultsV2Applied) }
    }
}
