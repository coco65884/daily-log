import SwiftUI
import WidgetKit

struct DailyLogWidget: Widget {
    let kind: String = "DailyLogWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DailyLogTimelineProvider()) { entry in
            DailyLogWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("DailyLog")
        .description("進行中の行動を表示します")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct DailyLogEntry: TimelineEntry {
    let date: Date
}

struct DailyLogTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> DailyLogEntry {
        DailyLogEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyLogEntry) -> Void) {
        completion(DailyLogEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyLogEntry>) -> Void) {
        let timeline = Timeline(entries: [DailyLogEntry(date: Date())], policy: .atEnd)
        completion(timeline)
    }
}

struct DailyLogWidgetEntryView: View {
    let entry: DailyLogEntry

    var body: some View {
        VStack(alignment: .leading) {
            Text("DailyLog")
                .font(.headline)
            Text(entry.date, style: .time)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
