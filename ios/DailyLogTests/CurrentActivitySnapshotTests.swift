@testable import DailyLog
import XCTest

final class CurrentActivitySnapshotTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        try super.setUpWithError()
        suiteName = "CurrentActivitySnapshotTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        try super.tearDownWithError()
    }

    func testLoadReturnsNilWhenNothingStored() {
        XCTAssertNil(CurrentActivitySnapshot.load(from: defaults))
    }

    func testStoreAndLoadRoundTrip() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let snapshot = CurrentActivitySnapshot(
            templateName: "仕事",
            iconName: "briefcase.fill",
            colorHex: "#4A90E2",
            startAt: start,
            isMealType: false
        )

        CurrentActivitySnapshot.store(snapshot, in: defaults)

        let loaded = try XCTUnwrap(CurrentActivitySnapshot.load(from: defaults))
        XCTAssertEqual(loaded, snapshot)
    }

    func testStoreNilClearsExistingEntry() {
        let snapshot = CurrentActivitySnapshot(
            templateName: "勉強",
            iconName: "book",
            colorHex: "#50C9BA",
            startAt: Date(),
            isMealType: false
        )
        CurrentActivitySnapshot.store(snapshot, in: defaults)
        XCTAssertNotNil(CurrentActivitySnapshot.load(from: defaults))

        CurrentActivitySnapshot.store(nil, in: defaults)
        XCTAssertNil(CurrentActivitySnapshot.load(from: defaults))
    }
}
