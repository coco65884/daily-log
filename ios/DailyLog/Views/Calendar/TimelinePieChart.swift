import Darwin
import Foundation
import SwiftUI

/// 24時間時計の見た目で、その日のアクティビティを「開始-終了」の時刻位置に
/// そのまま配置するドーナツチャート。
/// - 1周 = 24時間
/// - 0時を真上 (12時の方向)、時計回りに進行
struct TimelinePieChart: View {
    let day: Date
    let activities: [Activity]
    let calendar: Calendar
    let now: Date

    init(day: Date, activities: [Activity], calendar: Calendar = .currentGregorian, now: Date = Date()) {
        self.day = day
        self.activities = activities
        self.calendar = calendar
        self.now = now
    }

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let frame = CGRect(
                x: (geometry.size.width - side) / 2,
                y: (geometry.size.height - side) / 2,
                width: side,
                height: side
            )
            ZStack {
                Canvas { context, _ in
                    draw(in: &context, frame: frame)
                }
                hourLabels(in: frame)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func draw(in context: inout GraphicsContext, frame: CGRect) {
        let center = CGPoint(x: frame.midX, y: frame.midY)
        let outer = frame.width / 2
        let inner = outer * 0.55

        // 背景の薄いリング (24h 枠)
        let ring = annularSector(
            center: center,
            innerRadius: inner,
            outerRadius: outer,
            startDeg: -90,
            endDeg: 270
        )
        context.fill(ring, with: .color(Color.secondary.opacity(0.08)))

        let dayStart = calendar.startOfDay(for: day)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86400)

        for activity in activities {
            let effectiveEnd = activity.endAt ?? now
            let start = max(activity.startAt, dayStart)
            let end = min(effectiveEnd, dayEnd)
            guard end > start else { continue }
            let startFrac = start.timeIntervalSince(dayStart) / 86400.0
            let endFrac = end.timeIntervalSince(dayStart) / 86400.0
            let startDeg = startFrac * 360.0 - 90.0
            let endDeg = endFrac * 360.0 - 90.0

            let hex = displayHex(for: activity.template)
            let color = Color(hex: hex) ?? .accentColor
            let sector = annularSector(
                center: center,
                innerRadius: inner,
                outerRadius: outer,
                startDeg: startDeg,
                endDeg: endDeg
            )
            context.fill(sector, with: .color(color))
        }

        // 時計の針: 現在時刻のマーク (today のみ)
        if calendar.isDate(now, inSameDayAs: day) {
            let frac = now.timeIntervalSince(dayStart) / 86400.0
            let deg = frac * 360.0 - 90.0
            let radians = deg * .pi / 180.0
            let cosValue = Darwin.cos(radians)
            let sinValue = Darwin.sin(radians)
            let from = CGPoint(
                x: center.x + cosValue * inner,
                y: center.y + sinValue * inner
            )
            let to = CGPoint(
                x: center.x + cosValue * outer,
                y: center.y + sinValue * outer
            )
            var line = Path()
            line.move(to: from)
            line.addLine(to: to)
            context.stroke(line, with: .color(.red), lineWidth: 2)
        }
    }

    private func hourLabels(in frame: CGRect) -> some View {
        let center = CGPoint(x: frame.midX, y: frame.midY)
        let radius = frame.width / 2
        let labelRadius = radius - 6
        let labels: [Int] = [0, 6, 12, 18]
        return ZStack {
            ForEach(labels, id: \.self) { hour in
                let frac = Double(hour) / 24.0
                let deg = frac * 360.0 - 90.0
                let radians = deg * .pi / 180.0
                Text("\(hour)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .position(
                        x: center.x + Darwin.cos(radians) * (labelRadius + 14),
                        y: center.y + Darwin.sin(radians) * (labelRadius + 14)
                    )
            }
        }
    }

    private func annularSector(
        center: CGPoint,
        innerRadius: Double,
        outerRadius: Double,
        startDeg: Double,
        endDeg: Double
    ) -> Path {
        var path = Path()
        path.addArc(
            center: center,
            radius: outerRadius,
            startAngle: .degrees(startDeg),
            endAngle: .degrees(endDeg),
            clockwise: false
        )
        path.addArc(
            center: center,
            radius: innerRadius,
            startAngle: .degrees(endDeg),
            endAngle: .degrees(startDeg),
            clockwise: true
        )
        path.closeSubpath()
        return path
    }

    private func displayHex(for template: ActivityTemplate?) -> String {
        guard let template else { return "#7F8C8D" }
        guard let parent = template.parent else { return template.colorHex }
        let siblings = parent.children.sorted { $0.sortOrder < $1.sortOrder }
        let index = siblings.firstIndex { $0.id == template.id } ?? 0
        return HexColor.shaded(parentHex: parent.colorHex, childIndex: index)
    }
}
