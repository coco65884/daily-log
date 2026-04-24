# 写真選択とファイル入出力

## 1. PhotosPicker (iOS 16+ SwiftUI ネイティブ)

ライブラリから選択する UI。複数枚、動画フィルタ、`.images` / `.videos` フィルタ対応。

```swift
@State private var selection: [PhotosPickerItem] = []

PhotosPicker(selection: $selection, maxSelectionCount: 4, matching: .images) {
    Text("ライブラリから選択")
}
.onChange(of: selection) { _, items in
    Task {
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                save(image)
            }
        }
    }
}
```

- `loadTransferable` は非同期で、HEIC を JPEG に変換しながら読める
- 選択後に `selection` を空配列に戻さないと、同じ画像再選択が `onChange` を発火しない

## 2. カメラ撮影 (UIImagePickerController)

SwiftUI にネイティブ代替が無いので `UIViewControllerRepresentable` で包む。

```swift
struct CameraPicker: UIViewControllerRepresentable {
    let onPicked: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onPicked: onPicked, dismiss: { dismiss() })
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        // didFinishPickingMediaWithInfo, imagePickerControllerDidCancel
    }

    static var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }
}
```

simulator はカメラ無しなので `.fullScreenCover` に出すときは `isCameraAvailable` で制御。

## 3. App Group ファイル領域

本アプリは食事写真をウィジェットからも参照できるよう、App Group コンテナに保存。

```swift
guard let container = FileManager.default.containerURL(
    forSecurityApplicationGroupIdentifier: "group.com.coco.daily-log"
) else { return nil }
let photosDir = container.appendingPathComponent("Photos", isDirectory: true)
```

- エンタイトルメントで `com.apple.security.application-groups` を設定済みでないと nil
- シミュレータは `/Users/.../Containers/Shared/AppGroup/.../Photos/*.jpg` の実パスに解決される

## 4. iCloud Drive (ubiquity container)

ユーザーが Files アプリから見える領域。

```swift
guard let iCloud = FileManager.default.url(
    forUbiquityContainerIdentifier: "iCloud.com.coco.daily-log"
) else { return nil }
let backups = iCloud.appendingPathComponent("Documents/Backups")
```

- 「iCloud にサインイン + iCloud Drive ON」の端末でのみ non-nil
- `Documents/` 配下が Files アプリのアプリフォルダーに相当
- 書き込み後、iCloud 同期は OS 任せ (ネット接続と省電力ポリシー次第で遅延)

## 5. ファイル選択 / 保存

### 選択

`.fileImporter(isPresented: allowedContentTypes:)` で Files アプリから選ばせる。

```swift
.fileImporter(
    isPresented: $isPresentingImporter,
    allowedContentTypes: [.zip],
    allowsMultipleSelection: false
) { result in
    handleImportSelection(result)
}
```

- `startAccessingSecurityScopedResource()` を忘れると iCloud Drive / iOS の他アプリディレクトリを読めない
- 選んだ URL はすぐアクセスが切れる場合があるので、temp にコピーしてから処理

### 保存

`UIActivityViewController` を SwiftUI に持ち込む:

```swift
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
```

ZIP の URL を渡せば Files アプリ / AirDrop / メール等で保存できる。

## 6. ZIP 操作

- **作成**: `NSFileCoordinator.coordinate(readingItemAt:options: [.forUploading])` のクロージャで一時 ZIP URL が渡される。ディレクトリ指定すると zip 圧縮、ファイル指定すると安定コピー
- **展開**: iOS SDK に無いため [ZIPFoundation](https://github.com/weichsel/ZIPFoundation) SPM を追加。`FileManager.default.unzipItem(at:to:)` 拡張が提供される

```swift
try FileManager.default.unzipItem(at: zipURL, to: destination)
```

## 注意

- 写真は HEIC で保存されがち。JPEG 化しないと他アプリで開けない端末もある → `UIImage.jpegData(compressionQuality:)`
- App Group / iCloud のパスはどちらもエンタイトルメント未設定だと `nil` になる。UI は「利用不可」プロンプトを用意
- `contentsOfDirectory` が返す URL は順不同。ソートはクライアント側で行う
