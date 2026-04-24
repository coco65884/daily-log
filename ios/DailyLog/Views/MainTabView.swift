import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("ホーム", systemImage: "clock")
                }

            CalendarView()
                .tabItem {
                    Label("カレンダー", systemImage: "calendar")
                }
        }
    }
}
