import SwiftData
import SwiftUI

struct CalendarView: View {
    @Query(sort: \Activity.startAt)
    private var activities: [Activity]

    @State private var selectedDate: Date?

    private let calendar: Calendar = .currentGregorian

    var body: some View {
        NavigationStack {
            ScrollView {
                MonthGridView(activities: activities, calendar: calendar) { date in
                    selectedDate = date
                }
                .padding()
            }
            .navigationTitle("カレンダー")
            .navigationDestination(item: $selectedDate) { date in
                DayDetailView(date: date)
            }
        }
    }
}
