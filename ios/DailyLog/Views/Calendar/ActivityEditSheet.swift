import SwiftData
import SwiftUI

/// 記録 1 件のアクション・開始/終了時刻を変更・削除するシート。
/// 時刻は当日内かつ前後の記録と重ならない範囲に制限する
/// (大きな移動や重ね合わせは「修正」エディタを使う)。
struct ActivityEditSheet: View {
    let activity: Activity
    /// 同じ日の記録 (前後の境界算出用)。
    let dayActivities: [Activity]
    var calendar: Calendar = .currentGregorian

    @Query(
        filter: #Predicate<ActivityTemplate> { !$0.isHidden },
        sort: \ActivityTemplate.sortOrder
    )
    private var templates: [ActivityTemplate]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var selectedTemplateID: UUID?
    @State private var start: Date
    @State private var end: Date
    @State private var showDeleteConfirm = false

    init(activity: Activity, dayActivities: [Activity], calendar: Calendar = .currentGregorian) {
        self.activity = activity
        self.dayActivities = dayActivities
        self.calendar = calendar
        _selectedTemplateID = State(initialValue: activity.template?.id)
        _start = State(initialValue: activity.startAt)
        _end = State(initialValue: activity.endAt ?? Date())
    }

    private var selectedTemplate: ActivityTemplate? {
        templates.first { $0.id == selectedTemplateID } ?? activity.template
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
                headerSection
                actionSection
                timeSection
                deleteSection
            }
            .navigationTitle("記録を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .confirmationDialog("この記録を削除しますか？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("削除", role: .destructive) { deleteActivity() }
                Button("キャンセル", role: .cancel) {}
            }
        }
    }

    private var headerSection: some View {
        Section {
            HStack(spacing: 12) {
                actionIcon(for: selectedTemplate, size: 40)
                Text(selectedTemplate?.name ?? "（未分類）")
                    .font(.headline)
                Spacer()
            }
            .padding(.vertical, 4)
        }
    }

    private var actionSection: some View {
        Section("アクション") {
            Picker("アクション", selection: $selectedTemplateID) {
                ForEach(templates) { template in
                    actionRow(for: template).tag(Optional(template.id))
                }
            }
            .pickerStyle(.navigationLink)
        }
    }

    private var timeSection: some View {
        Section("時刻") {
            DatePicker("開始", selection: $start, in: selectableRange, displayedComponents: .hourAndMinute)
            DatePicker("終了", selection: $end, in: selectableRange, displayedComponents: .hourAndMinute)
            if end <= start {
                Text("終了は開始より後にしてください")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var deleteSection: some View {
        Section {
            Button("この記録を削除", role: .destructive) {
                showDeleteConfirm = true
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
                .disabled(end <= start)
        }
    }

    private func actionRow(for template: ActivityTemplate) -> some View {
        HStack(spacing: 10) {
            actionIcon(for: template, size: 28)
            Text(template.name)
        }
    }

    private func actionIcon(for template: ActivityTemplate?, size: CGFloat) -> some View {
        Image(systemName: template?.iconName ?? "circle")
            .font(size >= 36 ? .title3 : .callout)
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(template.flatMap { Color(hex: $0.colorHex) } ?? Color.secondary)
            )
    }

    private func save() {
        guard end > start else { return }
        if let template = templates.first(where: { $0.id == selectedTemplateID }) {
            activity.template = template
        }
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
