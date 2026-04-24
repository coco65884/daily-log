import SwiftUI
import WidgetKit

struct DailyLogWidget: Widget {
    let kind: String = "DailyLogWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DailyLogTimelineProvider()) { entry in
            DailyLogWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    entry.backgroundColor
                }
        }
        .configurationDisplayName("DailyLog")
        .description("進行中の行動を表示します")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct DailyLogEntry: TimelineEntry {
    let date: Date
    let snapshot: CurrentActivitySnapshot?

    var backgroundColor: Color {
        if let hex = snapshot?.colorHex, let color = Color(hex: hex) {
            return color.opacity(0.18)
        }
        return Color(.systemBackground)
    }
}

struct DailyLogTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> DailyLogEntry {
        DailyLogEntry(date: Date(), snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyLogEntry) -> Void) {
        completion(DailyLogEntry(date: Date(), snapshot: CurrentActivitySnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyLogEntry>) -> Void) {
        let now = Date()
        let snapshot = CurrentActivitySnapshot.load()
        let entries = [DailyLogEntry(date: now, snapshot: snapshot)]
        let refresh = Calendar.current.date(byAdding: .minute, value: 15, to: now) ?? now
        completion(Timeline(entries: entries, policy: .after(refresh)))
    }
}

struct DailyLogWidgetEntryView: View {
    let entry: DailyLogEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            activeLayout(for: snapshot)
        } else {
            idleLayout
        }
    }

    private func activeLayout(for snapshot: CurrentActivitySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: snapshot.iconName)
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(Color(hex: snapshot.colorHex) ?? .accentColor)
                    )

                Text(snapshot.templateName)
                    .font(.headline)
                    .lineLimit(1)

                Spacer(minLength: 4)
            }

            Text(snapshot.startAt, style: .timer)
                .font(.system(.title2, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            if snapshot.isMealType {
                Label("食事", systemImage: "fork.knife")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var idleLayout: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: "pause.circle")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("DailyLog")
                .font(.headline)
            Text("記録中の行動なし")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
