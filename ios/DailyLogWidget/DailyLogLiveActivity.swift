import ActivityKit
import SwiftUI
import WidgetKit

struct DailyLogLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DailyLogActivityAttributes.self) { context in
            LockScreenView(context: context)
                .activityBackgroundTint(
                    (Color(hex: context.attributes.colorHex) ?? .accentColor).opacity(0.2)
                )
                .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    icon(for: context.attributes)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.startAt, style: .timer)
                        .monospacedDigit()
                        .font(.title3)
                        .frame(maxWidth: 72, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.attributes.templateName)
                        .font(.headline)
                }
            } compactLeading: {
                icon(for: context.attributes)
            } compactTrailing: {
                Text(context.state.startAt, style: .timer)
                    .monospacedDigit()
                    .frame(maxWidth: 52)
            } minimal: {
                icon(for: context.attributes)
            }
            .keylineTint(Color(hex: context.attributes.colorHex) ?? .accentColor)
        }
    }

    private func icon(for attributes: DailyLogActivityAttributes) -> some View {
        Image(systemName: attributes.iconName)
            .font(.callout)
            .foregroundStyle(.white)
            .frame(width: 24, height: 24)
            .background(
                Circle()
                    .fill(Color(hex: attributes.colorHex) ?? .accentColor)
            )
    }
}

private struct LockScreenView: View {
    let context: ActivityViewContext<DailyLogActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                iconBadge
                Text(context.attributes.templateName)
                    .font(.headline)
                Spacer()
                if context.attributes.isMealType {
                    Label("食事", systemImage: "fork.knife")
                        .labelStyle(.iconOnly)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(context.state.startAt, style: .timer)
                .font(.system(.largeTitle, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding()
    }

    private var iconBadge: some View {
        Image(systemName: context.attributes.iconName)
            .font(.body)
            .foregroundStyle(.white)
            .frame(width: 32, height: 32)
            .background(
                Circle()
                    .fill(Color(hex: context.attributes.colorHex) ?? .accentColor)
            )
    }
}
