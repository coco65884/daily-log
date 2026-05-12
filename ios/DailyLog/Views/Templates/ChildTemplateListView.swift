import SwiftData
import SwiftUI

struct ChildTemplateListView: View {
    @Environment(\.modelContext) private var modelContext

    let parent: ActivityTemplate

    @State private var editing: ActivityTemplate?
    @State private var isPresentingNew = false
    @State private var errorMessage: String?

    private var service: TemplateService {
        TemplateService(context: modelContext)
    }

    private var sortedChildren: [ActivityTemplate] {
        parent.children.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        List {
            Section("子アクション") {
                if sortedChildren.isEmpty {
                    Text("子アクションがありません")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sortedChildren) { child in
                        Button {
                            editing = child
                        } label: {
                            TemplateRow(template: child)
                        }
                        .buttonStyle(.plain)
                    }
                    .onMove(perform: move)
                    .onDelete(perform: delete)
                }
            }
        }
        .navigationTitle(parent.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isPresentingNew = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("子アクションを追加")
            }
        }
        .sheet(item: $editing) { template in
            TemplateEditView(existing: template)
        }
        .sheet(isPresented: $isPresentingNew) {
            TemplateEditView(existing: nil, defaultParent: parent)
        }
        .alert(
            "エラー",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            ),
            presenting: errorMessage
        ) { _ in
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { message in
            Text(message)
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        do {
            try service.reorder(siblings: sortedChildren, from: source, to: destination)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete(at offsets: IndexSet) {
        let snapshot = sortedChildren
        for index in offsets {
            do {
                try service.delete(snapshot[index])
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
