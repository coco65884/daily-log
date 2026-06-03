import Foundation

/// 1 日分の編集対象セグメント。`Activity` から切り出した値型 (テスト可能)。
struct EditableSegment: Identifiable, Equatable {
    let id: UUID // 元 Activity.id
    var start: Date
    var end: Date
    let templateName: String
    let colorHex: String

    var duration: TimeInterval {
        end.timeIntervalSince(start)
    }
}

/// アクションの時刻を変更したときの重複を「上書き (トリム + 完全被覆は削除)」で解消する純ロジック。
///
/// 編集対象 X を新区間 `[start, end]` にしたとき、同日の他セグメント Y それぞれを:
/// - 完全被覆 (Y が X 内に収まる) → 削除
/// - 左重なり (Y が X より前から始まる) → `Y.end = X.start` にトリム
/// - 右重なり (Y が X より後ろまで続く) → `Y.start = X.end` にトリム
/// - Y が X を内包 → 早い側を残し `Y.end = X.start` にトリム (後半は破棄)
/// - トリム結果が長さ 0 以下 → 削除
/// これにより終了時刻を大きく後ろにずらして後続複数に被っても、被覆分は削除・部分重なりは
/// トリムで解消され、後続が黙って潰れることがない。
enum ActivityOverlapResolver {
    struct Resolution: Equatable {
        /// 時刻調整後のセグメント (編集対象を含む)。元の並び順を保持。
        var updated: [EditableSegment]
        /// 完全被覆/0 長で削除されたセグメントの ID。
        var deletedIDs: [UUID]
    }

    /// `editedID` を `newStart`/`newEnd` に変更し、重複を解消した結果を返す。
    /// `newStart < newEnd` を前提とする (呼び出し側でクランプ)。
    static func apply(
        editedID: UUID,
        newStart: Date,
        newEnd: Date,
        to segments: [EditableSegment]
    ) -> Resolution {
        var updated: [EditableSegment] = []
        var deletedIDs: [UUID] = []

        for segment in segments {
            if segment.id == editedID {
                var edited = segment
                edited.start = newStart
                edited.end = newEnd
                updated.append(edited)
                continue
            }

            guard overlaps(segment, newStart: newStart, newEnd: newEnd) else {
                updated.append(segment)
                continue
            }

            let startsBefore = segment.start < newStart
            let endsAfter = segment.end > newEnd
            var trimmed = segment

            switch (startsBefore, endsAfter) {
            case (true, true), (true, false):
                // Y が X を内包 or 左重なり → 左側を残す
                trimmed.end = newStart
            case (false, true):
                // 右重なり → 右側を残す
                trimmed.start = newEnd
            case (false, false):
                // 完全被覆 → 削除
                deletedIDs.append(segment.id)
                continue
            }

            if trimmed.end > trimmed.start {
                updated.append(trimmed)
            } else {
                deletedIDs.append(segment.id)
            }
        }

        return Resolution(updated: updated, deletedIDs: deletedIDs)
    }

    private static func overlaps(_ segment: EditableSegment, newStart: Date, newEnd: Date) -> Bool {
        segment.start < newEnd && segment.end > newStart
    }
}
