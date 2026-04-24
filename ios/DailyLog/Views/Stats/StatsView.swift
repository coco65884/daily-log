import SwiftUI

struct StatsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("チャート") {
                    NavigationLink("週 24 時間チャート") {
                        WeekChartView()
                    }
                    // #16 日別円グラフ / #17 週月統計 は追って追加
                }
            }
            .navigationTitle("統計")
        }
    }
}
