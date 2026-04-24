#!/usr/bin/env swift
// 使い方: swift tools/generate_app_icon.swift
// 出力先: ios/DailyLog/Assets.xcassets/AppIcon.appiconset/icon-1024.png
//
// 水色グラデ + 白い角丸ページ 3 枚を重ねたスタック。
// 最前面ページには上部に水色の時計、下部に水色の横線 3 本を配置。
// 「時間を記録するジャーナル」のメタファ。

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
    let drawContent: Bool
}

// sky-100 / sky-50 / white で奥のページほどわずかに青みを帯びさせて段差を可視化。
let backColor = NSColor(red: 224 / 255, green: 242 / 255, blue: 254 / 255, alpha: 1.0).cgColor
let middleColor = NSColor(red: 240 / 255, green: 249 / 255, blue: 255 / 255, alpha: 1.0).cgColor
let frontColor = NSColor.white.cgColor
let accentColor = NSColor(red: 125 / 255, green: 211 / 255, blue: 252 / 255, alpha: 1.0).cgColor // sky-300

let layers: [PageLayer] = [
    PageLayer(rotationDegrees: 10, fill: backColor, drawContent: false),
    PageLayer(rotationDegrees: -5, fill: middleColor, drawContent: false),
    PageLayer(rotationDegrees: 0, fill: frontColor, drawContent: true),
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

    guard layer.drawContent else {
        ctx.restoreGState()
        continue
    }

    // MARK: Front-page content — clock (top) + lines (bottom)
    // ページ座標は canvas center が原点、Cocoa 規約で +y が視覚的な上。

    ctx.setStrokeColor(accentColor)
    ctx.setLineCap(.round)

    // --- Clock (upper area) ---
    let clockCenterY: CGFloat = size * 0.15
    let clockRadius: CGFloat = size * 0.110
    let clockStroke: CGFloat = size * 0.028

    ctx.setLineWidth(clockStroke)
    ctx.strokeEllipse(in: CGRect(
        x: -clockRadius,
        y: clockCenterY - clockRadius,
        width: clockRadius * 2,
        height: clockRadius * 2
    ))

    // 針は NSBitmapImageRep の Y-up 座標系前提の `π/2 - 2π·(h/12)` で表現。
    func drawHand(pointingAt hour: CGFloat, length: CGFloat, width: CGFloat) {
        let angle = CGFloat.pi / 2 - CGFloat.pi * 2 * (hour / 12.0)
        ctx.setLineWidth(width)
        ctx.move(to: CGPoint(x: 0, y: clockCenterY))
        ctx.addLine(to: CGPoint(
            x: cos(angle) * length,
            y: clockCenterY + sin(angle) * length
        ))
        ctx.strokePath()
    }
    drawHand(pointingAt: 10, length: clockRadius * 0.55, width: clockStroke * 1.1)
    drawHand(pointingAt: 2, length: clockRadius * 0.78, width: clockStroke)

    // --- Lines (lower area) ---
    // 先頭 (一番上の線) はページ中央より少し下、以降下向きに 3 本。
    let lineWidths: [CGFloat] = [pageWidth * 0.60, pageWidth * 0.66, pageWidth * 0.45]
    let lineSpacing: CGFloat = size * 0.080
    let topLineY: CGFloat = -size * 0.04
    let leftX: CGFloat = -pageWidth * 0.33

    ctx.setLineWidth(size * 0.033)
    for (index, width) in lineWidths.enumerated() {
        let yPos = topLineY - CGFloat(index) * lineSpacing
        ctx.move(to: CGPoint(x: leftX, y: yPos))
        ctx.addLine(to: CGPoint(x: leftX + width, y: yPos))
        ctx.strokePath()
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
