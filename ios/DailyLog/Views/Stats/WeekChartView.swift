import SwiftData
import SwiftUI

struct WeekChartView: View {
    @Query(sort: \Activity.startAt)
    private var allActivities: [Activity]

    @State private var weekStart: Date = WeekActivityLayout.weekStart(containing: Date())

    private let calendar: Calendar = .currentGregorian

    private var weekEnd: Date {
        calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
    }

    private var spans: [WeekActivityLayout.Span] {
        WeekActivityLayout.spans(for: allActivities, weekStart: weekStart, calendar: calendar)
    }

    private var weekdayLabels: [String] {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "E"
        return (0 ..< 7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: weekStart) else { return nil }
            return formatter.string(from: date)
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            navigation
            chartSection
        }
        .padding()
        .gesture(swipeGesture)
        .navigationTitle("週ビュー")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var navigation: some View {
        HStack {
            Button {
                move(weeks: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
            }
            .accessibilityLabel("前の週")

            Spacer()

            Text(rangeLabel)
                .font(.headline)

            Spacer()

            Button {
                move(weeks: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.headline)
            }
            .accessibilityLabel("次の週")
            .disabled(weekEnd > calendar.startOfDay(for: Date().addingTimeInterval(86400)))
        }
    }

    private var chartSection: some View {
        WeekActivityChart(weekStart: weekStart, spans: spans, weekdayLabels: weekdayLabels)
            .frame(height: 420)
    }

    private var rangeLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "MMM d"
        let last = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        return "\(formatter.string(from: weekStart)) – \(formatter.string(from: last))"
    }

    private var swipeGesture: some Gesture {
        DragGesture()
            .onEnded { value in
                if value.translation.width > 50 {
                    move(weeks: -1)
                } else if value.translation.width < -50 {
                    move(weeks: 1)
                }
            }
    }

    private func move(weeks: Int) {
        if let next = calendar.date(byAdding: .day, value: weeks * 7, to: weekStart) {
            withAnimation { weekStart = next }
        }
    }
}
