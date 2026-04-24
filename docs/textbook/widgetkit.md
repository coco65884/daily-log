# WidgetKit + ActivityKit

ホーム画面ウィジェットとロック画面/Dynamic Island の両方を、同じ `DailyLogWidget` app-extension ターゲットで提供している。

## 1. ウィジェットバンドル

```swift
@main
struct DailyLogWidgetBundle: WidgetBundle {
    var body: some Widget {
        DailyLogWidget()           // ホーム画面ウィジェット
        DailyLogLiveActivity()     // Live Activity
    }
}
```

Info.plist に `NSExtensionPointIdentifier = com.apple.widgetkit-extension` が要る。xcodegen の `INFOPLIST_KEY_*` では nested dict を注入できないため手書きの Info.plist (`ios/DailyLogWidget/Info.plist`) を置いている。

## 2. ホーム画面ウィジェット (`StaticConfiguration`)

```swift
struct DailyLogWidget: Widget {
    let kind: String = "DailyLogWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DailyLogTimelineProvider()) { entry in
            DailyLogWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    entry.backgroundColor
                }
        }
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
```

- `containerBackground(for: .widget)` は iOS 17 以降の必須 API (無いとウィジェットが描画されない)
- Small / Medium サイズだけサポート (Lockscreen 用の `.accessory*` は現在無い)

### TimelineProvider

本アプリはアプリ側で App Group UserDefaults に `CurrentActivitySnapshot` を書き込み、ウィジェットがそれを読む単純モデル。

```swift
struct DailyLogTimelineProvider: TimelineProvider {
    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyLogEntry>) -> Void) {
        let entry = DailyLogEntry(date: Date(), snapshot: CurrentActivitySnapshot.load())
        let refresh = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }
}
```

経過時間は `Text(startAt, style: .timer)` に任せているのでエントリを増やす必要がない。15 分毎の refresh は省電力のため。

アプリ側で `WidgetCenter.shared.reloadAllTimelines()` を呼ぶと次回 timeline 取得で最新スナップショットが反映される。

## 3. App Group データ共有

- `project.yml` の `Shared` ディレクトリを両ターゲットの `sources` に追加してシンプルなコード共有
- `UserDefaults(suiteName: "group.com.coco.daily-log")` に JSON エンコードした `Codable` を置く
- SwiftData ストアをウィジェットに共有する方法もあるが、コンテナ初期化コストが重いのでスナップショット方式を選択

## 4. Live Activity (`ActivityConfiguration`)

`ActivityAttributes` を `Shared/DailyLogActivityAttributes.swift` に定義し、アプリと widget が同じ型を使う。

```swift
struct DailyLogActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let startAt: Date
    }
    let templateName: String
    let iconName: String
    let colorHex: String
    let isMealType: Bool
}
```

- 不変属性 (テンプレ情報) は attributes 側、時刻のみ state 側
- 経過時間は Live Activity でも `Text(startAt, style: .timer)` で自動更新されるので state を push 更新する必要がない

### 画面

```swift
ActivityConfiguration(for: DailyLogActivityAttributes.self) { context in
    LockScreenView(context: context)           // ロック画面
} dynamicIsland: { context in
    DynamicIsland {
        DynamicIslandExpandedRegion(.leading) { ... }
        DynamicIslandExpandedRegion(.trailing) { ... }
        DynamicIslandExpandedRegion(.bottom) { ... }
    } compactLeading: { icon }
      compactTrailing: { timer }
      minimal: { icon }
      .keylineTint(...)
}
```

## 5. アプリ側の起動/停止

```swift
@MainActor
struct LiveActivityController {
    func start(template: ActivityTemplate, startAt: Date) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = DailyLogActivityAttributes(...)
        let content = ActivityContent(
            state: DailyLogActivityAttributes.ContentState(startAt: startAt),
            staleDate: nil
        )
        _ = try? ActivityKit.Activity<DailyLogActivityAttributes>.request(
            attributes: attributes,
            content: content,
            pushType: nil
        )
    }

    func endAll() async {
        for activity in ActivityKit.Activity<DailyLogActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
```

- SwiftData の `Activity` と `ActivityKit.Activity` が同名なのでフルパス参照
- `NSSupportsLiveActivities = YES` が Info.plist に必要 (xcodegen の `INFOPLIST_KEY_NSSupportsLiveActivities: YES` で注入)
- Push 未使用なので Push Notifications capability は不要

## 注意

- WidgetKit はプロセスがアプリと別。共有は App Group か (ファイル/UserDefaults) か CloudKit 経由のみ
- シミュレータでも一応動くが、Live Activity は iPhone 14 Pro 相当 (Dynamic Island) のシミュレータで確認した方が早い
- `containerBackground` を忘れるとウィジェットが真っ白または非表示になる
- Timeline エントリを大量に突っ込むとバッテリー/cpu budget に跳ね返る。静的スナップショット + `Text(style: .timer)` が推奨
