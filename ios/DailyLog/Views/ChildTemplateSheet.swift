import SwiftUI

struct ChildTemplateSheet: View {
    let parent: ActivityTemplate
    let onSelect: (ActivityTemplate) -> Void

    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 88), spacing: 12)]

    private var sortedChildren: [ActivityTemplate] {
        parent.children.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header

                    if sortedChildren.isEmpty {
                        emptyState
                    } else {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(sortedChildren) { child in
                                TemplateButton(template: child) {
                                    onSelect(child)
                                    dismiss()
                                }
                            }
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding()
            }
            .navigationTitle(parent.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("親で開始") {
                        onSelect(parent)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: parent.iconName)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(Color(hex: parent.colorHex) ?? .accentColor)
                )

            VStack(alignment: .leading) {
                Text(parent.name)
                    .font(.headline)
                Text("子テンプレート \(sortedChildren.count) 個")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.grid.2x2")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("子テンプレートはありません")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}
