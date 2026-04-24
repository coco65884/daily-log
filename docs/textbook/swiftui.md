# SwiftUI パターン集 (本アプリで使ったもの)

## 1. 画面ナビゲーション

- `NavigationStack { ... }` でルートを用意し、`NavigationLink`, `.navigationDestination(for:)`, `.navigationDestination(item:)` で遷移
- シートは `.sheet(isPresented:)` と `.sheet(item:)` を使い分ける。`item:` 版は `Identifiable` を受け取り、nil で自動クローズ
- タブ切替は `TabView { … .tabItem { Label(...) } }`

```swift
TabView {
    HomeView().tabItem { Label("ホーム", systemImage: "clock") }
    CalendarView().tabItem { Label("カレンダー", systemImage: "calendar") }
    StatsView().tabItem { Label("統計", systemImage: "chart.bar") }
    SettingsView().tabItem { Label("設定", systemImage: "gear") }
}
```

## 2. @State と @Environment

- View 内部の短命な状態は `@State`
- ModelContext のようなシステム注入は `@Environment(\.modelContext) private var modelContext`
- `@AppStorage` は `UserDefaults.standard` (or suite) を直接バインドする。同期トグルや軽量設定に

```swift
@AppStorage("pref.iCloudSyncEnabled") private var iCloudSyncEnabled = false
```

## 3. コンパイラが重い body を避ける

SwiftUI ビルダーは型が非常に太くなりやすく、`The compiler is unable to type-check this expression in reasonable time` が出やすい。

対策:

- ネストした条件 (`if ... { ... } else ...`) はサブビューに切り出す
- `Background(alignment:)` + `Overlay(alignment:)` の中で条件分岐する場合は、`@ViewBuilder` プロパティに出す
- `Button(action:) { ... }` を多重ネストする箇所は `{ action } label: { label }` のトレーリングクロージャ 2 つ形式にする

```swift
Button {
    start()
} label: {
    Label("開始", systemImage: "play.fill")
}
```

## 4. 破壊的操作の確認

- `.confirmationDialog(titleVisibility: .visible)` で iOS 風 UI
- `Button(role: .destructive, action:) { Text("削除") }` で色が自動で変わる

## 5. 非同期 `.task`

初回表示時に権限要求などをやりたいときは `.task { await ... }` を使う。cancel は View の life-cycle と連動。

```swift
.task {
    await LocalNotificationNotifier.shared.requestAuthorizationIfNeeded()
}
```

## 6. UIKit ブリッジ (`UIViewRepresentable`)

- `UIImagePickerController` は SwiftUI にネイティブ代替が無い (カメラ撮影用)
- `UICalendarView` も同様

```swift
struct CameraPicker: UIViewControllerRepresentable {
    let onPicked: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController { ... }
    func makeCoordinator() -> Coordinator { ... }
}
```

Coordinator で delegate を実装し、親の closure へ結果を渡す。

## 7. ファイル関連

- `.fileImporter(isPresented:allowedContentTypes:)` - アプリ外の zip / json を選択
- `UIActivityViewController` を `UIViewControllerRepresentable` でくるんだ `ShareSheet` で書き出し
- `startAccessingSecurityScopedResource()` を忘れると Files アプリから拾ったファイルが読めない

## 8. アラート

`.alert(presenting:)` で `String?` optional を渡すとコンテンツに応じて自動で出る:

```swift
.alert(
    "エラー",
    isPresented: Binding(
        get: { errorMessage != nil },
        set: { if !$0 { errorMessage = nil } }
    ),
    presenting: errorMessage
) { _ in
    Button("OK", role: .cancel) {}
} message: { msg in
    Text(msg)
}
```

## 9. タイマー更新

`Text(date, style: .timer)` はシステムがチェック不要で秒更新してくれる。ウィジェットや Live Activity の timer 表示に最適 (timeline を増やさずに済む)。

それ以外は `Timer.publish(every: 1, on: .main, in: .common).autoconnect()` を `.onReceive` で受ける。
