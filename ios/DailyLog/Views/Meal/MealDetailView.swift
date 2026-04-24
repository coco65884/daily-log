import PhotosUI
import SwiftData
import SwiftUI

struct MealDetailView: View {
    let activity: Activity

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var shopName: String = ""
    @State private var shopAddress: String = ""
    @State private var note: String = ""
    @State private var photoFilenames: [String] = []
    @State private var photoSelection: [PhotosPickerItem] = []
    @State private var isPresentingCamera = false
    @State private var isPresentingSourceDialog = false
    @State private var errorMessage: String?

    private let storage: PhotoStorage? = PhotoStorage.makeDefault()

    var body: some View {
        NavigationStack {
            Form {
                photosSection
                shopSection
                noteSection
            }
            .navigationTitle("食事の記録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                }
            }
            .confirmationDialog("写真を追加", isPresented: $isPresentingSourceDialog) {
                if CameraPicker.isCameraAvailable {
                    Button("カメラで撮影") { isPresentingCamera = true }
                }
                photosPickerButton
            }
            .fullScreenCover(isPresented: $isPresentingCamera) {
                CameraPicker { image in
                    handlePickedImage(image)
                }
            }
            .onChange(of: photoSelection) { _, new in
                Task { await handlePhotosPickerSelection(new) }
            }
            .onAppear(perform: loadFromActivity)
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

    // MARK: - Sections

    private var photosSection: some View {
        Section("写真") {
            if photoFilenames.isEmpty {
                Text("まだ写真がありません")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if let storage {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(photoFilenames, id: \.self) { filename in
                            MealPhotoThumbnail(
                                filename: filename,
                                storage: storage,
                                onDelete: { removePhoto(filename: filename) }
                            )
                        }
                    }
                }
            }

            Button {
                isPresentingSourceDialog = true
            } label: {
                Label("写真を追加", systemImage: "plus")
            }
        }
    }

    private var shopSection: some View {
        Section("店舗 (任意)") {
            TextField("店舗名", text: $shopName)
            TextField("住所", text: $shopAddress)
        }
    }

    private var noteSection: some View {
        Section("メモ (任意)") {
            TextField("内容・感想など", text: $note, axis: .vertical)
                .lineLimit(3 ... 6)
        }
    }

    private var photosPickerButton: some View {
        PhotosPicker(
            selection: $photoSelection,
            maxSelectionCount: 4,
            matching: .images
        ) {
            Text("ライブラリから選択")
        }
    }

    // MARK: - Actions

    private func loadFromActivity() {
        let meal = activity.ensureMeal(in: modelContext)
        shopName = meal.shopName ?? ""
        shopAddress = meal.shopAddress ?? ""
        note = meal.note
        photoFilenames = meal.photoFilenames
    }

    private func handlePickedImage(_ image: UIImage) {
        guard let storage else {
            errorMessage = "App Group の写真保存領域が使えません (エンタイトルメントを確認してください)"
            return
        }
        do {
            let filename = try storage.save(image)
            photoFilenames.append(filename)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handlePhotosPickerSelection(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        defer { photoSelection = [] }
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            guard let image = UIImage(data: data) else { continue }
            handlePickedImage(image)
        }
    }

    private func removePhoto(filename: String) {
        photoFilenames.removeAll { $0 == filename }
        try? storage?.delete(filename: filename)
    }

    private func save() {
        let meal = activity.ensureMeal(in: modelContext)
        meal.shopName = shopName.isEmpty ? nil : shopName
        meal.shopAddress = shopAddress.isEmpty ? nil : shopAddress
        meal.note = note
        meal.photoFilenames = photoFilenames
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
