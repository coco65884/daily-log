import ActivityKit
import AppIntents
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
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.templateName)
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 8) {
                        Button(intent: StopCurrentActivityIntent()) {
                            Label("停止", systemImage: "stop.fill")
                                .font(.subheadline)
                        }
                        .tint(.red)
                        ForEach(context.state.nextCandidates.prefix(2)) { candidate in
                            Button(intent: StartTemplateIntent(templateID: candidate.templateID)) {
                                Label(candidate.name, systemImage: candidate.iconName)
                                    .font(.subheadline)
                                    .lineLimit(1)
                            }
                            .tint(Color(hex: candidate.colorHex) ?? .accentColor)
                        }
                    }
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                iconBadge

                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.templateName)
                        .font(.headline)
                        .lineLimit(1)
                    Text(context.state.startAt, style: .timer)
                        .font(.system(.title3, design: .monospaced))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }

                Spacer()

                Button(intent: StopCurrentActivityIntent()) {
                    Label("停止", systemImage: "stop.fill")
                        .labelStyle(.iconOnly)
                        .font(.title3)
                        .padding(10)
                }
                .tint(.red)
                .buttonStyle(.bordered)
                .accessibilityLabel("停止")
            }

            if !context.state.nextCandidates.isEmpty {
                candidateRow
            }
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

    private var candidateRow: some View {
        HStack(spacing: 6) {
            Text("次:")
                .font(.caption2)
                .foregroundStyle(.secondary)
            ForEach(context.state.nextCandidates.prefix(3)) { candidate in
                Button(intent: StartTemplateIntent(templateID: candidate.templateID)) {
                    Label(candidate.name, systemImage: candidate.iconName)
                        .font(.caption)
                        .lineLimit(1)
                        .padding(.horizontal, 4)
                }
                .tint(Color(hex: candidate.colorHex) ?? .accentColor)
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
}
