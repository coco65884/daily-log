import SwiftUI

struct StatsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("チャート") {
                    NavigationLink("週 24 時間チャート") {
                        WeekChartView()
                    }
                    NavigationLink("週/月サマリー") {
                        PeriodStatsView()
                    }
                }
            }
            .navigationTitle("統計")
        }
    }
}
