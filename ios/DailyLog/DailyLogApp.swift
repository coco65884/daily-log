import SwiftData
import SwiftUI

@main
struct DailyLogApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try AppModelContainer.makeContainer()
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
