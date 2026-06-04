import SwiftData
import SwiftUI

/// カレンダーから日付をタップしたときに開く 1 日の詳細画面。
/// 円グラフ + 記録リストで構成。
struct DayDetailView: View {
    let date: Date

    @Query(sort: \Activity.startAt)
    private var allActivities: [Activity]

    @State private var chartMode: ChartMode = .timeline
    @State private var isEditing = false
    @State private var editingActivity: Activity?

    private let calendar: Calendar = .currentGregorian

    enum ChartMode: String, CaseIterable, Identifiable {
        case timeline
        case proportion

        var id: String {
            rawValue
        }

        var displayName: String {
            switch self {
            case .timeline: "時系列"
            case .proportion: "割合"
            }
        }
    }

    private var activities: [Activity] {
        ActivityDateExtractor.activities(on: date, from: allActivities)
    }

    private var slices: [DayActivitySummary.Slice] {
        DayActivitySummary.slices(for: allActivities, on: date)
    }

    private var dayStart: Date {
        calendar.startOfDay(for: date)
    }

    /// 時系列ドーナツ用に、その日の各 Activity を当日内にクリップしたセグメント列。
    private var daySegments: [EditableSegment] {
        let dayEnd = dayStart.addingTimeInterval(86400)
        let now = Date()
        return activities.compactMap { activity in
            let start = max(activity.startAt, dayStart)
            let end = min(activity.endAt ?? now, dayEnd)
            guard end > start else { return nil }
            return EditableSegment(
                id: activity.id,
                start: start,
                end: end,
                templateName: activity.template?.name ?? "（未分類）",
                colorHex: displayHex(for: activity.template)
            )
        }
    }

    private func displayHex(for template: ActivityTemplate?) -> String {
        guard let template else { return "#7F8C8D" }
        guard let parent = template.parent else { return template.colorHex }
        let siblings = parent.children.sorted { $0.sortOrder < $1.sortOrder }
        let index = siblings.firstIndex { $0.id == template.id } ?? 0
        return HexColor.shaded(parentHex: parent.colorHex, childIndex: index)
    }

    var body: some View {
        List {
            Section("サマリー") {
                LabeledContent("記録数", value: "\(activities.count)")
                LabeledContent("合計時間", value: totalDurationText)
            }

            Section("内訳") {
                Picker("表示", selection: $chartMode) {
                    ForEach(ChartMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Group {
                    switch chartMode {
                    case .proportion:
                        DayPieChart(slices: slices)
                    case .timeline:
                        DayTimelineDonut(segments: daySegments, dayStart: dayStart)
                            .frame(height: 260)
                    }
                }
                .padding(.vertical, 8)
            }

            Section("記録") {
                if activities.isEmpty {
                    Text("この日の記録はありません")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(activities) { activity in
                        Button {
                            editingActivity = activity
                        } label: {
                            DayActivityRow(activity: activity)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle(titleText)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("修正") { isEditing = true }
                    .disabled(activities.isEmpty)
            }
        }
        .sheet(isPresented: $isEditing) {
            DayEditView(date: date)
        }
        .sheet(item: $editingActivity) { activity in
            ActivityEditSheet(activity: activity, dayActivities: activities, calendar: calendar)
        }
    }

    private var titleText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    /// 合計は日内にクリップ済みの slices から算出する。
    /// 日付を跨ぐアクションは当日分のみ計上されるため 24 時間を超えない。
    private var totalDurationText: String {
        let seconds = slices.reduce(0) { $0 + Int($1.totalSeconds) }
        return DurationFormatter.elapsed(seconds: seconds)
    }
}

private struct DayActivityRow: View {
    let activity: Activity

    var body: some View {
        HStack(spacing: 12) {
            iconView

            VStack(alignment: .leading, spacing: 2) {
                Text(activity.template?.name ?? "（テンプレートなし）")
                    .font(.body)
                Text(timeRangeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let duration = activity.duration {
                Text(DurationFormatter.elapsed(seconds: Int(duration)))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            } else {
                Text("進行中")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder
    private var iconView: some View {
        if let template = activity.template {
            Image(systemName: template.iconName)
                .font(.callout)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(Color(hex: template.colorHex) ?? .accentColor)
                )
        } else {
            Circle()
                .fill(Color.secondary)
                .frame(width: 28, height: 28)
        }
    }

    private var timeRangeText: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let start = formatter.string(from: activity.startAt)
        if let end = activity.endAt {
            return "\(start) - \(formatter.string(from: end))"
        } else {
            return "\(start) -"
        }
    }
}
