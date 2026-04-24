import Foundation

enum DurationFormatter {
    /// 経過秒数を `HH:MM:SS` または `MM:SS` 形式にフォーマットする。
    static func elapsed(seconds total: Int) -> String {
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    static func elapsed(from start: Date, to end: Date) -> String {
        let seconds = max(0, Int(end.timeIntervalSince(start)))
        return elapsed(seconds: seconds)
    }
}
