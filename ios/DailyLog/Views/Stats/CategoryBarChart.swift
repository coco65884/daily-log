import Charts
import SwiftUI

struct CategoryBarChart: View {
    let categories: [PeriodActivitySummary.CategoryStats]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            chart
            legend
        }
    }

    private var chart: some View {
        Chart {
            ForEach(categories) { category in
                BarMark(
                    x: .value("カテゴリ", category.templateName),
                    y: .value("時間", category.totalSeconds / 3600)
                )
                .foregroundStyle(Color(hex: category.colorHex) ?? .accentColor)
                .annotation(position: .top, alignment: .center) {
                    Text(DurationFormatter.elapsed(seconds: Int(category.totalSeconds)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic) { value in
                AxisValueLabel {
                    if let name = value.as(String.self) {
                        Text(name)
                            .font(.caption2)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let hours = value.as(Double.self) {
                        Text("\(Int(hours))h")
                    }
                }
            }
        }
        .frame(minHeight: 220)
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(categories) { category in
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: category.colorHex) ?? .accentColor)
                        .frame(width: 10, height: 10)
                    Text(category.templateName)
                        .font(.caption)
                    Spacer()
                    Text(DurationFormatter.elapsed(seconds: Int(category.totalSeconds)))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
