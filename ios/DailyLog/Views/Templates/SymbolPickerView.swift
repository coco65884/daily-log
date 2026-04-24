import SwiftUI

struct SymbolPickerView: View {
    @Binding var selected: String
    @Environment(\.dismiss) private var dismiss
    @State private var search: String = ""

    static let allSymbols: [String] = [
        "circle", "square", "star.fill", "heart.fill", "flag.fill",
        "clock", "timer", "calendar", "bell", "hourglass",
        "moon.fill", "sun.max.fill", "cloud.fill", "leaf.fill", "flame.fill",
        "fork.knife", "cup.and.saucer.fill", "wineglass.fill", "takeoutbag.and.cup.and.straw.fill", "birthday.cake",
        "book.fill", "book.closed", "graduationcap.fill", "pencil", "highlighter",
        "briefcase.fill", "display", "keyboard", "laptopcomputer", "printer.fill",
        "figure.run", "figure.walk", "dumbbell.fill", "sportscourt", "figure.pool.swim",
        "tram.fill", "car.fill", "bicycle", "airplane", "bus",
        "gamecontroller.fill", "music.note", "headphones", "film.fill", "tv",
        "person.fill", "person.2.fill", "house.fill", "bed.double.fill", "shower.fill",
        "cart.fill", "creditcard.fill", "dollarsign.circle.fill", "bag.fill", "gift.fill",
        "cross.case.fill", "pills.fill", "stethoscope", "brain.head.profile", "lungs.fill",
    ]

    private var filtered: [String] {
        if search.isEmpty { return Self.allSymbols }
        let query = search.lowercased()
        return Self.allSymbols.filter { $0.lowercased().contains(query) }
    }

    private let columns = [GridItem(.adaptive(minimum: 64), spacing: 12)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(filtered, id: \.self) { symbol in
                    SymbolCell(symbol: symbol, isSelected: selected == symbol) {
                        selected = symbol
                        dismiss()
                    }
                }
            }
            .padding()
        }
        .searchable(text: $search, prompt: "検索")
        .navigationTitle("アイコン選択")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SymbolCell: View {
    let symbol: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title2)
                .frame(width: 56, height: 56)
                .background(background)
                .overlay(border)
                .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(symbol)
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(isSelected ? Color.accentColor.opacity(0.2) : Color(.secondarySystemBackground))
    }

    private var border: some View {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
    }
}
