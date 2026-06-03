import SwiftUI

/// 自前の月カレンダーグリッド。各日付セルにその日の時系列円グラフ (ミニ) を表示し、
/// タップでその日の詳細へ遷移するための `onSelect` を呼ぶ。
struct MonthGridView: View {
    let activities: [Activity]
    var calendar: Calendar = .currentGregorian
    let onSelect: (Date) -> Void

    @State private var monthAnchor: Date = .init()

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        VStack(spacing: 12) {
            header
            weekdayHeader
            grid
        }
    }

    private var header: some View {
        HStack {
            Button {
                shiftMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left").font(.headline)
            }
            .accessibilityLabel("前の月")

            Spacer()

            Text(monthTitle).font(.headline)

            Spacer()

            Button {
                shiftMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right").font(.headline)
            }
            .accessibilityLabel("次の月")
        }
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Array(orderedWeekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(cells) { cell in
                cellView(for: cell)
            }
        }
    }

    @ViewBuilder
    private func cellView(for cell: DayCell) -> some View {
        if let date = cell.date {
            Button {
                onSelect(date)
            } label: {
                DayCellContent(
                    date: date,
                    dayNumber: cell.dayNumber,
                    activities: ActivityDateExtractor.activities(on: date, from: activities, calendar: calendar),
                    isToday: calendar.isDateInToday(date),
                    calendar: calendar
                )
            }
            .buttonStyle(.plain)
        } else {
            Color.clear.frame(height: 56)
        }
    }

    // MARK: - Data

    private var cells: [DayCell] {
        let (start, dayCount) = WeekActivityLayout.monthRange(containing: monthAnchor, calendar: calendar)
        let weekday = calendar.component(.weekday, from: start)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        var result: [DayCell] = (0 ..< leading).map { DayCell(id: "b\($0)", date: nil, dayNumber: 0) }
        for day in 1 ... dayCount {
            let date = calendar.date(byAdding: .day, value: day - 1, to: start) ?? start
            result.append(DayCell(id: "d\(day)", date: date, dayNumber: day))
        }
        return result
    }

    private var orderedWeekdaySymbols: [String] {
        let symbols = calendar.shortWeekdaySymbols // index 0 = 日曜
        let first = calendar.firstWeekday - 1
        return (0 ..< 7).map { symbols[(first + $0) % 7] }
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("yMMMM")
        return formatter.string(from: monthAnchor)
    }

    private func shiftMonth(by delta: Int) {
        if let next = calendar.date(byAdding: .month, value: delta, to: monthAnchor) {
            withAnimation { monthAnchor = next }
        }
    }
}

private struct DayCell: Identifiable {
    let id: String
    let date: Date?
    let dayNumber: Int
}

private struct DayCellContent: View {
    let date: Date
    let dayNumber: Int
    let activities: [Activity]
    let isToday: Bool
    let calendar: Calendar

    var body: some View {
        VStack(spacing: 2) {
            Text("\(dayNumber)")
                .font(.caption2)
                .fontWeight(isToday ? .bold : .regular)
                .foregroundStyle(isToday ? Color.accentColor : .primary)

            if activities.isEmpty {
                Color.clear.frame(width: 34, height: 34)
            } else {
                TimelinePieChart(
                    day: date,
                    activities: activities,
                    calendar: calendar,
                    showsHourLabels: false,
                    showsNowHand: false
                )
                .frame(width: 34, height: 34)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isToday ? Color.accentColor.opacity(0.12) : Color.clear)
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .long
        let base = formatter.string(from: date)
        return activities.isEmpty ? base : "\(base)、\(activities.count) 件の記録"
    }
}
