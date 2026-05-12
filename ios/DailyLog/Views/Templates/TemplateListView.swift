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
                    row(for: template)
                }
                .onMove(perform: move)
                .onDelete(perform: delete)
            }
            .navigationTitle("アクション")
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
                    .accessibilityLabel("親アクションを追加")
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .navigationDestination(for: ActivityTemplate.self) { parent in
                ChildTemplateListView(parent: parent)
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

    private func row(for template: ActivityTemplate) -> some View {
        HStack(spacing: 8) {
            Button {
                editing = template
            } label: {
                TemplateRow(template: template)
            }
            .buttonStyle(.plain)

            if !template.children.isEmpty {
                hiddenToggle(for: template)
                NavigationLink(value: template) {
                    Image(systemName: "chevron.right")
                        .imageScale(.small)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(template.name) の子アクション一覧")
            }
        }
    }

    private func hiddenToggle(for template: ActivityTemplate) -> some View {
        Toggle(isOn: hiddenBinding(for: template)) {
            Text("非表示")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .toggleStyle(.switch)
        .controlSize(.mini)
        .labelsHidden()
        .accessibilityLabel("\(template.name) をホームから非表示")
    }

    private func hiddenBinding(for template: ActivityTemplate) -> Binding<Bool> {
        Binding(
            get: { template.isHidden },
            set: { newValue in
                template.isHidden = newValue
                do {
                    try service.save()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        )
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
