import Darwin
import SwiftUI

/// 日別詳細の時系列ドーナツ (読み取り専用 + タップで吹き出し)。
/// - 1 周 = 24 時間、0 時を真上、時計回り
/// - ラベル (0/6/12/18) が枠外にはみ出さないよう内側に余白を取り、確実に中央寄せする
/// - セグメントをタップするとアクション名 + 開始/終了時刻を吹き出し表示 (再タップで閉じる)
struct DayTimelineDonut: View {
    let segments: [EditableSegment]
    let dayStart: Date

    @State private var selectedID: UUID?

    /// ラベル用に確保する外周の余白。
    private let labelInset: CGFloat = 20

    private var selectedSegment: EditableSegment? {
        segments.first { $0.id == selectedID }
    }

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let outer = side / 2 - labelInset
            let inner = outer * 0.55
            ZStack {
                Canvas { context, _ in
                    draw(in: &context, center: center, inner: inner, outer: outer)
                }
                .contentShape(Rectangle())
                .onTapGesture { location in
                    handleTap(at: location, center: center, inner: inner, outer: outer)
                }
                hourLabels(center: center, radius: outer)
                if let segment = selectedSegment {
                    callout(for: segment, center: center, inner: inner, outer: outer)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: .infinity)
    }

    private func draw(in context: inout GraphicsContext, center: CGPoint, inner: Double, outer: Double) {
        let ring = annularSector(center: center, inner: inner, outer: outer, startDeg: -90, endDeg: 270)
        context.fill(ring, with: .color(Color.secondary.opacity(0.08)))

        for segment in segments {
            let startDeg = fraction(of: segment.start) * 360 - 90
            let endDeg = fraction(of: segment.end) * 360 - 90
            guard endDeg > startDeg else { continue }
            let color = Color(hex: segment.colorHex) ?? .accentColor
            let isDimmed = selectedID != nil && segment.id != selectedID
            let sector = annularSector(center: center, inner: inner, outer: outer, startDeg: startDeg, endDeg: endDeg)
            context.fill(sector, with: .color(color.opacity(isDimmed ? 0.4 : 1)))
        }
    }

    private func hourLabels(center: CGPoint, radius: Double) -> some View {
        ZStack {
            ForEach([0, 6, 12, 18], id: \.self) { hour in
                let deg = Double(hour) / 24 * 360 - 90
                let radians = deg * .pi / 180
                Text("\(hour)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .position(
                        x: center.x + Darwin.cos(radians) * (radius + 10),
                        y: center.y + Darwin.sin(radians) * (radius + 10)
                    )
            }
        }
    }

    @ViewBuilder
    private func callout(for segment: EditableSegment, center: CGPoint, inner: Double, outer: Double) -> some View {
        let midDeg = (fraction(of: segment.start) + fraction(of: segment.end)) / 2 * 360 - 90
        let radians = midDeg * .pi / 180
        let radius = (inner + outer) / 2
        DayCalloutBubble(title: segment.templateName, timeRange: timeRangeText(for: segment))
            .position(
                x: center.x + Darwin.cos(radians) * radius,
                y: center.y + Darwin.sin(radians) * radius
            )
            .allowsHitTesting(false)
    }

    private func handleTap(at location: CGPoint, center: CGPoint, inner: Double, outer: Double) {
        let dx = location.x - center.x
        let dy = location.y - center.y
        let radius = Darwin.sqrt(dx * dx + dy * dy)
        guard radius >= inner, radius <= outer else {
            selectedID = nil
            return
        }
        let degrees = Darwin.atan2(dy, dx) * 180 / .pi
        var frac = (degrees + 90) / 360
        frac = frac.truncatingRemainder(dividingBy: 1)
        if frac < 0 { frac += 1 }
        let tappedTime = dayStart.addingTimeInterval(frac * 86400)
        let hit = segments.first { $0.start <= tappedTime && tappedTime < $0.end }
        selectedID = (hit?.id == selectedID) ? nil : hit?.id
    }

    private func timeRangeText(for segment: EditableSegment) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: segment.start)) – \(formatter.string(from: segment.end))"
    }

    private func fraction(of date: Date) -> Double {
        date.timeIntervalSince(dayStart) / 86400.0
    }

    private func annularSector(
        center: CGPoint,
        inner: Double,
        outer: Double,
        startDeg: Double,
        endDeg: Double
    ) -> Path {
        var path = Path()
        path.addArc(
            center: center,
            radius: outer,
            startAngle: .degrees(startDeg),
            endAngle: .degrees(endDeg),
            clockwise: false
        )
        path.addArc(
            center: center,
            radius: inner,
            startAngle: .degrees(endDeg),
            endAngle: .degrees(startDeg),
            clockwise: true
        )
        path.closeSubpath()
        return path
    }
}

private struct DayCalloutBubble: View {
    let title: String
    let timeRange: String

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption.bold())
                .lineLimit(1)
            Text(timeRange)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.2), radius: 4, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
        .fixedSize()
    }
}
