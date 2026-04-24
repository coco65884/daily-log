import Foundation

extension Activity {
    /// 既存メモの末尾に新しい内容を追加する。空文字列は無視。
    /// 既存メモが空でなければ改行で区切る。
    func appendNote(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if note.isEmpty {
            note = trimmed
        } else {
            note += "\n" + trimmed
        }
    }
}
