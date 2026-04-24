import SwiftUI

struct InProgressCard: View {
    let activity: Activity?
    let onStop: () -> Void

    @State private var now: Date = .init()

    private let timer = Timer
        .publish(every: 1, on: .main, in: .common)
        .autoconnect()

    var body: some View {
        Group {
            if let activity {
                activeContent(for: activity)
            } else {
                emptyContent
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
        .onReceive(timer) { now = $0 }
    }

    private func activeContent(for activity: Activity) -> some View {
        HStack(spacing: 14) {
            iconView(for: activity)

            VStack(alignment: .leading, spacing: 4) {
                Text(activity.template?.name ?? "（テンプレートなし）")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(DurationFormatter.elapsed(from: activity.startAt, to: now))
                    .font(.system(.title3, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(role: .destructive, action: onStop) {
                Label("停止", systemImage: "stop.fill")
                    .labelStyle(.iconOnly)
                    .font(.title3)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var emptyContent: some View {
        HStack(spacing: 10) {
            Image(systemName: "pause.circle")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("記録中の行動なし")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func iconView(for activity: Activity) -> some View {
        if let template = activity.template {
            Image(systemName: template.iconName)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(Color(hex: template.colorHex) ?? .accentColor)
                )
        } else {
            Image(systemName: "clock")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.secondary))
        }
    }
}
