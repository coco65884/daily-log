@testable import DailyLog
import XCTest

final class ActivityNoteTests: XCTestCase {
    func testAppendToEmptyNote() {
        let activity = Activity()
        activity.appendNote("こんにちは")
        XCTAssertEqual(activity.note, "こんにちは")
    }

    func testAppendSeparatesExistingNoteWithNewline() {
        let activity = Activity(note: "一言目")
        activity.appendNote("二言目")
        XCTAssertEqual(activity.note, "一言目\n二言目")
    }

    func testAppendTrimsWhitespace() {
        let activity = Activity(note: "一言目")
        activity.appendNote("   追加  \n")
        XCTAssertEqual(activity.note, "一言目\n追加")
    }

    func testAppendIgnoresEmptyOrWhitespaceOnly() {
        let activity = Activity(note: "保持される")
        activity.appendNote("")
        activity.appendNote("   \n  ")
        XCTAssertEqual(activity.note, "保持される")
    }

    func testAppendMultipleEntries() {
        let activity = Activity()
        activity.appendNote("a")
        activity.appendNote("b")
        activity.appendNote("c")
        XCTAssertEqual(activity.note, "a\nb\nc")
    }
}
