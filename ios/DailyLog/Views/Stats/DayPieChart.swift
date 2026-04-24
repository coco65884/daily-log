import Charts
import SwiftUI

struct DayPieChart: View {
    let slices: [DayActivitySummary.Slice]

    @State private var selectedID: UUID?

    var body: some View {
        VStack(spacing: 16) {
            if slices.isEmpty {
                emptyState
            } else {
                chart
                legend
            }
        }
    }

    private var chart: some View {
        Chart {
            ForEach(slices) { slice in
                SectorMark(
                    angle: .value("時間", slice.totalSeconds),
                    innerRadius: .ratio(0.55),
                    angularInset: 1
                )
                .foregroundStyle(Color(hex: slice.colorHex) ?? .accentColor)
                .opacity(selectedID == nil || selectedID == slice.id ? 1 : 0.35)
                .cornerRadius(4)
            }
        }
        .chartLegend(.hidden)
        .frame(height: 220)
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(slices) { slice in
                Button {
                    selectedID = selectedID == slice.id ? nil : slice.id
                } label: {
                    legendRow(for: slice)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func legendRow(for slice: DayActivitySummary.Slice) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color(hex: slice.colorHex) ?? .accentColor)
                .frame(width: 12, height: 12)
            Text(slice.templateName)
                .font(.subheadline)
            Spacer()
            Text(DurationFormatter.elapsed(seconds: Int(slice.totalSeconds)))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(selectedID == slice.id ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .contentShape(Rectangle())
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.pie")
                .font(.title)
                .foregroundStyle(.secondary)
            Text("この日の記録はありません")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 40)
    }
}
