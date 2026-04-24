# ツールチェーン (xcodegen / SwiftLint / SwiftFormat / GitHub Actions)

本プロジェクトは macOS + Xcode 26.4 前提、Swift 5.9。ビルド・CI のセットアップを低コストに保つために 4 つのツールを組み合わせている。

## 1. xcodegen

`.xcodeproj` は **追跡しない** 。`ios/project.yml` から `xcodegen generate` で再生成する方針。

利点:
- マージコンフリクトが起きない
- 追加ファイル/ターゲットの設定が YAML で diff できる
- 個人の `xcuserdata/*` が混入しない

基本形:
```yaml
name: DailyLog
options:
  bundleIdPrefix: com.coco
  deploymentTarget:
    iOS: "17.0"
packages:
  ZIPFoundation:
    url: https://github.com/weichsel/ZIPFoundation
    from: 0.9.19
targets:
  DailyLog:
    type: application
    platform: iOS
    sources:
      - path: DailyLog
      - path: Shared
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.coco.daily-log
        GENERATE_INFOPLIST_FILE: YES
        INFOPLIST_KEY_NSSupportsLiveActivities: YES
        CODE_SIGN_ENTITLEMENTS: DailyLog/DailyLog.entitlements
    dependencies:
      - target: DailyLogWidget
      - package: ZIPFoundation
```

- `GENERATE_INFOPLIST_FILE: YES` + `INFOPLIST_KEY_*` で Info.plist の単純なキーを注入
- `NSExtension` のような nested dict は手書きの Info.plist + `GENERATE_INFOPLIST_FILE: NO` に切り替える必要がある (本アプリでは Widget 側がこれ)
- `Shared` を app と widget 両方の `sources` に入れるとコード共有できる

## 2. SwiftLint

`.swiftlint.yml` で設定。重要な opt-in:

```yaml
opt_in_rules:
  - sorted_imports
  - force_unwrapping
  - explicit_init
  - first_where
  - redundant_nil_coalescing

identifier_name:
  min_length: 2

trailing_comma:
  mandatory_comma: true     # SwiftFormat の trailingCommas と合わせる
```

- `force_unwrapping` は `!` を強制エラーにする。代わりに `guard let ... else` / `throw` に倒すと堅くなる
- `sorted_imports` は `import SwiftUI` の前後順を強制。`@testable import Foo` と `import Bar` の扱いは SwiftFormat の `--importgrouping` と揃える必要がある (本アプリは `alphabetized`)

## 3. SwiftFormat

`.swiftformat` に配置:

```
--swiftversion 5.9
--indent 4
--maxwidth 120
--wraparguments before-first
--wrapparameters before-first
--wrapcollections before-first
--self remove
--importgrouping alphabetized
```

- `trailingCommas` ルール (SwiftFormat 0.61+) は **デフォルトで trailing comma を require** する。SwiftLint の `trailing_comma: mandatory_comma: true` と噛み合わせておく
- `wrapPropertyBodies` ルール (0.61+) は `var id: String { rawValue }` のようなワンライナープロパティを multi-line に拡張する。local 0.60 と CI 0.62 で挙動が食い違うと CI だけ落ちるので、たまに `swiftformat --lint` を走らせて揃える

## 4. GitHub Actions CI

`.github/workflows/ci.yml`:

- `macos-latest` ランナー
- 2 ジョブを並列: `Lint / Format` と `Build & Test`
- DerivedData を `actions/cache@v4` で `hashFiles('ios/project.yml', 'ios/**/*.swift')` をキーに保存。同一ブランチの 2 回目以降の push で incremental コンパイルが効く
- `xcodebuild test` 一本で build → test を回す。build + test の 2 step は compile 重複で遅いので一本化
- `-skipMacroValidation` / `-skipPackagePluginValidation` で interactive prompt を回避
- `COMPILER_INDEX_STORE_ENABLE=NO` で IDE 用 index を作らず短縮

実測:
- 初回 (cache miss): 5-12 min
- 同一 commit rerun (cache hit): 3-4 min

## 5. ローカルコマンド

```bash
make -C ios generate      # project.yml から .xcodeproj 再生成
make -C ios build         # iPhone シミュレータ向け Debug
make -C ios test          # XCTest 実行
make -C ios lint          # SwiftLint strict
make -C ios format-check  # SwiftFormat dry-run
make -C ios format        # SwiftFormat 適用
make -C ios clean         # derived data 等削除
```

## 6. よくある詰まり所

- **`xcode-select` が Command Line Tools を指している** → `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`
- **`gh push` が OAuth workflow scope で拒否** → `gh auth refresh -s workflow`
- **DateComponents に `isLeapMonth` が付く/付かない** の SDK 差で Set 等値判定が崩れる → 比較は `year/month/day` の triple のみで行う
- **macOS runner 上の `Calendar.current` が UTC** → テスト用 Calendar は `TimeZone(identifier: "Asia/Tokyo")` を明示し、関数内で `calendar.timeZone = .current` のような上書きをしない (TASK-14 で踏んだ)
- **public repo にすると macOS runner が無料になる** → private の場合は分数課金、billing 要注意
