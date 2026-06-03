import Charts
import SwiftUI

struct WeekActivityChart: View {
    let weekStart: Date
    let spans: [WeekActivityLayout.Span]
    let weekdayLabels: [String]

    @State private var selectedSpanID: UUID?

    private var selectedSpan: WeekActivityLayout.Span? {
        spans.first { $0.id == selectedSpanID }
    }

    var body: some View {
        Chart {
            ForEach(spans) { span in
                let xStart = Double(span.weekdayIndex) - 0.4
                let xEnd = Double(span.weekdayIndex) + 0.4
                // 上=00:00, 下=24:00 にするため (24 - hours) に変換してプロットする。
                let yStart: Double = 24 - span.endHours
                let yEnd: Double = 24 - span.startHours
                RectangleMark(
                    xStart: .value("start-day", xStart),
                    xEnd: .value("end-day", xEnd),
                    yStart: .value("start-hour", yStart),
                    yEnd: .value("end-hour", yEnd)
                )
                .foregroundStyle(Color(hex: span.colorHex) ?? .accentColor)
                .opacity(selectedSpanID == nil || selectedSpanID == span.id ? 0.95 : 0.4)
            }
        }
        .chartXScale(domain: -0.5 ... 6.5)
        .chartYScale(domain: 0.0 ... 24.0)
        .chartXAxis {
            AxisMarks(values: Array(0 ..< 7).map(Double.init)) { value in
                AxisValueLabel { weekdayLabel(for: value) }
            }
        }
        .chartYAxis {
            AxisMarks(values: [0.0, 6.0, 12.0, 18.0, 24.0]) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let plotted = value.as(Double.self) {
                        // プロット値は反転済みなので元の時刻は (24 - plotted)。
                        Text(String(format: "%02d:00", Int(24 - plotted)))
                            .font(.caption2)
                    }
                }
            }
        }
        .chartPlotStyle { plot in
            plot
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.secondarySystemBackground))
                )
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                tapTarget(proxy: proxy, geo: geo)
                if let span = selectedSpan {
                    callout(for: span, proxy: proxy, geo: geo)
                }
            }
        }
    }

    private func tapTarget(proxy: ChartProxy, geo: GeometryProxy) -> some View {
        Rectangle()
            .fill(.clear)
            .contentShape(Rectangle())
            .onTapGesture { location in
                handleTap(at: location, proxy: proxy, geo: geo)
            }
    }

    private func handleTap(at location: CGPoint, proxy: ChartProxy, geo: GeometryProxy) {
        guard let plotAnchor = proxy.plotFrame else { return }
        let origin = geo[plotAnchor].origin
        guard
            let xValue: Double = proxy.value(atX: location.x - origin.x),
            let yValue: Double = proxy.value(atY: location.y - origin.y)
        else { return }
        let hour = 24 - yValue
        let dayIndex = Int(xValue.rounded())
        let hit = spans.first { span in
            span.weekdayIndex == dayIndex && hour >= span.startHours && hour <= span.endHours
        }
        withAnimation(.easeOut(duration: 0.15)) {
            selectedSpanID = (hit?.id == selectedSpanID) ? nil : hit?.id
        }
    }

    @ViewBuilder
    private func callout(for span: WeekActivityLayout.Span, proxy: ChartProxy, geo: GeometryProxy) -> some View {
        if let point = calloutPoint(for: span, proxy: proxy, geo: geo) {
            CalloutBubble(
                title: span.templateName,
                timeRange: timeRangeText(for: span),
                duration: durationText(for: span)
            )
            .position(x: point.x, y: point.y)
            .allowsHitTesting(false)
        }
    }

    private func calloutPoint(
        for span: WeekActivityLayout.Span,
        proxy: ChartProxy,
        geo: GeometryProxy
    ) -> CGPoint? {
        guard
            let plotAnchor = proxy.plotFrame,
            let xPos = proxy.position(forX: Double(span.weekdayIndex)),
            let yPos = proxy.position(forY: 24 - (span.startHours + span.endHours) / 2)
        else { return nil }
        let origin = geo[plotAnchor].origin
        return CGPoint(x: origin.x + xPos, y: origin.y + yPos)
    }

    private func timeRangeText(for span: WeekActivityLayout.Span) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: span.startDate)) – \(formatter.string(from: span.endDate))"
    }

    private func durationText(for span: WeekActivityLayout.Span) -> String {
        let seconds = Int(span.endDate.timeIntervalSince(span.startDate))
        return DurationFormatter.elapsed(seconds: seconds)
    }

    @ViewBuilder
    private func weekdayLabel(for value: AxisValue) -> some View {
        if let raw = value.as(Double.self) {
            let idx = Int(raw)
            if idx >= 0, idx < weekdayLabels.count {
                Text(weekdayLabels[idx])
                    .font(.caption)
            }
        }
    }
}

/// セグメントタップ時に表示する吹き出し。
private struct CalloutBubble: View {
    let title: String
    let timeRange: String
    let duration: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.bold())
                .lineLimit(1)
            Text(timeRange)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
            Text(duration)
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
