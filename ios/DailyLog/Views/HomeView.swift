import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(
        filter: #Predicate<Activity> { $0.endAt == nil },
        sort: \Activity.startAt,
        order: .reverse
    )
    private var inProgressActivities: [Activity]

    @Query(sort: \ActivityTemplate.sortOrder)
    private var templates: [ActivityTemplate]

    @State private var errorMessage: String?
    @State private var isPresentingTemplates = false

    private var currentActivity: Activity? {
        inProgressActivities.first
    }

    private var service: ActivityService {
        ActivityService(context: modelContext)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    InProgressCard(
                        activity: currentActivity,
                        onStop: { stopCurrent() }
                    )

                    TemplateGrid(
                        templates: templates,
                        onTap: { start(with: $0) }
                    )

                    Spacer(minLength: 0)
                }
                .padding(.horizontal)
                .padding(.top)
            }
            .navigationTitle("DailyLog")
            .task {
                await LocalNotificationNotifier.shared.requestAuthorizationIfNeeded()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresentingTemplates = true
                    } label: {
                        Image(systemName: "square.grid.2x2")
                    }
                    .accessibilityLabel("テンプレート管理")
                }
            }
            .sheet(isPresented: $isPresentingTemplates) {
                TemplateListView()
            }
            .alert(
                "エラー",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                ),
                presenting: errorMessage
            ) { _ in
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: { message in
                Text(message)
            }
        }
    }

    private func stopCurrent() {
        do {
            try service.stopCurrent()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func start(with template: ActivityTemplate) {
        do {
            try service.start(template: template)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
