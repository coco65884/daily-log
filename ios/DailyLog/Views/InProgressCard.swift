import SwiftUI

struct InProgressCard: View {
    let activity: Activity?
    let onStop: () -> Void

    @State private var now: Date = .init()
    @State private var isPresentingVoiceMemo = false
    @State private var isPresentingMeal = false

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
        .sheet(isPresented: $isPresentingVoiceMemo) {
            if let activity {
                VoiceMemoSheet(activity: activity)
            }
        }
        .sheet(isPresented: $isPresentingMeal) {
            if let activity {
                MealDetailView(activity: activity)
            }
        }
    }

    private func activeContent(for activity: Activity) -> some View {
        HStack(spacing: 12) {
            iconView(for: activity)

            VStack(alignment: .leading, spacing: 4) {
                Text(activity.template?.name ?? "（テンプレートなし）")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(DurationFormatter.elapsed(from: activity.startAt, to: now))
                    .font(.system(.title3, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if activity.template?.isMealType == true {
                mealButton
            }

            micButton

            stopButton
        }
    }

    private var mealButton: some View {
        Button {
            isPresentingMeal = true
        } label: {
            Image(systemName: "fork.knife")
                .font(.title3)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel("食事の記録")
    }

    private var micButton: some View {
        Button {
            isPresentingVoiceMemo = true
        } label: {
            Image(systemName: "mic")
                .font(.title3)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel("音声メモ")
    }

    private var stopButton: some View {
        Button(role: .destructive, action: onStop) {
            Image(systemName: "stop.fill")
                .font(.title3)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityLabel("停止")
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
