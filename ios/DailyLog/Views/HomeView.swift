import SwiftData
import SwiftUI

struct HomeView: View {
    @Query(
        filter: #Predicate<Activity> { $0.endAt == nil },
        sort: \Activity.startAt,
        order: .reverse
    )
    private var inProgressActivities: [Activity]

    @Query(
        filter: #Predicate<ActivityTemplate> { $0.parent == nil },
        sort: \ActivityTemplate.sortOrder
    )
    private var rootTemplates: [ActivityTemplate]

    private var currentActivity: Activity? {
        inProgressActivities.first
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
                        templates: rootTemplates,
                        onTap: { start(with: $0) }
                    )

                    Spacer(minLength: 0)
                }
                .padding(.horizontal)
                .padding(.top)
            }
            .navigationTitle("DailyLog")
        }
    }

    // MARK: - Placeholder handlers (wired up in #7)

    private func stopCurrent() {
        // #7 で実装
    }

    private func start(with template: ActivityTemplate) {
        // #7 で実装
        _ = template
    }
}
