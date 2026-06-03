import SwiftUI

/// 週/月の統計サマリー (カテゴリ別棒グラフ + 行 + 食事)。
/// 個別/ジャンル別の表示切替と各行の展開状態を内部で管理する。
struct StatsSummaryView: View {
    let summary: PeriodActivitySummary.Summary

    @State private var displayMode: DisplayMode = .individual
    @State private var expandedIDs: Set<UUID> = []

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

    private var displayCategories: [PeriodActivitySummary.CategoryStats] {
        switch displayMode {
        case .grouped:
            summary.categories
        case .individual:
            Self.flattenedCategories(from: summary.categories)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("表示", selection: $displayMode) {
                ForEach(DisplayMode.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .pickerStyle(.segmented)

            categoriesSection
            mealSection
        }
    }

    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(displayMode == .grouped ? "ジャンル別" : "アクション別")
                .font(.headline)

            if displayCategories.isEmpty {
                Text("この期間の記録はありません")
                    .font(.subheadline)
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

    private var mealSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("食事")
                .font(.headline)
            LabeledContent("記録", value: "\(summary.meal.activityCount) 回")
            LabeledContent("写真", value: "\(summary.meal.photoCount) 枚")
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
    static func flattenedCategories(
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
