@testable import DailyLog
import UIKit
import XCTest

final class PhotoStorageTests: XCTestCase {
    private var tempDirectory: URL!
    private var storage: PhotoStorage!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PhotoStorageTests-\(UUID().uuidString)", isDirectory: true)
        storage = PhotoStorage(rootURL: tempDirectory)
    }

    override func tearDownWithError() throws {
        if let url = tempDirectory {
            try? FileManager.default.removeItem(at: url)
        }
        storage = nil
        tempDirectory = nil
        try super.tearDownWithError()
    }

    func testSaveAndLoadJPEG() throws {
        let image = makeSolidImage(color: .red)
        let filename = try storage.save(image)

        XCTAssertTrue(filename.hasSuffix(".jpg"))
        let loaded = try XCTUnwrap(storage.loadImage(filename: filename))
        XCTAssertGreaterThan(loaded.size.width, 0)
        XCTAssertGreaterThan(loaded.size.height, 0)
    }

    func testSaveJPEGData() throws {
        let image = makeSolidImage(color: .blue)
        let data = try XCTUnwrap(image.jpegData(compressionQuality: 0.8))
        let filename = try storage.saveJPEG(data)

        let reloaded = try XCTUnwrap(storage.loadData(filename: filename))
        XCTAssertEqual(reloaded.count, data.count)
    }

    func testDeleteRemovesFile() throws {
        let image = makeSolidImage(color: .green)
        let filename = try storage.save(image)
        XCTAssertNotNil(storage.loadImage(filename: filename))

        try storage.delete(filename: filename)

        XCTAssertNil(storage.loadImage(filename: filename))
    }

    func testDeleteMissingIsNoOp() {
        XCTAssertNoThrow(try storage.delete(filename: "does-not-exist.jpg"))
    }

    private func makeSolidImage(color: UIColor, size: CGSize = CGSize(width: 40, height: 40)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
