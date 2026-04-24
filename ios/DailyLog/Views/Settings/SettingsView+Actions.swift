import Foundation
import SwiftUI

extension SettingsView {
    func export() {
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

    func cleanupExportArchive() {
        if let archive = exportArchive {
            try? FileManager.default.removeItem(at: archive.url)
            exportArchive = nil
        }
    }

    func handleImportSelection(_ result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            guard let url = urls.first else { return }
            let needsScopeAccess = url.startAccessingSecurityScopedResource()
            defer {
                if needsScopeAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            let copy = FileManager.default.temporaryDirectory
                .appendingPathComponent("import-\(UUID().uuidString).zip")
            do {
                if FileManager.default.fileExists(atPath: copy.path) {
                    try FileManager.default.removeItem(at: copy)
                }
                try FileManager.default.copyItem(at: url, to: copy)
                pendingImportURL = copy
            } catch {
                importMessage = error.localizedDescription
            }
        case let .failure(error):
            importMessage = error.localizedDescription
        }
    }

    func performImport(url: URL, mode: ImportService.Mode) {
        defer {
            try? FileManager.default.removeItem(at: url)
            pendingImportURL = nil
        }
        let service = ImportService(context: modelContext)
        do {
            let result = try service.importArchive(at: url, mode: mode)
            importMessage = [
                "復元しました:",
                "テンプレ \(result.templatesImported) / 行動 \(result.activitiesImported)",
                "食事 \(result.mealsImported) / 写真 \(result.photosRestored)",
                "反映にはアプリの再起動を推奨します。",
            ].joined(separator: "\n")
        } catch {
            importMessage = error.localizedDescription
        }
    }

    func runManualBackup() {
        guard let target = BackupService.iCloudBackupsDirectory() else {
            backupMessage = "iCloud Drive が利用できません。iCloud にサインインして iCloud Drive を有効にしてください。"
            return
        }
        isRunningBackup = true
        let service = BackupService(
            exporter: ExportService(context: modelContext),
            targetDirectory: target
        )
        do {
            let url = try service.performBackup()
            backupMessage = "バックアップしました: \(url.lastPathComponent)"
        } catch {
            backupMessage = error.localizedDescription
        }
        isRunningBackup = false
    }

    func reseedTemplates() {
        do {
            try AppModelContainer.reseedDefaultTemplates(in: modelContext)
            reseedMessage = "デフォルトテンプレートを追加しました (既存の同名テンプレはそのまま)"
        } catch {
            reseedMessage = error.localizedDescription
        }
    }
}
