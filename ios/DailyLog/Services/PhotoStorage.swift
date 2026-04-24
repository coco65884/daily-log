import Foundation
import UIKit

/// 食事写真などを App Group 共有コンテナに保存する。
///
/// 本体アプリと `DailyLogWidget` で同じ領域を参照できる。
struct PhotoStorage {
    static let appGroupIdentifier = "group.com.coco.daily-log"

    let rootURL: URL

    /// App Group コンテナの Photos ディレクトリを使う本番用インスタンス。
    /// 取得できない場合 (エンタイトルメント不備など) は `nil`。
    static func makeDefault() -> PhotoStorage? {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            return nil
        }
        return PhotoStorage(rootURL: container.appendingPathComponent("Photos", isDirectory: true))
    }

    /// JPEG バイト列を保存し、生成したファイル名を返す。
    func saveJPEG(_ data: Data) throws -> String {
        try FileManager.default.createDirectory(
            at: rootURL,
            withIntermediateDirectories: true
        )
        let filename = "\(UUID().uuidString).jpg"
        let url = rootURL.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return filename
    }

    /// UIImage を JPEG 圧縮 (80%) して保存する。
    func save(_ image: UIImage) throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw PhotoStorageError.encodingFailed
        }
        return try saveJPEG(data)
    }

    func url(for filename: String) -> URL {
        rootURL.appendingPathComponent(filename)
    }

    func loadData(filename: String) -> Data? {
        try? Data(contentsOf: url(for: filename))
    }

    func loadImage(filename: String) -> UIImage? {
        guard let data = loadData(filename: filename) else { return nil }
        return UIImage(data: data)
    }

    func delete(filename: String) throws {
        let target = url(for: filename)
        if FileManager.default.fileExists(atPath: target.path) {
            try FileManager.default.removeItem(at: target)
        }
    }

    enum PhotoStorageError: Error {
        case encodingFailed
    }
}
