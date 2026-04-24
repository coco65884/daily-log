import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext

    @AppStorage(AppPreferences.Keys.iCloudSyncEnabled) private var iCloudSyncEnabled = false
    @AppStorage(AppPreferences.Keys.notificationsEnabled) private var notificationsEnabled = true

    @State private var reseedConfirmation = false
    @State private var reseedMessage: String?
    @State private var isExporting = false
    @State private var exportArchive: ExportArchive?
    @State private var exportErrorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                syncSection
                notificationSection
                templatesSection
                dataSection
                aboutSection
            }
            .navigationTitle("設定")
            .alert(
                "メッセージ",
                isPresented: Binding(
                    get: { reseedMessage != nil },
                    set: { if !$0 { reseedMessage = nil } }
                ),
                presenting: reseedMessage
            ) { _ in
                Button("OK", role: .cancel) { reseedMessage = nil }
            } message: { message in
                Text(message)
            }
            .confirmationDialog(
                "デフォルトテンプレートを再追加しますか？",
                isPresented: $reseedConfirmation,
                titleVisibility: .visible
            ) {
                Button("追加", role: .destructive) { reseedTemplates() }
                Button("キャンセル", role: .cancel) {}
            }
            .sheet(item: $exportArchive, onDismiss: cleanupExportArchive) { archive in
                ShareSheet(items: [archive.url])
            }
            .alert(
                "エクスポートに失敗しました",
                isPresented: Binding(
                    get: { exportErrorMessage != nil },
                    set: { if !$0 { exportErrorMessage = nil } }
                ),
                presenting: exportErrorMessage
            ) { _ in
                Button("OK", role: .cancel) { exportErrorMessage = nil }
            } message: { message in
                Text(message)
            }
        }
    }

    private func export() {
        isExporting = true
        do {
            let service = ExportService(context: modelContext)
            let url = try service.makeArchive()
            exportArchive = ExportArchive(url: url)
        } catch {
            exportErrorMessage = error.localizedDescription
        }
        isExporting = false
    }

    private func cleanupExportArchive() {
        if let archive = exportArchive {
            try? FileManager.default.removeItem(at: archive.url)
            exportArchive = nil
        }
    }

    private var syncSection: some View {
        Section("同期") {
            Toggle("iCloud 同期", isOn: $iCloudSyncEnabled)
            if iCloudSyncEnabled {
                Text("有効化の反映にはアプリの再起動が必要です。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var notificationSection: some View {
        Section("通知") {
            Toggle("忘れアラート", isOn: $notificationsEnabled)
            Text("テンプレごとの分数設定は「テンプレート管理」で行えます。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var templatesSection: some View {
        Section("テンプレート") {
            Button {
                reseedConfirmation = true
            } label: {
                Label("デフォルトテンプレートを再追加", systemImage: "arrow.clockwise")
            }
        }
    }

    private var dataSection: some View {
        Section("データ") {
            Button {
                export()
            } label: {
                HStack {
                    Label("エクスポート", systemImage: "square.and.arrow.up")
                    if isExporting {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(isExporting)

            LabeledContent("インポート", value: "Issue #23 で実装")
                .foregroundStyle(.secondary)
            LabeledContent("iCloud Drive 自動バックアップ", value: "Issue #22 で実装")
                .foregroundStyle(.secondary)
        }
    }

    private var aboutSection: some View {
        Section("このアプリ") {
            LabeledContent("バージョン", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-")
            LabeledContent("ビルド", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-")
        }
    }

    private func reseedTemplates() {
        do {
            try AppModelContainer.reseedDefaultTemplates(in: modelContext)
            reseedMessage = "デフォルトテンプレートを追加しました (既存の同名テンプレはそのまま)"
        } catch {
            reseedMessage = error.localizedDescription
        }
    }
}
