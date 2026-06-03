import Darwin
import SwiftUI

/// 修正画面用の 24 時間ドーナツ。`EditableSegment` から描画し、
/// セグメントをタップすると選択 (`selectedID`) を切り替える。
/// - 1 周 = 24 時間、0 時を真上、時計回り。
struct TimelineEditorDonut: View {
    let segments: [EditableSegment]
    let dayStart: Date
    @Binding var selectedID: UUID?

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let frame = CGRect(
                x: (geometry.size.width - side) / 2,
                y: (geometry.size.height - side) / 2,
                width: side,
                height: side
            )
            Canvas { context, _ in
                draw(in: &context, frame: frame)
            }
            .contentShape(Rectangle())
            .onTapGesture { location in
                selectSegment(at: location, frame: frame)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func draw(in context: inout GraphicsContext, frame: CGRect) {
        let center = CGPoint(x: frame.midX, y: frame.midY)
        let outer = frame.width / 2
        let inner = outer * 0.55

        let ring = annularSector(center: center, innerRadius: inner, outerRadius: outer, startDeg: -90, endDeg: 270)
        context.fill(ring, with: .color(Color.secondary.opacity(0.08)))

        for segment in segments {
            let startDeg = fraction(of: segment.start) * 360 - 90
            let endDeg = fraction(of: segment.end) * 360 - 90
            guard endDeg > startDeg else { continue }
            let color = Color(hex: segment.colorHex) ?? .accentColor
            let isSelected = segment.id == selectedID
            let sector = annularSector(
                center: center,
                innerRadius: inner,
                outerRadius: outer,
                startDeg: startDeg,
                endDeg: endDeg
            )
            context.fill(sector, with: .color(color.opacity(isSelected ? 1 : 0.6)))
            if isSelected {
                context.stroke(sector, with: .color(.primary), lineWidth: 2)
            }
        }
    }

    private func selectSegment(at location: CGPoint, frame: CGRect) {
        let center = CGPoint(x: frame.midX, y: frame.midY)
        let dx = location.x - center.x
        let dy = location.y - center.y
        let radius = Darwin.sqrt(dx * dx + dy * dy)
        let outer = frame.width / 2
        let inner = outer * 0.55
        guard radius >= inner, radius <= outer else { return }

        let degrees = Darwin.atan2(dy, dx) * 180 / .pi
        var frac = (degrees + 90) / 360
        frac = frac.truncatingRemainder(dividingBy: 1)
        if frac < 0 { frac += 1 }
        let tappedTime = dayStart.addingTimeInterval(frac * 86400)

        let hit = segments.first { $0.start <= tappedTime && tappedTime < $0.end }
        selectedID = (hit?.id == selectedID) ? selectedID : hit?.id
    }

    private func fraction(of date: Date) -> Double {
        date.timeIntervalSince(dayStart) / 86400.0
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
}
