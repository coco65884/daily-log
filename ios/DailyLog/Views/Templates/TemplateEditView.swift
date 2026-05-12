import SwiftData
import SwiftUI

struct TemplateEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let existing: ActivityTemplate?
    let defaultParent: ActivityTemplate?

    init(existing: ActivityTemplate?, defaultParent: ActivityTemplate? = nil) {
        self.existing = existing
        self.defaultParent = defaultParent
    }

    @Query(sort: \ActivityTemplate.sortOrder)
    private var allTemplates: [ActivityTemplate]

    @State private var name: String = ""
    @State private var iconName: String = "circle"
    @State private var colorHex: String = "#4A90E2"
    @State private var parentID: UUID?
    @State private var hasReminder: Bool = false
    @State private var reminderMinutes: Int = 30
    @State private var isMealType: Bool = false
    @State private var errorMessage: String?

    private var service: TemplateService {
        TemplateService(context: modelContext)
    }

    private var parentCandidates: [ActivityTemplate] {
        guard let existing else { return allTemplates.filter { $0.parent == nil } }
        let forbidden = Set([existing.id] + existing.children.map(\.id))
        return allTemplates.filter { !forbidden.contains($0.id) }
    }

    private var isSaveDisabled: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本") {
                    TextField("名前", text: $name)

                    NavigationLink {
                        SymbolPickerView(selected: $iconName)
                    } label: {
                        HStack {
                            Text("アイコン")
                            Spacer()
                            Image(systemName: iconName)
                                .foregroundStyle(.secondary)
                        }
                    }

                    ColorPaletteView(selected: $colorHex)
                }

                Section("分類") {
                    Picker("親アクション", selection: $parentID) {
                        Text("なし").tag(nil as UUID?)
                        ForEach(parentCandidates) { template in
                            Text(template.name).tag(template.id as UUID?)
                        }
                    }

                    Toggle("食事タイプ", isOn: $isMealType)
                }

                Section("リマインダー") {
                    Toggle("忘れアラートを使う", isOn: $hasReminder)
                    if hasReminder {
                        Stepper("\(reminderMinutes) 分後", value: $reminderMinutes, in: 5 ... 240, step: 5)
                    }
                }
            }
            .navigationTitle(existing == nil ? "新規アクション" : "アクション編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .disabled(isSaveDisabled)
                }
            }
            .onAppear(perform: loadInitialState)
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

    private func loadInitialState() {
        if let existing {
            name = existing.name
            iconName = existing.iconName
            colorHex = existing.colorHex
            parentID = existing.parent?.id
            if let minutes = existing.reminderMinutes {
                hasReminder = true
                reminderMinutes = minutes
            } else {
                hasReminder = false
                reminderMinutes = 30
            }
            isMealType = existing.isMealType
        } else if let defaultParent {
            parentID = defaultParent.id
            colorHex = defaultParent.colorHex
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveReminder: Int? = hasReminder ? reminderMinutes : nil
        let parent = parentID.flatMap { id in allTemplates.first(where: { $0.id == id }) }

        do {
            if let existing {
                existing.name = trimmedName
                existing.iconName = iconName
                existing.colorHex = colorHex
                existing.parent = parent
                existing.reminderMinutes = effectiveReminder
                existing.isMealType = isMealType
                try service.save()
            } else {
                try service.create(
                    name: trimmedName,
                    iconName: iconName,
                    colorHex: colorHex,
                    reminderMinutes: effectiveReminder,
                    isMealType: isMealType,
                    parent: parent
                )
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
