import SwiftData
import SwiftUI

/// 記録 1 件の開始/終了時刻を変更・削除するシート。
/// 時刻は当日内かつ前後の記録と重ならない範囲に制限する
/// (大きな移動や重ね合わせは「修正」エディタを使う)。
struct ActivityEditSheet: View {
    let activity: Activity
    /// 同じ日の記録 (前後の境界算出用)。
    let dayActivities: [Activity]
    var calendar: Calendar = .currentGregorian

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var start: Date
    @State private var end: Date
    @State private var showDeleteConfirm = false

    init(activity: Activity, dayActivities: [Activity], calendar: Calendar = .currentGregorian) {
        self.activity = activity
        self.dayActivities = dayActivities
        self.calendar = calendar
        _start = State(initialValue: activity.startAt)
        _end = State(initialValue: activity.endAt ?? Date())
    }

    private var dayStart: Date {
        calendar.startOfDay(for: activity.startAt)
    }

    private var dayEnd: Date {
        dayStart.addingTimeInterval(86400)
    }

    /// 前の記録の終了 (これより前には開始できない)。
    private var lowerBound: Date {
        let others = dayActivities.filter { $0.id != activity.id && $0.startAt < activity.startAt }
        return others.compactMap(\.endAt).max() ?? dayStart
    }

    /// 次の記録の開始 (これより後には終了できない)。
    private var upperBound: Date {
        let others = dayActivities.filter { $0.id != activity.id && $0.startAt > activity.startAt }
        return others.map(\.startAt).min() ?? dayEnd
    }

    /// DatePicker 用の選択可能範囲。境界が逆転/退化している場合は当日全体にフォールバック。
    private var selectableRange: ClosedRange<Date> {
        upperBound > lowerBound ? lowerBound ... upperBound : dayStart ... dayEnd
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("アクション", value: activity.template?.name ?? "（未分類）")
                }

                Section("時刻") {
                    DatePicker("開始", selection: $start, in: selectableRange, displayedComponents: .hourAndMinute)
                    DatePicker("終了", selection: $end, in: selectableRange, displayedComponents: .hourAndMinute)
                    if end <= start {
                        Text("終了は開始より後にしてください")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button("この記録を削除", role: .destructive) {
                        showDeleteConfirm = true
                    }
                }
            }
            .navigationTitle("記録を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(end <= start)
                }
            }
            .confirmationDialog("この記録を削除しますか？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("削除", role: .destructive) { deleteActivity() }
                Button("キャンセル", role: .cancel) {}
            }
        }
    }

    private func save() {
        guard end > start else { return }
        activity.startAt = start
        activity.endAt = end
        try? modelContext.save()
        dismiss()
    }

    private func deleteActivity() {
        modelContext.delete(activity)
        try? modelContext.save()
        dismiss()
    }
}
