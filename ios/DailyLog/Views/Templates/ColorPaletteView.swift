import SwiftUI

struct ColorPaletteView: View {
    @Binding var selected: String

    static let palette: [String] = [
        "#4A90E2", "#F5A623", "#6F5BE8", "#50C9BA",
        "#E95E77", "#7F8C8D", "#BFAE82", "#9B59B6",
        "#2ECC71", "#E67E22", "#E74C3C", "#34495E",
    ]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 6)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("カラー")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Self.palette, id: \.self) { hex in
                    Button {
                        selected = hex
                    } label: {
                        Circle()
                            .fill(Color(hex: hex) ?? .accentColor)
                            .frame(height: 36)
                            .overlay(
                                Circle()
                                    .strokeBorder(
                                        selected == hex ? Color.primary : Color.clear,
                                        lineWidth: 3
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(hex)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
