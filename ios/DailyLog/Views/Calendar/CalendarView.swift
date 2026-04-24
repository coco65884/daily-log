import SwiftData
import SwiftUI

struct CalendarView: View {
    @Query(sort: \Activity.startAt)
    private var activities: [Activity]

    @State private var selectedDate: Date?

    private var datesWithActivity: Set<DateComponents> {
        ActivityDateExtractor.extractDateComponents(from: activities)
    }

    private var activitiesOnSelectedDay: [Activity] {
        guard let selectedDate else { return [] }
        return ActivityDateExtractor.activities(on: selectedDate, from: activities)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ActivityCalendar(
                        selectedDate: $selectedDate,
                        datesWithActivity: datesWithActivity
                    )
                    .frame(minHeight: 360)

                    selectedDaySummary
                }
                .padding()
            }
            .navigationTitle("カレンダー")
            .navigationDestination(item: $selectedDate) { date in
                DayDetailView(date: date)
            }
        }
    }

    @ViewBuilder
    private var selectedDaySummary: some View {
        if let selectedDate {
            VStack(alignment: .leading, spacing: 8) {
                Text(formatted(date: selectedDate))
                    .font(.headline)

                if activitiesOnSelectedDay.isEmpty {
                    Text("この日の記録はありません")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(activitiesOnSelectedDay.count) 件の記録")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    NavigationLink(value: selectedDate) {
                        Label("この日の詳細を見る", systemImage: "chart.pie")
                    }
                    .buttonStyle(.bordered)
                }
            }
        } else {
            Text("日付を選択してください")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func formatted(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }
}
