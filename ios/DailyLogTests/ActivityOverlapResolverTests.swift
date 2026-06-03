@testable import DailyLog
import XCTest

final class ActivityOverlapResolverTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        return calendar
    }()

    func testExtendingEndIntoNextPartiallyTrimsNextStart() {
        let segA = segment("A", 9, 0, 10, 0)
        let segB = segment("B", 10, 0, 12, 0)

        // A の終了を 11:00 へ延長 → B は右重なりなので開始が 11:00 にトリムされる
        let result = ActivityOverlapResolver.apply(
            editedID: segA.id,
            newStart: segA.start,
            newEnd: time(11, 0),
            to: [segA, segB]
        )

        XCTAssertTrue(result.deletedIDs.isEmpty)
        XCTAssertEqual(result.updated.first { $0.id == segA.id }?.end, time(11, 0))
        XCTAssertEqual(result.updated.first { $0.id == segB.id }?.start, time(11, 0))
        XCTAssertEqual(result.updated.first { $0.id == segB.id }?.end, time(12, 0))
    }

    func testFullyCoveredSegmentIsDeleted() {
        let segA = segment("A", 9, 0, 10, 0)
        let segB = segment("B", 10, 30, 11, 0)

        // A の終了を 12:00 へ延長 → B (10:30-11:00) は完全被覆 → 削除
        let result = ActivityOverlapResolver.apply(
            editedID: segA.id,
            newStart: segA.start,
            newEnd: time(12, 0),
            to: [segA, segB]
        )

        XCTAssertEqual(result.deletedIDs, [segB.id])
        XCTAssertNil(result.updated.first { $0.id == segB.id })
    }

    func testCascadeDeletesCoveredAndTrimsPartial() {
        let segA = segment("A", 9, 0, 10, 0)
        let segB = segment("B", 10, 0, 11, 0) // 完全被覆される
        let segC = segment("C", 11, 0, 13, 0) // 部分的に被る

        // A の終了を 12:00 まで大きく延長 → B 削除, C 開始 12:00 にトリム
        let result = ActivityOverlapResolver.apply(
            editedID: segA.id,
            newStart: segA.start,
            newEnd: time(12, 0),
            to: [segA, segB, segC]
        )

        XCTAssertEqual(result.deletedIDs, [segB.id])
        XCTAssertEqual(result.updated.first { $0.id == segC.id }?.start, time(12, 0))
        XCTAssertEqual(result.updated.first { $0.id == segC.id }?.end, time(13, 0))
    }

    func testSegmentContainingEditedIsTrimmedToLeftPart() {
        let big = segment("BIG", 8, 0, 14, 0)
        let segX = segment("X", 10, 0, 11, 0)

        // X を 9:00-12:00 に拡張 → BIG は X を内包 → 左側 (8:00-9:00) を残す
        let result = ActivityOverlapResolver.apply(
            editedID: segX.id,
            newStart: time(9, 0),
            newEnd: time(12, 0),
            to: [big, segX]
        )

        XCTAssertTrue(result.deletedIDs.isEmpty)
        XCTAssertEqual(result.updated.first { $0.id == big.id }?.start, time(8, 0))
        XCTAssertEqual(result.updated.first { $0.id == big.id }?.end, time(9, 0))
    }

    func testLeftOverlapTrimsPreviousEnd() {
        let segA = segment("A", 9, 0, 11, 0)
        let segB = segment("B", 11, 0, 12, 0)

        // B の開始を 10:00 へ前倒し → A は左重なり → A.end が 10:00 にトリム
        let result = ActivityOverlapResolver.apply(
            editedID: segB.id,
            newStart: time(10, 0),
            newEnd: segB.end,
            to: [segA, segB]
        )

        XCTAssertTrue(result.deletedIDs.isEmpty)
        XCTAssertEqual(result.updated.first { $0.id == segA.id }?.end, time(10, 0))
        XCTAssertEqual(result.updated.first { $0.id == segB.id }?.start, time(10, 0))
    }

    func testNonOverlappingSegmentsUnchanged() {
        let segA = segment("A", 9, 0, 10, 0)
        let segB = segment("B", 12, 0, 13, 0)

        // A を 9:30 までに短縮 → B とは無関係
        let result = ActivityOverlapResolver.apply(
            editedID: segA.id,
            newStart: segA.start,
            newEnd: time(9, 30),
            to: [segA, segB]
        )

        XCTAssertTrue(result.deletedIDs.isEmpty)
        XCTAssertEqual(result.updated.first { $0.id == segB.id }, segB)
    }

    func testOrderIsPreserved() {
        let segA = segment("A", 9, 0, 10, 0)
        let segB = segment("B", 10, 0, 11, 0)
        let segC = segment("C", 11, 0, 12, 0)

        let result = ActivityOverlapResolver.apply(
            editedID: segB.id,
            newStart: segB.start,
            newEnd: segB.end,
            to: [segA, segB, segC]
        )

        XCTAssertEqual(result.updated.map(\.id), [segA.id, segB.id, segC.id])
    }

    // MARK: - Helpers

    private func time(_ hour: Int, _ minute: Int) -> Date {
        let components = DateComponents(year: 2026, month: 4, day: 25, hour: hour, minute: minute)
        return calendar.date(from: components) ?? Date()
    }

    private func segment(
        _ name: String,
        _ startHour: Int,
        _ startMinute: Int,
        _ endHour: Int,
        _ endMinute: Int
    ) -> EditableSegment {
        EditableSegment(
            id: UUID(),
            start: time(startHour, startMinute),
            end: time(endHour, endMinute),
            templateName: name,
            colorHex: "#333333"
        )
    }
}
