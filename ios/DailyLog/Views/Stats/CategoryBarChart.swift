import Charts
import SwiftUI

struct CategoryBarChart: View {
    let categories: [PeriodActivitySummary.CategoryStats]

    var body: some View {
        Chart {
            ForEach(categories) { category in
                BarMark(
                    x: .value("時間", category.totalSeconds / 3600),
                    y: .value("カテゴリ", category.templateName)
                )
                .foregroundStyle(Color(hex: category.colorHex) ?? .accentColor)
                .annotation(position: .trailing, alignment: .leading) {
                    Text(DurationFormatter.elapsed(seconds: Int(category.totalSeconds)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let hours = value.as(Double.self) {
                        Text("\(Int(hours))h")
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
    }
}
