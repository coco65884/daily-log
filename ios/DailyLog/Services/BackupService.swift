import Foundation
import SwiftData

/// エクスポート ZIP を iCloud Drive (ubiquity container の Documents) にコピーし、
/// 古いバックアップを世代管理する。
@MainActor
struct BackupService {
    private let exporter: ExportService
    private let targetDirectory: URL
    private let maxRetained: Int

    init(exporter: ExportService, targetDirectory: URL, maxRetained: Int = 7) {
        self.exporter = exporter
        self.targetDirectory = targetDirectory
        self.maxRetained = maxRetained
    }

    /// 今すぐバックアップを作る。戻り値は保存先 URL。
    @discardableResult
    func performBackup() throws -> URL {
        try FileManager.default.createDirectory(
            at: targetDirectory,
            withIntermediateDirectories: true
        )
        let archive = try exporter.makeArchive()
        let destination = targetDirectory.appendingPathComponent(archive.lastPathComponent)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: archive, to: destination)
        try pruneOldBackups()
        return destination
    }

    /// 保存済みバックアップの一覧 (新しい順)。
    func listBackups() throws -> [URL] {
        guard FileManager.default.fileExists(atPath: targetDirectory.path) else { return [] }
        let files = try FileManager.default.contentsOfDirectory(
            at: targetDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        )
        return files
            .filter { $0.pathExtension == "zip" && $0.lastPathComponent.hasPrefix("DailyLog-") }
            .sorted { lhs, rhs in
                let lhsDate = (try? lhs.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                let rhsDate = (try? rhs.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                return lhsDate > rhsDate
            }
    }

    private func pruneOldBackups() throws {
        let backups = try listBackups()
        guard backups.count > maxRetained else { return }
        for url in backups.dropFirst(maxRetained) {
            try FileManager.default.removeItem(at: url)
        }
    }

    /// iCloud Drive 上の DailyLog/Documents/Backups フォルダ。ユーザーが iCloud に
    /// サインインしていない場合は nil。
    static func iCloudBackupsDirectory() -> URL? {
        guard let container = FileManager.default.url(
            forUbiquityContainerIdentifier: AppGroupConfig.iCloudContainerIdentifier
        ) else {
            return nil
        }
        return container
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent("Backups", isDirectory: true)
    }
}
