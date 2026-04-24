# DailyLog 実装計画

行動記録と食事記録を日常的にキャプチャする iOS アプリ。

## 目的

- 数タップで今やっている行動の開始/停止を記録する
- 食事は写真 + 店舗情報付きで残す
- 日単位/週単位の振り返りを素早くできる
- iCloud 同期 + ローカルのエクスポート/復元で端末変更に耐える

## 技術スタック

| 領域 | 採用 |
|---|---|
| 言語 | Swift 5.9+ |
| UI | SwiftUI |
| 永続化 | SwiftData (+ CloudKit `.automatic` オプション切替) |
| チャート | Swift Charts (`SectorMark`, `RectangleMark`, `BarMark`) |
| 音声入力 | SFSpeechRecognizer + AVAudioEngine |
| ウィジェット | WidgetKit (Static + ActivityKit Live) |
| Live Activity | ActivityKit (Lock / Dynamic Island) |
| 写真 | PhotosUI `PhotosPicker` + `UIImagePickerController` |
| ZIP | エクスポート側 `NSFileCoordinator(.forUploading)`、インポート側 [ZIPFoundation](https://github.com/weichsel/ZIPFoundation) |
| 通知 | UserNotifications (ローカル) |
| 背景処理 | BGTaskScheduler (バックアップ、将来追加予定) |
| プロジェクト生成 | [xcodegen](https://github.com/yonaskolb/XcodeGen) |
| Lint / Format | SwiftLint + SwiftFormat |
| CI | GitHub Actions (macos-latest, DerivedData cache) |

## 画面構成

```
MainTabView
├── ホーム (HomeView)
│   ├── InProgressCard (進行中 + mic + 食事アイコン + 停止)
│   └── TemplateGrid (ルートテンプレ, 長押しで ChildTemplateSheet)
├── カレンダー (CalendarView / UICalendarView wrapper)
│   └── DayDetailView (記録一覧 + 円グラフ)
├── 統計 (StatsView)
│   ├── WeekChartView (24h × 7曜日 RectangleMark)
│   └── PeriodStatsView (週/月切替, BarMark, 食事サマリー)
└── 設定 (SettingsView)
    ├── iCloud 同期トグル
    ├── 通知マスタートグル
    ├── デフォルトテンプレ再追加
    ├── エクスポート
    ├── インポート / 復元
    ├── iCloud Drive バックアップ
    └── バージョン表示
```

## モデル

- **ActivityTemplate**: 名前 / アイコン / カラー / sortOrder / reminderMinutes / isMealType / parent / children
- **Activity**: startAt / endAt / note / voiceNoteFilename / voiceTranscript / template / meal
- **Meal**: photoFilenames[] / shopName / shopAddress / note / activity
- **AppSettings**: iCloudSyncEnabled / defaultReminderMinutes (主にエクスポート往復用, 動作切替は `AppPreferences` UserDefaults 経由)

## サービス

- **ActivityService** - start/stop + 通知 + ウィジェット snapshot + Live Activity 連携
- **TemplateService** - create/reorder/delete, 自動 sortOrder
- **ActivityNotifier / LocalNotificationNotifier** - 忘れアラート
- **LiveActivityController** - ActivityKit 開始/終了
- **SpeechRecognitionService** - 音声メモ
- **PhotoStorage** - App Group 下の写真保存
- **ExportService / ImportService / BackupService** - データ往復

## 識別子

| 種別 | 値 |
|---|---|
| App Bundle ID | `com.coco.daily-log` |
| Widget Bundle ID | `com.coco.daily-log.widget` |
| Tests Bundle ID | `com.coco.daily-log.tests` |
| App Group | `group.com.coco.daily-log` |
| iCloud Container | `iCloud.com.coco.daily-log` |

## 進捗 (2026-04-25 時点)

全 priority:high + priority:medium + priority:low の実装を完了。残件:

- `#13` Core ML による食事検出 (`future` ラベル、保留)
- `#24` Apple Developer Portal 手動設定 (`needs:human`)
- BGAppRefreshTask による自動 iCloud バックアップ (#22 のフォローアップ)

## 開発フロー

`CLAUDE.md` を参照。1 issue → 1 feature branch → PR → CI 緑 → squash merge。
