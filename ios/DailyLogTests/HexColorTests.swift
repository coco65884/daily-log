@testable import DailyLog
import XCTest

final class HexColorTests: XCTestCase {
    func testParseSixDigitHex() throws {
        let rgb = try XCTUnwrap(HexColor.parse(hex: "#FF8040"))
        XCTAssertEqual(rgb.red, 1.0, accuracy: 0.001)
        XCTAssertEqual(rgb.green, 128.0 / 255.0, accuracy: 0.001)
        XCTAssertEqual(rgb.blue, 64.0 / 255.0, accuracy: 0.001)
    }

    func testParseRejectsInvalid() {
        XCTAssertNil(HexColor.parse(hex: "123"))
        XCTAssertNil(HexColor.parse(hex: "#ZZZZZZ"))
        XCTAssertNil(HexColor.parse(hex: ""))
    }

    func testMixedPositiveLightens() {
        let result = HexColor.mixed(hex: "#000000", amount: 0.5)
        XCTAssertEqual(result, "#808080", "0.5 toward white from black ≈ mid grey")
    }

    func testMixedNegativeDarkens() {
        let result = HexColor.mixed(hex: "#FFFFFF", amount: -0.5)
        XCTAssertEqual(result, "#808080", "0.5 toward black from white ≈ mid grey")
    }

    func testMixedClampsOutOfRange() {
        XCTAssertEqual(HexColor.mixed(hex: "#000000", amount: 5.0), "#FFFFFF")
        XCTAssertEqual(HexColor.mixed(hex: "#FFFFFF", amount: -5.0), "#000000")
    }

    func testMixedReturnsInputOnParseFailure() {
        XCTAssertEqual(HexColor.mixed(hex: "garbage", amount: 0.3), "garbage")
    }

    func testShadedAlternatesLightAndDark() {
        let base = "#808080" // 中間グレー
        let shade0 = HexColor.shaded(parentHex: base, childIndex: 0)
        let shade1 = HexColor.shaded(parentHex: base, childIndex: 1)
        // index 0 は明寄り、 index 1 は暗寄り
        XCTAssertGreaterThan(brightness(of: shade0), brightness(of: base))
        XCTAssertLessThan(brightness(of: shade1), brightness(of: base))
    }

    private func brightness(of hex: String) -> Double {
        guard let rgb = HexColor.parse(hex: hex) else { return 0 }
        return (rgb.red + rgb.green + rgb.blue) / 3.0
    }
}
