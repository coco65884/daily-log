import SwiftData
import SwiftUI

struct TemplateListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(
        filter: #Predicate<ActivityTemplate> { $0.parent == nil },
        sort: \ActivityTemplate.sortOrder
    )
    private var rootTemplates: [ActivityTemplate]

    @State private var editing: ActivityTemplate?
    @State private var isPresentingNew = false
    @State private var errorMessage: String?

    private var service: TemplateService {
        TemplateService(context: modelContext)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(rootTemplates) { template in
                    Button {
                        editing = template
                    } label: {
                        TemplateRow(template: template)
                    }
                    .buttonStyle(.plain)
                }
                .onMove(perform: move)
                .onDelete(perform: delete)
            }
            .navigationTitle("テンプレート")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresentingNew = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .sheet(item: $editing) { template in
                TemplateEditView(existing: template)
            }
            .sheet(isPresented: $isPresentingNew) {
                TemplateEditView(existing: nil)
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
    }

    private func move(from source: IndexSet, to destination: Int) {
        do {
            try service.reorder(siblings: rootTemplates, from: source, to: destination)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            do {
                try service.delete(rootTemplates[index])
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
