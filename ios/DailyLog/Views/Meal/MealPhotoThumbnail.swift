import SwiftUI

struct MealPhotoThumbnail: View {
    let filename: String
    let storage: PhotoStorage
    let onDelete: () -> Void

    @State private var image: UIImage?

    private let side: CGFloat = 90

    var body: some View {
        ZStack(alignment: .topTrailing) {
            photoArea

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.white, .black.opacity(0.6))
            }
            .padding(4)
            .accessibilityLabel("写真を削除")
        }
        .frame(width: side, height: side)
        .task {
            image = storage.loadImage(filename: filename)
        }
    }

    @ViewBuilder
    private var photoArea: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: side, height: side)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    ProgressView()
                )
                .frame(width: side, height: side)
        }
    }
}
