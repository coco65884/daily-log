import SwiftData
import SwiftUI

/// カレンダーから日付をタップしたときに開く 1 日の詳細画面。
/// 円グラフは #16 で本実装する (ここでは一覧表示のみ)。
struct DayDetailView: View {
    let date: Date

    @Query(sort: \Activity.startAt)
    private var allActivities: [Activity]

    private var activities: [Activity] {
        ActivityDateExtractor.activities(on: date, from: allActivities)
    }

    var body: some View {
        List {
            Section("サマリー") {
                LabeledContent("記録数", value: "\(activities.count)")
                LabeledContent("合計時間", value: totalDurationText)
            }

            Section("記録") {
                if activities.isEmpty {
                    Text("この日の記録はありません")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(activities) { activity in
                        DayActivityRow(activity: activity)
                    }
                }
            }

            Section {
                Text("円グラフは今後 Issue #16 で実装予定")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(titleText)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var titleText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private var totalDurationText: String {
        let seconds = activities.reduce(0) { running, activity in
            running + Int(activity.duration ?? 0)
        }
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
