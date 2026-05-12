import SwiftData
import SwiftUI

struct PeriodStatsView: View {
    @Query(sort: \Activity.startAt)
    private var allActivities: [Activity]

    @State private var period: PeriodActivitySummary.Period = .week
    @State private var displayMode: DisplayMode = .individual
    @State private var referenceDate: Date = .init()
    @State private var expandedIDs: Set<UUID> = []

    private let calendar: Calendar = .currentGregorian

    enum DisplayMode: String, CaseIterable, Identifiable {
        case individual
        case grouped

        var id: String {
            rawValue
        }

        var displayName: String {
            switch self {
            case .individual: "個別"
            case .grouped: "ジャンル別"
            }
        }
    }

    private var summary: PeriodActivitySummary.Summary {
        PeriodActivitySummary.summarize(
            activities: allActivities,
            period: period,
            referenceDate: referenceDate,
            calendar: calendar
        )
    }

    private var displayCategories: [PeriodActivitySummary.CategoryStats] {
        switch displayMode {
        case .grouped:
            summary.categories
        case .individual:
            flattenedCategories(from: summary.categories)
        }
    }

    var body: some View {
        List {
            periodSection
            displayModeSection
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

    private var displayModeSection: some View {
        Section {
            Picker("表示", selection: $displayMode) {
                ForEach(DisplayMode.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .pickerStyle(.segmented)
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
        Section(categoriesSectionTitle) {
            if displayCategories.isEmpty {
                Text("この期間の記録はありません")
                    .foregroundStyle(.secondary)
            } else {
                CategoryBarChart(categories: displayCategories)

                ForEach(displayCategories) { category in
                    CategoryRow(
                        category: category,
                        isExpanded: expandedIDs.contains(category.id),
                        onToggle: { toggle(category.id) }
                    )
                }
            }
        }
    }

    private var categoriesSectionTitle: String {
        switch displayMode {
        case .individual: "アクション別"
        case .grouped: "ジャンル別"
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

    /// 親子ツリーを平坦化する。親の「自分自身の時間 (= totalSeconds - 子合計)」が
    /// 正のときだけ親エントリを残し、子はそのまま個別エントリとして並べる。
    private func flattenedCategories(
        from categories: [PeriodActivitySummary.CategoryStats]
    ) -> [PeriodActivitySummary.CategoryStats] {
        var result: [PeriodActivitySummary.CategoryStats] = []
        for parent in categories {
            let childSum = parent.children.reduce(0) { $0 + $1.totalSeconds }
            let parentBare = parent.totalSeconds - childSum
            if parentBare > 0 || parent.children.isEmpty {
                result.append(PeriodActivitySummary.CategoryStats(
                    id: parent.id,
                    templateName: parent.templateName,
                    colorHex: parent.colorHex,
                    totalSeconds: parentBare > 0 ? parentBare : parent.totalSeconds,
                    children: []
                ))
            }
            for child in parent.children {
                result.append(PeriodActivitySummary.CategoryStats(
                    id: child.id,
                    templateName: child.templateName,
                    colorHex: child.colorHex,
                    totalSeconds: child.totalSeconds,
                    children: []
                ))
            }
        }
        return result.sorted { $0.totalSeconds > $1.totalSeconds }
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
