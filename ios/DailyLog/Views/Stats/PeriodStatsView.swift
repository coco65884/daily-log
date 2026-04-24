import SwiftData
import SwiftUI

struct PeriodStatsView: View {
    @Query(sort: \Activity.startAt)
    private var allActivities: [Activity]

    @State private var period: PeriodActivitySummary.Period = .week
    @State private var referenceDate: Date = .init()
    @State private var expandedIDs: Set<UUID> = []

    private let calendar: Calendar = .currentGregorian

    private var summary: PeriodActivitySummary.Summary {
        PeriodActivitySummary.summarize(
            activities: allActivities,
            period: period,
            referenceDate: referenceDate,
            calendar: calendar
        )
    }

    var body: some View {
        List {
            periodSection
            categoriesSection
            mealSection
        }
        .navigationTitle("統計サマリー")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var periodSection: some View {
        Section {
            Picker("期間", selection: $period) {
                ForEach(PeriodActivitySummary.Period.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .pickerStyle(.segmented)

            periodNavigation
        }
    }

    private var periodNavigation: some View {
        HStack {
            Button {
                shiftPeriod(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel("前の期間")

            Spacer()

            Text(rangeLabel)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                shiftPeriod(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .accessibilityLabel("次の期間")
            .disabled(summary.end > calendar.startOfDay(for: Date().addingTimeInterval(86400)))
        }
    }

    private var categoriesSection: some View {
        Section("カテゴリ別") {
            if summary.categories.isEmpty {
                Text("この期間の記録はありません")
                    .foregroundStyle(.secondary)
            } else {
                CategoryBarChart(categories: summary.categories)
                    .frame(minHeight: CGFloat(summary.categories.count * 36 + 40))

                ForEach(summary.categories) { category in
                    CategoryRow(
                        category: category,
                        isExpanded: expandedIDs.contains(category.id),
                        onToggle: { toggle(category.id) }
                    )
                }
            }
        }
    }

    private var mealSection: some View {
        Section("食事") {
            LabeledContent("記録", value: "\(summary.meal.activityCount) 回")
            LabeledContent("写真", value: "\(summary.meal.photoCount) 枚")
        }
    }

    private var rangeLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = period == .week ? "MMM d" : "yyyy MMM"
        let endInclusive = calendar.date(byAdding: .day, value: -1, to: summary.end) ?? summary.end
        if period == .month {
            return formatter.string(from: summary.start)
        }
        return "\(formatter.string(from: summary.start)) – \(formatter.string(from: endInclusive))"
    }

    private func shiftPeriod(by delta: Int) {
        withAnimation {
            referenceDate = period.shift(delta, from: referenceDate, calendar: calendar)
        }
    }

    private func toggle(_ id: UUID) {
        if expandedIDs.contains(id) {
            expandedIDs.remove(id)
        } else {
            expandedIDs.insert(id)
        }
    }
}

private struct CategoryRow: View {
    let category: PeriodActivitySummary.CategoryStats
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: onToggle) {
                HStack {
                    Circle()
                        .fill(Color(hex: category.colorHex) ?? .accentColor)
                        .frame(width: 12, height: 12)
                    Text(category.templateName)
                        .font(.body)
                    Spacer()
                    Text(DurationFormatter.elapsed(seconds: Int(category.totalSeconds)))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    if !category.children.isEmpty {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(category.children) { child in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color(hex: child.colorHex) ?? .accentColor)
                            .frame(width: 8, height: 8)
                        Text(child.templateName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(DurationFormatter.elapsed(seconds: Int(child.totalSeconds)))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .padding(.leading, 20)
                }
            }
        }
    }
}
