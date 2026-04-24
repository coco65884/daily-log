import SwiftUI

struct TemplateGrid: View {
    let templates: [ActivityTemplate]
    let onTap: (ActivityTemplate) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 88), spacing: 12),
    ]

    var body: some View {
        if templates.isEmpty {
            emptyState
        } else {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(templates) { template in
                    TemplateButton(template: template) {
                        onTap(template)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.grid.2x2")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("テンプレートがありません")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}
