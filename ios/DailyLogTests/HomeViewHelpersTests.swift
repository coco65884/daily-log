@testable import DailyLog
import SwiftUI
import XCTest

final class HomeViewHelpersTests: XCTestCase {
    func testColorHexParsesSixDigit() {
        XCTAssertNotNil(Color(hex: "#4A90E2"))
        XCTAssertNotNil(Color(hex: "4A90E2"))
    }

    func testColorHexRejectsInvalid() {
        XCTAssertNil(Color(hex: "123"))
        XCTAssertNil(Color(hex: "#ZZZZZZ"))
        XCTAssertNil(Color(hex: ""))
    }

    func testDurationFormatterMMSS() {
        XCTAssertEqual(DurationFormatter.elapsed(seconds: 0), "00:00")
        XCTAssertEqual(DurationFormatter.elapsed(seconds: 59), "00:59")
        XCTAssertEqual(DurationFormatter.elapsed(seconds: 3540), "59:00")
    }

    func testDurationFormatterHHMMSS() {
        XCTAssertEqual(DurationFormatter.elapsed(seconds: 3600), "01:00:00")
        XCTAssertEqual(DurationFormatter.elapsed(seconds: 3661), "01:01:01")
    }

    func testDurationFormatterClampsNegative() {
        let now = Date()
        let past = now.addingTimeInterval(10)
        XCTAssertEqual(DurationFormatter.elapsed(from: past, to: now), "00:00")
    }
}
