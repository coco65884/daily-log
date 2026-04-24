#!/usr/bin/env swift
// 使い方: swift tools/generate_app_icon.swift
// 出力先: ios/DailyLog/Assets.xcassets/AppIcon.appiconset/icon-1024.png
//
// 水色グラデ + 白い角丸ページ 3 枚を少しずつ傾けて重ねたスタック。
// 最前面にメモの横線を 3 本入れて「ログ/ジャーナル」感を出す。

import AppKit
import CoreGraphics
import Foundation

// MARK: - Canvas (exact 1024×1024 pixels)

let sizeInt = 1024
let size = CGFloat(sizeInt)
let center = CGPoint(x: size / 2, y: size / 2)

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: sizeInt,
    pixelsHigh: sizeInt,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bitmapFormat: [],
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fputs("NSBitmapImageRep init failed\n", stderr)
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
guard let graphicsContext = NSGraphicsContext(bitmapImageRep: rep) else {
    fputs("NSGraphicsContext init failed\n", stderr)
    exit(1)
}
NSGraphicsContext.current = graphicsContext
let ctx = graphicsContext.cgContext

// MARK: - Background (light blue gradient)

let topColor = NSColor(red: 125 / 255, green: 211 / 255, blue: 252 / 255, alpha: 1.0) // sky-300
let bottomColor = NSColor(red: 56 / 255, green: 189 / 255, blue: 248 / 255, alpha: 1.0) // sky-400
let colorSpace = CGColorSpaceCreateDeviceRGB()
let gradient = CGGradient(
    colorsSpace: colorSpace,
    colors: [topColor.cgColor, bottomColor.cgColor] as CFArray,
    locations: [0.0, 1.0]
)!
ctx.drawLinearGradient(
    gradient,
    start: CGPoint(x: 0, y: size),
    end: CGPoint(x: size, y: 0),
    options: []
)

// MARK: - Page stack

struct PageLayer {
    let rotationDegrees: CGFloat
    let fill: CGColor
    let showLines: Bool
}

// sky-100 / sky-50 / white で奥のページほどわずかに青みを帯びさせて段差を可視化。
let backColor = NSColor(red: 224 / 255, green: 242 / 255, blue: 254 / 255, alpha: 1.0).cgColor
let middleColor = NSColor(red: 240 / 255, green: 249 / 255, blue: 255 / 255, alpha: 1.0).cgColor
let frontColor = NSColor.white.cgColor

let layers: [PageLayer] = [
    PageLayer(rotationDegrees: 10, fill: backColor, showLines: false),
    PageLayer(rotationDegrees: -5, fill: middleColor, showLines: false),
    PageLayer(rotationDegrees: 0, fill: frontColor, showLines: true),
]

let pageWidth = size * 0.58
let pageHeight = size * 0.70
let cornerRadius = size * 0.05

for layer in layers {
    ctx.saveGState()
    ctx.translateBy(x: center.x, y: center.y)
    ctx.rotate(by: layer.rotationDegrees * .pi / 180)

    let rect = CGRect(
        x: -pageWidth / 2,
        y: -pageHeight / 2,
        width: pageWidth,
        height: pageHeight
    )
    let path = CGPath(
        roundedRect: rect,
        cornerWidth: cornerRadius,
        cornerHeight: cornerRadius,
        transform: nil
    )
    ctx.addPath(path)
    ctx.setFillColor(layer.fill)
    ctx.fillPath()

    if layer.showLines {
        // 3 本の短い水色線。上から下に並べてメモを暗示。
        ctx.setStrokeColor(
            NSColor(red: 125 / 255, green: 211 / 255, blue: 252 / 255, alpha: 1.0).cgColor
        )
        ctx.setLineWidth(size * 0.025)
        ctx.setLineCap(.round)

        // 行の長さバリエーションで「記入済みのメモ」感
        let lineWidths: [CGFloat] = [pageWidth * 0.58, pageWidth * 0.66, pageWidth * 0.42]
        // ページ中央に 3 本を等間隔で配置
        let lineSpacing = size * 0.09
        let verticalSpan = lineSpacing * CGFloat(lineWidths.count - 1)
        let topY = verticalSpan / 2
        let leftX = -pageWidth * 0.33

        for (index, width) in lineWidths.enumerated() {
            let yPos = topY - CGFloat(index) * lineSpacing
            ctx.move(to: CGPoint(x: leftX, y: yPos))
            ctx.addLine(to: CGPoint(x: leftX + width, y: yPos))
            ctx.strokePath()
        }
    }

    ctx.restoreGState()
}

NSGraphicsContext.restoreGraphicsState()

// MARK: - Export

guard let png = rep.representation(using: .png, properties: [:]) else {
    fputs("PNG encoding failed\n", stderr)
    exit(1)
}

let outputPath = "ios/DailyLog/Assets.xcassets/AppIcon.appiconset/icon-1024.png"
do {
    try png.write(to: URL(fileURLWithPath: outputPath))
    print("Wrote \(outputPath) (\(png.count) bytes, \(sizeInt)×\(sizeInt))")
} catch {
    fputs("Write failed: \(error)\n", stderr)
    exit(1)
}
