import Darwin
import SwiftUI

/// 修正画面用の 24 時間ドーナツ。`EditableSegment` から描画し、
/// セグメントをタップすると選択 (`selectedID`) を切り替える。
/// - 1 周 = 24 時間、0 時を真上、時計回り。
struct TimelineEditorDonut: View {
    let segments: [EditableSegment]
    let dayStart: Date
    @Binding var selectedID: UUID?
    /// ドラッグ開始時に呼ばれる (呼び出し側で基準レイアウトを退避)。
    var onBeginDrag: () -> Void = {}
    /// ドラッグ中、(セグメントID, 開始境界か, 新しい時刻) を通知。
    var onDragBoundary: (UUID, Bool, Date) -> Void = { _, _, _ in }
    /// ドラッグ確定時に呼ばれる。
    var onEndDrag: () -> Void = {}

    /// ドラッグ中に掴んでいる境界。
    @State private var grab: Grab?

    private struct Grab {
        let id: UUID
        let isStart: Bool
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
            Canvas { context, _ in
                draw(in: &context, frame: frame)
            }
            .contentShape(Rectangle())
            .onTapGesture { location in
                selectSegment(at: location, frame: frame)
            }
            .gesture(dragGesture(frame: frame))
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func dragGesture(frame: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .local)
            .onChanged { value in handleDrag(value, frame: frame) }
            .onEnded { _ in
                if grab != nil { onEndDrag() }
                grab = nil
            }
    }

    private func handleDrag(_ value: DragGesture.Value, frame: CGRect) {
        if grab == nil {
            // ドラッグ開始位置から掴む境界を決定する。
            guard inRing(value.startLocation, frame: frame) else { return }
            let startTime = angleTime(at: value.startLocation, frame: frame)
            guard let segment = segmentContaining(startTime) ?? selectedSegment else { return }
            let isStart = abs(startTime.timeIntervalSince(segment.start))
                <= abs(segment.end.timeIntervalSince(startTime))
            grab = Grab(id: segment.id, isStart: isStart)
            selectedID = segment.id
            onBeginDrag()
        }
        guard let grab else { return }
        let time = snap(angleTime(at: value.location, frame: frame))
        onDragBoundary(grab.id, grab.isStart, time)
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
        guard inRing(location, frame: frame) else { return }
        let tappedTime = angleTime(at: location, frame: frame)
        if let hit = segmentContaining(tappedTime) {
            selectedID = hit.id
        }
    }

    private func segmentContaining(_ time: Date) -> EditableSegment? {
        segments.first { $0.start <= time && time < $0.end }
    }

    private var selectedSegment: EditableSegment? {
        segments.first { $0.id == selectedID }
    }

    private func inRing(_ location: CGPoint, frame: CGRect) -> Bool {
        let dx = location.x - frame.midX
        let dy = location.y - frame.midY
        let radius = Darwin.sqrt(dx * dx + dy * dy)
        let outer = frame.width / 2
        return radius >= outer * 0.55 && radius <= outer
    }

    /// タッチ位置の角度から当日内の時刻を求める (0 時を真上、時計回り)。
    private func angleTime(at location: CGPoint, frame: CGRect) -> Date {
        let dx = location.x - frame.midX
        let dy = location.y - frame.midY
        let degrees = Darwin.atan2(dy, dx) * 180 / .pi
        var frac = (degrees + 90) / 360
        frac = frac.truncatingRemainder(dividingBy: 1)
        if frac < 0 { frac += 1 }
        return dayStart.addingTimeInterval(frac * 86400)
    }

    /// 5 分単位にスナップする。
    private func snap(_ date: Date) -> Date {
        let step: TimeInterval = 5 * 60
        let snapped = (date.timeIntervalSince(dayStart) / step).rounded() * step
        return dayStart.addingTimeInterval(snapped)
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
