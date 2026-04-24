import Foundation
import SwiftData

@Model
final class Meal {
    var id: UUID = UUID()
    var photoFilenames: [String] = []
    var shopName: String?
    var shopAddress: String?
    var note: String = ""
    var createdAt: Date = Date()

    var activity: Activity?

    init(
        id: UUID = UUID(),
        activity: Activity? = nil,
        photoFilenames: [String] = [],
        shopName: String? = nil,
        shopAddress: String? = nil,
        note: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.activity = activity
        self.photoFilenames = photoFilenames
        self.shopName = shopName
        self.shopAddress = shopAddress
        self.note = note
        self.createdAt = createdAt
    }
}
