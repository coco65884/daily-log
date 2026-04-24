import Charts
import SwiftUI

struct WeekActivityChart: View {
    let weekStart: Date
    let spans: [WeekActivityLayout.Span]
    let weekdayLabels: [String]

    var body: some View {
        Chart {
            ForEach(spans) { span in
                RectangleMark(
                    xStart: .value("start-day", Double(span.weekdayIndex) - 0.4),
                    xEnd: .value("end-day", Double(span.weekdayIndex) + 0.4),
                    yStart: .value("start-hour", span.startHours),
                    yEnd: .value("end-hour", span.endHours)
                )
                .foregroundStyle(Color(hex: span.colorHex) ?? .accentColor)
                .opacity(0.85)
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
                    if let hour = value.as(Double.self) {
                        Text(String(format: "%02d:00", Int(hour)))
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
