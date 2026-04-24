# SwiftData

Apple が iOS 17 で導入した宣言的な永続化フレームワーク。Core Data の後継だが `@Model` マクロで Swift クラスをそのまま永続化できる。本アプリでは CloudKit 同期とも組み合わせている。

## 本アプリでの使い方

### モデル定義 (`@Model`)

```swift
@Model
final class Activity {
    var id: UUID = UUID()
    var startAt: Date = Date()
    var endAt: Date?
    var note: String = ""
    var template: ActivityTemplate?

    @Relationship(deleteRule: .cascade, inverse: \Meal.activity)
    var meal: Meal?
}
```

- `@Model` で自動的に `PersistentModel` 適合とストレージ属性が付与される
- `@Relationship(deleteRule:inverse:)` で一方の側に書けば逆辺は推論される
- **CloudKit 互換**: すべての stored property にデフォルト値があること、`@Attribute(.unique)` を使わないこと

### ModelContainer の構成

```swift
let configuration = ModelConfiguration(
    schema: schema,
    isStoredInMemoryOnly: inMemory,
    cloudKitDatabase: AppPreferences.iCloudSyncEnabled ? .automatic : .none
)
let container = try ModelContainer(for: schema, configurations: configuration)
```

- `.automatic`: エンタイトルメントの iCloud コンテナを使う
- `.none`: ローカルのみ (テストでは `isStoredInMemoryOnly: true` と組合せ)

アプリのトップで:

```swift
WindowGroup { MainTabView() }
    .modelContainer(modelContainer)
```

### 取得 (`@Query`)

View 側で宣言的に取得。変更は自動で再レンダリング。

```swift
@Query(
    filter: #Predicate<Activity> { $0.endAt == nil },
    sort: \Activity.startAt,
    order: .reverse
)
private var inProgressActivities: [Activity]
```

- `#Predicate` は型安全、クローズしか受け付けない制限がある (外部変数キャプチャに注意)
- `@Query` は View の再計算に連動する

### 明示的な操作 (`ModelContext`)

サービス層では `ModelContext` を直接使う。

```swift
@MainActor
struct ActivityService {
    let context: ModelContext

    func start(template: ActivityTemplate) throws {
        let activity = Activity(template: template, startAt: Date())
        context.insert(activity)
        try context.save()
    }

    func fetchInProgress() throws -> [Activity] {
        let descriptor = FetchDescriptor<Activity>(
            predicate: #Predicate { $0.endAt == nil },
            sortBy: [SortDescriptor(\.startAt)]
        )
        return try context.fetch(descriptor)
    }
}
```

- `save()` を忘れると永続化されない
- `SortDescriptor` / `FetchDescriptor` は Foundation の API と同じ形

### テスト

`isStoredInMemoryOnly: true` の `ModelContainer` を `setUpWithError` で作る。CloudKit はテストでは `.none` 固定。

```swift
override func setUpWithError() throws {
    container = try AppModelContainer.makeContainer(inMemory: true)
    service = ActivityService(context: container.mainContext, notifier: MockNotifier())
}
```

## ハマり所

- **`@Attribute(.unique)` は CloudKit と併用不可**: schema 作成時にエラー。UUID を自前で振るしかない
- **nil 比較 `#Predicate`**: `#Predicate { $0.endAt == nil }` は OK、`$0.endAt != capturedVar` のような外部参照は不可
- **スレッド**: SwiftData モデルは Main Actor 前提。バックグラウンド Task からアクセスすると警告/クラッシュ
- **`@Model` クラスは Sendable ではない**: 別アクターに渡すときは ID 等の値型を抜き出してから渡す
- **マイグレーション**: `.unique` 不使用 + 全プロパティ default 値なら、ほとんどの追加はマイグレーションなしで済む

## 参考

- [Apple Docs: SwiftData](https://developer.apple.com/documentation/swiftdata)
- [WWDC23 Meet SwiftData](https://developer.apple.com/videos/play/wwdc2023/10187/)
