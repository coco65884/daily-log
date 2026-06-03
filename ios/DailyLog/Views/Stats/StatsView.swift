import SwiftData
import SwiftUI

/// 統計タブのトップ画面。タップ直後にその週の統計 (24h チャート + サマリー) を表示し、
/// 右上の週/月トグルで期間を切り替える。
struct StatsView: View {
    @Query(sort: \Activity.startAt)
    private var allActivities: [Activity]

    @State private var period: PeriodActivitySummary.Period = .week
    @State private var referenceDate: Date = .init()

    private let calendar: Calendar = .currentGregorian

    /// 月チャートの 1 日あたりの列幅 (横スクロール時)。
    private let monthColumnWidth: CGFloat = 40

    private var summary: PeriodActivitySummary.Summary {
        PeriodActivitySummary.summarize(
            activities: allActivities,
            period: period,
            referenceDate: referenceDate,
            calendar: calendar
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    periodNavigation
                    chartSection
                    StatsSummaryView(summary: summary)
                }
                .padding()
            }
            .navigationTitle("統計")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    periodPicker
                }
            }
        }
    }

    private var periodPicker: some View {
        Picker("期間", selection: $period) {
            ForEach(PeriodActivitySummary.Period.allCases) { option in
                Text(option.displayName).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 120)
    }

    @ViewBuilder
    private var chartSection: some View {
        switch period {
        case .week:
            ActivityColumnsChart(spans: weekSpans, columnLabels: weekdayLabels, columnWidth: nil)
                .frame(height: 420)
        case .month:
            ActivityColumnsChart(spans: monthSpans, columnLabels: monthDayLabels, columnWidth: monthColumnWidth)
                .frame(height: 420)
        }
    }

    private var periodNavigation: some View {
        HStack {
            Button {
                shiftPeriod(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
            }
            .accessibilityLabel("前の期間")

            Spacer()

            Text(rangeLabel)
                .font(.headline)

            Spacer()

            Button {
                shiftPeriod(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.headline)
            }
            .accessibilityLabel("次の期間")
            .disabled(summary.end > calendar.startOfDay(for: Date().addingTimeInterval(86400)))
        }
    }

    // MARK: - Data

    private var weekSpans: [WeekActivityLayout.Span] {
        let weekStart = WeekActivityLayout.weekStart(containing: referenceDate, calendar: calendar)
        return WeekActivityLayout.spans(for: allActivities, weekStart: weekStart, calendar: calendar)
    }

    private var monthSpans: [WeekActivityLayout.Span] {
        WeekActivityLayout.monthSpans(for: allActivities, monthContaining: referenceDate, calendar: calendar)
    }

    private var weekdayLabels: [String] {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "E"
        let weekStart = WeekActivityLayout.weekStart(containing: referenceDate, calendar: calendar)
        return (0 ..< 7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: weekStart) else { return nil }
            return formatter.string(from: date)
        }
    }

    private var monthDayLabels: [String] {
        let (_, dayCount) = WeekActivityLayout.monthRange(containing: referenceDate, calendar: calendar)
        return (1 ... max(dayCount, 1)).map(String.init)
    }

    private var rangeLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = period == .week ? "MMM d" : "yyyy MMM"
        if period == .month {
            return formatter.string(from: summary.start)
        }
        let endInclusive = calendar.date(byAdding: .day, value: -1, to: summary.end) ?? summary.end
        return "\(formatter.string(from: summary.start)) – \(formatter.string(from: endInclusive))"
    }

    private func shiftPeriod(by delta: Int) {
        withAnimation {
            referenceDate = period.shift(delta, from: referenceDate, calendar: calendar)
        }
    }
}
