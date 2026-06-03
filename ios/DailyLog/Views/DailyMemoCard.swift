import SwiftData
import SwiftUI

/// ホーム下部に表示する「今日のメモ」入力カード。
/// `dayKey` 一意で `DailyMemo` を 1 日 1 件保持し、テキスト変更時に自動保存する。
struct DailyMemoCard: View {
    @Environment(\.modelContext) private var modelContext

    @Query private var memos: [DailyMemo]

    @State private var draft: String = ""
    @State private var loadedDayKey: String?
    @State private var isPresentingVoiceMemo = false
    @FocusState private var isFocused: Bool

    private let calendar: Calendar = .currentGregorian

    private var todayKey: String {
        DailyMemo.dayKey(for: Date(), calendar: calendar)
    }

    private var todayMemo: DailyMemo? {
        memos.first { $0.dayKey == todayKey }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Label("今日のメモ", systemImage: "note.text")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                if isFocused {
                    Button("完了") {
                        isFocused = false
                    }
                    .font(.caption)
                }
                Button {
                    isPresentingVoiceMemo = true
                } label: {
                    Image(systemName: "mic")
                        .font(.subheadline)
                }
                .accessibilityLabel("音声メモ")
            }

            ZStack(alignment: .topLeading) {
                if draft.isEmpty {
                    Text("今日やったことを書き残す…")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                        .padding(.leading, 4)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $draft)
                    .focused($isFocused)
                    .frame(minHeight: 80)
                    .scrollContentBackground(.hidden)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .onAppear(perform: loadIfNeeded)
        .onChange(of: draft) { _, newValue in
            save(text: newValue)
        }
        .sheet(isPresented: $isPresentingVoiceMemo) {
            VoiceMemoSheet(onAppend: appendTranscription)
        }
    }

    /// 音声認識テキストを今日のメモ末尾へ追記する。空文字列は無視。
    private func appendTranscription(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        draft = draft.isEmpty ? trimmed : draft + "\n" + trimmed
    }

    private func loadIfNeeded() {
        if loadedDayKey == todayKey { return }
        draft = todayMemo?.text ?? ""
        loadedDayKey = todayKey
    }

    private func save(text: String) {
        guard loadedDayKey == todayKey else { return }
        if let existing = todayMemo {
            guard existing.text != text else { return }
            existing.text = text
            existing.updatedAt = Date()
        } else {
            let memo = DailyMemo(dayKey: todayKey, text: text)
            modelContext.insert(memo)
        }
        try? modelContext.save()
    }
}
