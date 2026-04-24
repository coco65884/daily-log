@testable import DailyLog
import XCTest

final class AppPreferencesTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: AppPreferences.Keys.iCloudSyncEnabled)
        UserDefaults.standard.removeObject(forKey: AppPreferences.Keys.notificationsEnabled)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: AppPreferences.Keys.iCloudSyncEnabled)
        UserDefaults.standard.removeObject(forKey: AppPreferences.Keys.notificationsEnabled)
        super.tearDown()
    }

    func testiCloudSyncDefaultsToFalse() {
        XCTAssertFalse(AppPreferences.iCloudSyncEnabled)
    }

    func testNotificationsDefaultsToTrue() {
        XCTAssertTrue(AppPreferences.notificationsEnabled)
    }

    func testTogglesPersistAcrossAccesses() {
        AppPreferences.iCloudSyncEnabled = true
        AppPreferences.notificationsEnabled = false

        XCTAssertTrue(AppPreferences.iCloudSyncEnabled)
        XCTAssertFalse(AppPreferences.notificationsEnabled)
    }
}
