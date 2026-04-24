import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("DailyLog")
                .font(.title)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
