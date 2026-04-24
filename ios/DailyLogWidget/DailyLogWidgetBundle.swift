import SwiftUI
import WidgetKit

@main
struct DailyLogWidgetBundle: WidgetBundle {
    var body: some Widget {
        DailyLogWidget()
        DailyLogLiveActivity()
    }
}
