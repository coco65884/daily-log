# daily-log

行動時間と食事を記録する iOS アプリ。

## 技術スタック

- **言語**: Swift 5.9
- **UI**: SwiftUI
- **永続化**: SwiftData + CloudKit (iCloud 同期)
- **ターゲット**: iOS 17.0+
- **プロジェクト生成**: [xcodegen](https://github.com/yonaskolb/XcodeGen) (`ios/project.yml`)
- **Lint/Format**: SwiftLint + SwiftFormat
- **テスト**: XCTest
- **ウィジェット**: WidgetKit (App Group で本体アプリとデータ共有)

## 初回セットアップ

### 必要ツール (Homebrew)

```bash
brew install xcodegen swiftlint swiftformat
```

Xcode 15 以上を App Store からインストール後、

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

### 署名設定 (実機ビルド前)

個人の Apple Developer Team ID は `ios/Signing.local.xcconfig` (gitignored) で管理する。`make generate` で Xcode プロジェクトを再生成しても Team が消えないようにするため。

```bash
cp ios/Signing.local.xcconfig.example ios/Signing.local.xcconfig
# Signing.local.xcconfig を開き DEVELOPMENT_TEAM に自分の Team ID を設定
```

Team ID は Xcode の **TARGETS > Signing & Capabilities > Team** プルダウン、もしくは https://developer.apple.com/account/#/membership で確認できる。

シミュレータ実行のみなら省略可能 (未設定なら ad-hoc 署名で動作する)。

### Xcode プロジェクトの生成

`.xcodeproj` は追跡外なのでクローン直後に生成する。

```bash
make -C ios generate
```

`ios/DailyLog.xcodeproj` が作られるので、そのまま Xcode で開ける。

## よく使うコマンド

```bash
make -C ios generate      # project.yml から .xcodeproj を再生成
make -C ios build         # iPhone シミュレータ向けに Debug ビルド
make -C ios test          # XCTest 実行
make -C ios lint          # SwiftLint strict
make -C ios format-check  # SwiftFormat dry-run
make -C ios format        # SwiftFormat 適用
make -C ios clean         # .xcodeproj / build / DerivedData を削除
```

## ディレクトリ構成

```
ios/
├── project.yml              # xcodegen 定義
├── Makefile                 # ショートカット
├── DailyLog/                # アプリ本体
│   ├── DailyLogApp.swift
│   ├── ContentView.swift
│   ├── DailyLog.entitlements  # App Group + iCloud CloudKit
│   └── Assets.xcassets/
├── DailyLogTests/           # ユニットテスト
└── DailyLogWidget/          # ホーム画面ウィジェット (App Extension)
    ├── DailyLogWidgetBundle.swift
    ├── DailyLogWidget.swift
    ├── DailyLogWidget.entitlements
    └── Info.plist
```

## 識別子

| 種別 | 値 |
|---|---|
| App Bundle ID | `com.coco.daily-log` |
| Widget Bundle ID | `com.coco.daily-log.widget` |
| App Group | `group.com.coco.daily-log` |
| iCloud Container | `iCloud.com.coco.daily-log` |

## 開発フロー

詳細は [CLAUDE.md](./CLAUDE.md) を参照。

1. GitHub Issues でタスクを管理 (`priority:critical` → `priority:high` 順)
2. `feature/<TASK-ID>-<description>` ブランチで 1 issue ずつ実装
3. ローカルで `make -C ios lint && make -C ios format-check && make -C ios test` が通ることを確認
4. PR → CI 緑 → squash merge
