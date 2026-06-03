import SwiftData
import SwiftUI

/// その日の記録のミスを手動修正する画面。
/// - 時系列ドーナツ (プレビュー / タップで選択)
/// - 各記録の開始/終了時刻を ±5 分・±15 分ボタンで調整
/// - 期間が他と被ったら `ActivityOverlapResolver` で上書き (トリム + 完全被覆は削除) 解消
/// - 削除が発生する場合は保存前に確認
struct DayEditView: View {
    let date: Date

    @Query(sort: \Activity.startAt)
    private var allActivities: [Activity]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var segments: [EditableSegment] = []
    @State private var selectedID: UUID?
    @State private var pendingDeleted: [EditableSegment] = []
    @State private var excludedCount = 0
    @State private var showDeleteConfirm = false
    @State private var didPopulate = false

    private let calendar: Calendar = .currentGregorian
    private let now: Date = .init()

    private var dayStart: Date {
        calendar.startOfDay(for: date)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    TimelineEditorDonut(segments: segments, dayStart: dayStart, selectedID: $selectedID)
                        .frame(height: 220)

                    if excludedCount > 0 {
                        Text("日をまたぐ / 進行中の記録は修正対象外です")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    content
                }
                .padding()
            }
            .navigationTitle("記録を修正")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .confirmationDialog("削除される記録があります", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("削除して保存", role: .destructive) { commit() }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text(deleteMessage)
            }
            .onAppear(perform: populateIfNeeded)
        }
    }

    @ViewBuilder
    private var content: some View {
        if segments.isEmpty {
            Text("修正できる記録がありません")
                .foregroundStyle(.secondary)
                .padding(.top, 40)
        } else {
            ForEach(segments) { segment in
                DayEditRow(
                    segment: segment,
                    isSelected: selectedID == segment.id,
                    onSelect: { selectedID = segment.id },
                    onAdjustStart: { adjust(segment.id, startDelta: $0, endDelta: 0) },
                    onAdjustEnd: { adjust(segment.id, startDelta: 0, endDelta: $0) }
                )
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("キャンセル") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("保存") { save() }
                .disabled(segments.isEmpty && pendingDeleted.isEmpty)
        }
    }

    // MARK: - Editing

    private func adjust(_ id: UUID, startDelta: TimeInterval, endDelta: TimeInterval) {
        guard let current = segments.first(where: { $0.id == id }) else { return }
        let dayEnd = dayStart.addingTimeInterval(86400)
        let newStart = clamp(current.start.addingTimeInterval(startDelta), lower: dayStart, upper: dayEnd)
        let newEnd = clamp(current.end.addingTimeInterval(endDelta), lower: dayStart, upper: dayEnd)
        guard newEnd.timeIntervalSince(newStart) >= 60 else { return }

        let before = segments
        let result = ActivityOverlapResolver.apply(editedID: id, newStart: newStart, newEnd: newEnd, to: segments)
        for deletedID in result.deletedIDs {
            if let deleted = before.first(where: { $0.id == deletedID }) {
                pendingDeleted.append(deleted)
            }
        }
        selectedID = id
        withAnimation { segments = result.updated }
    }

    private func clamp(_ date: Date, lower: Date, upper: Date) -> Date {
        min(max(date, lower), upper)
    }

    // MARK: - Persistence

    private func save() {
        if pendingDeleted.isEmpty {
            commit()
        } else {
            showDeleteConfirm = true
        }
    }

    private func commit() {
        let byID = Dictionary(allActivities.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for segment in segments {
            guard let activity = byID[segment.id] else { continue }
            activity.startAt = segment.start
            activity.endAt = segment.end
        }
        for id in Set(pendingDeleted.map(\.id)) {
            if let activity = byID[id] {
                modelContext.delete(activity)
            }
        }
        try? modelContext.save()
        dismiss()
    }

    private var deleteMessage: String {
        let names = Set(pendingDeleted.map(\.templateName)).sorted()
        return "次の記録が削除されます: \(names.joined(separator: "、"))"
    }

    // MARK: - Population

    private func populateIfNeeded() {
        guard !didPopulate else { return }
        didPopulate = true

        let dayEnd = dayStart.addingTimeInterval(86400)
        let dayActivities = ActivityDateExtractor.activities(on: date, from: allActivities, calendar: calendar)
            .sorted { $0.startAt < $1.startAt }

        var built: [EditableSegment] = []
        var excluded = 0
        for activity in dayActivities {
            // 安全のため当日内で完結する完了済み記録のみ編集対象とする。
            guard let end = activity.endAt, activity.startAt >= dayStart, end <= dayEnd, end > activity.startAt else {
                excluded += 1
                continue
            }
            built.append(EditableSegment(
                id: activity.id,
                start: activity.startAt,
                end: end,
                templateName: activity.template?.name ?? "（未分類）",
                colorHex: displayHex(for: activity.template)
            ))
        }
        segments = built
        excludedCount = excluded
        selectedID = built.first?.id
    }

    private func displayHex(for template: ActivityTemplate?) -> String {
        guard let template else { return "#7F8C8D" }
        guard let parent = template.parent else { return template.colorHex }
        let siblings = parent.children.sorted { $0.sortOrder < $1.sortOrder }
        let index = siblings.firstIndex { $0.id == template.id } ?? 0
        return HexColor.shaded(parentHex: parent.colorHex, childIndex: index)
    }
}

private struct DayEditRow: View {
    let segment: EditableSegment
    let isSelected: Bool
    let onSelect: () -> Void
    let onAdjustStart: (TimeInterval) -> Void
    let onAdjustEnd: (TimeInterval) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            timeControl(label: "開始", time: segment.start, onAdjust: onAdjustStart)
            timeControl(label: "終了", time: segment.end, onAdjust: onAdjustEnd)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color(.secondarySystemBackground))
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }

    private var header: some View {
        HStack {
            Circle()
                .fill(Color(hex: segment.colorHex) ?? .accentColor)
                .frame(width: 12, height: 12)
            Text(segment.templateName)
                .font(.body)
            Spacer()
            Text(DurationFormatter.elapsed(seconds: Int(segment.duration)))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private func timeControl(
        label: String,
        time: Date,
        onAdjust: @escaping (TimeInterval) -> Void
    ) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .leading)
            Text(timeText(time))
                .font(.subheadline.monospacedDigit())
                .frame(width: 52, alignment: .leading)
            Spacer()
            stepButton("−15", -15 * 60, onAdjust)
            stepButton("−5", -5 * 60, onAdjust)
            stepButton("+5", 5 * 60, onAdjust)
            stepButton("+15", 15 * 60, onAdjust)
        }
    }

    private func stepButton(
        _ title: String,
        _ delta: TimeInterval,
        _ onAdjust: @escaping (TimeInterval) -> Void
    ) -> some View {
        Button(title) { onAdjust(delta) }
            .font(.caption.monospacedDigit())
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .controlSize(.small)
    }

    private func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
