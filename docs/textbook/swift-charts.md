# Swift Charts

Apple が iOS 16 で導入したネイティブチャート。SwiftUI の ResultBuilder で Chart を書く。本アプリでは `SectorMark` (円グラフ) / `RectangleMark` (週 24h) / `BarMark` (カテゴリ別) を使用。

## 1. `SectorMark` - 日別円グラフ

```swift
Chart {
    ForEach(slices) { slice in
        SectorMark(
            angle: .value("時間", slice.totalSeconds),
            innerRadius: .ratio(0.55),
            angularInset: 1
        )
        .foregroundStyle(Color(hex: slice.colorHex) ?? .accentColor)
        .cornerRadius(4)
    }
}
.chartLegend(.hidden)
```

- `innerRadius: .ratio(0.55)` でドーナツ化
- `angularInset` でセクター間にスペース
- `.chartLegend(.hidden)` して自前の凡例ビューを用意するとタップでハイライトなどカスタムしやすい

## 2. `RectangleMark` - 週 24h グリッド

```swift
Chart {
    ForEach(spans) { span in
        RectangleMark(
            xStart: .value("start-day", Double(span.weekdayIndex) - 0.4),
            xEnd: .value("end-day", Double(span.weekdayIndex) + 0.4),
            yStart: .value("start-hour", span.startHours),
            yEnd: .value("end-hour", span.endHours)
        )
        .foregroundStyle(Color(hex: span.colorHex) ?? .accentColor)
    }
}
.chartXScale(domain: -0.5...6.5)
.chartYScale(domain: 0.0...24.0)
.chartXAxis {
    AxisMarks(values: Array(0..<7).map(Double.init)) { value in
        AxisValueLabel { weekdayLabel(for: value) }
    }
}
```

- `xStart/xEnd` + `yStart/yEnd` で矩形の 4 頂点を指定
- X 軸に曜日、Y 軸に時間帯 (0-24) の割付が直感的
- 曜日ラベルを自前で `@ViewBuilder` に出さないとコンパイラが落ちる (SwiftUI の複雑度爆発回避)

## 3. `BarMark` - 横棒ランキング

```swift
Chart {
    ForEach(categories) { category in
        BarMark(
            x: .value("時間", category.totalSeconds / 3600),
            y: .value("カテゴリ", category.templateName)
        )
        .foregroundStyle(Color(hex: category.colorHex) ?? .accentColor)
        .annotation(position: .trailing, alignment: .leading) {
            Text(DurationFormatter.elapsed(seconds: Int(category.totalSeconds)))
                .font(.caption2)
        }
    }
}
.chartYAxis { AxisMarks(position: .leading) }
```

- `annotation` でバーの端に値ラベルを重ねる
- カテゴリ軸を y 側にすると「ランキング」らしく縦に並ぶ

## 4. 軸のカスタム

```swift
.chartYAxis {
    AxisMarks(values: [0.0, 6.0, 12.0, 18.0, 24.0]) { value in
        AxisGridLine()
        AxisTick()
        AxisValueLabel {
            if let hour = value.as(Double.self) {
                Text(String(format: "%02d:00", Int(hour)))
            }
        }
    }
}
```

- `values:` に固定配列で指定すると好きな目盛を出せる
- `.automatic` と違って決め打ちの罫線と値が出るので読みやすい

## 5. `chartPlotStyle`

チャートの背景を調整したいときに。

```swift
.chartPlotStyle { plot in
    plot.background(RoundedRectangle(cornerRadius: 8).fill(Color(.secondarySystemBackground)))
}
```

## 注意

- `LineMark` など時系列チャートでは `.value("x", date)` を Date で渡すと自動で Date 軸になる
- X/Y に Double 値を渡すときは `-chartXScale(domain:)` を必ず書いておくと意図通りに収まる
- アクセシビリティ向けに `.accessibilityLabel(_:)` を各 Mark に付けるとスクリーンリーダー対応
