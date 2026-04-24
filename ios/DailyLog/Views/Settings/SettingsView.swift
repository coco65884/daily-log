import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) var modelContext

    @AppStorage(AppPreferences.Keys.iCloudSyncEnabled) var iCloudSyncEnabled = false
    @AppStorage(AppPreferences.Keys.notificationsEnabled) var notificationsEnabled = true

    @State var reseedConfirmation = false
    @State var reseedMessage: String?
    @State var isExporting = false
    @State var exportArchive: ExportArchive?
    @State var exportErrorMessage: String?
    @State var backupMessage: String?
    @State var isRunningBackup = false
    @State var isPresentingImporter = false
    @State var pendingImportURL: URL?
    @State var importMessage: String?

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
            .alert(
                "バックアップ",
                isPresented: Binding(
                    get: { backupMessage != nil },
                    set: { if !$0 { backupMessage = nil } }
                ),
                presenting: backupMessage
            ) { _ in
                Button("OK", role: .cancel) { backupMessage = nil }
            } message: { message in
                Text(message)
            }
            .fileImporter(
                isPresented: $isPresentingImporter,
                allowedContentTypes: [.zip],
                allowsMultipleSelection: false
            ) { result in
                handleImportSelection(result)
            }
            .confirmationDialog(
                "復元方法を選んでください",
                isPresented: Binding(
                    get: { pendingImportURL != nil },
                    set: { if !$0 { pendingImportURL = nil } }
                ),
                titleVisibility: .visible,
                presenting: pendingImportURL
            ) { url in
                Button("マージ (既存データ保持)") {
                    performImport(url: url, mode: .merge)
                }
                Button("完全置換", role: .destructive) {
                    performImport(url: url, mode: .replace)
                }
                Button("キャンセル", role: .cancel) {
                    pendingImportURL = nil
                }
            } message: { _ in
                Text("マージは既存データを保ちつつ追加、完全置換は既存を削除してから復元します。復元後はアプリの再起動を推奨します。")
            }
            .alert(
                "インポート",
                isPresented: Binding(
                    get: { importMessage != nil },
                    set: { if !$0 { importMessage = nil } }
                ),
                presenting: importMessage
            ) { _ in
                Button("OK", role: .cancel) { importMessage = nil }
            } message: { message in
                Text(message)
            }
        }
    }

    // アクション実装は SettingsView+Actions.swift にある。

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

            Button {
                isPresentingImporter = true
            } label: {
                Label("インポート / 復元", systemImage: "square.and.arrow.down")
            }

            Button {
                runManualBackup()
            } label: {
                HStack {
                    Label("今すぐ iCloud バックアップ", systemImage: "icloud.and.arrow.up")
                    if isRunningBackup {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(isRunningBackup)
        }
    }

    private var aboutSection: some View {
        Section("このアプリ") {
            LabeledContent("バージョン", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-")
            LabeledContent("ビルド", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-")
        }
    }
}
