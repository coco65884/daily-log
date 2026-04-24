#!/usr/bin/env swift
// 使い方: swift tools/generate_app_icon.swift
// 出力先: ios/DailyLog/Assets.xcassets/AppIcon.appiconset/icon-1024.png
//
// 水色のグラデ背景 + 白の時計モチーフ (アプリが行動時間記録なので時計で統一)。
// ベースカラーはユーザー指定の「水色と白」。

import AppKit
import CoreGraphics
import Foundation

// MARK: - Output image (exact 1024x1024 pixels, no HiDPI scaling)

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

// MARK: - Clock face

let white = NSColor.white.cgColor
let radius = size * 0.32
let strokeWidth = size * 0.045

// outer ring
ctx.setStrokeColor(white)
ctx.setLineWidth(strokeWidth)
ctx.strokeEllipse(in: CGRect(
    x: center.x - radius,
    y: center.y - radius,
    width: radius * 2,
    height: radius * 2
))

// hour tick marks at 12 / 3 / 6 / 9
let tickLen = size * 0.035
let tickThickness = size * 0.025
ctx.setLineCap(.round)
for quarter in 0 ..< 4 {
    let angle = CGFloat.pi / 2 * CGFloat(quarter) - CGFloat.pi / 2
    let outer = CGPoint(
        x: center.x + cos(angle) * radius,
        y: center.y + sin(angle) * radius
    )
    let inner = CGPoint(
        x: center.x + cos(angle) * (radius - tickLen),
        y: center.y + sin(angle) * (radius - tickLen)
    )
    ctx.setStrokeColor(white)
    ctx.setLineWidth(tickThickness)
    ctx.move(to: outer)
    ctx.addLine(to: inner)
    ctx.strokePath()
}

// MARK: - Clock hands

// NSBitmapImageRep の座標系は Y が上 (Cocoa 標準) なので
// 12 時方向は sin が正になる `π/2 - 2π·(h/12)` で表現する。
// hour hand pointing to 10
let hourAngle = CGFloat.pi / 2 - CGFloat.pi * 2 * (10.0 / 12.0)
let hourLen = radius * 0.52
ctx.setStrokeColor(white)
ctx.setLineWidth(size * 0.05)
ctx.setLineCap(.round)
ctx.move(to: center)
ctx.addLine(to: CGPoint(
    x: center.x + cos(hourAngle) * hourLen,
    y: center.y + sin(hourAngle) * hourLen
))
ctx.strokePath()

// minute hand pointing to 2
let minuteAngle = CGFloat.pi / 2 - CGFloat.pi * 2 * (2.0 / 12.0)
let minuteLen = radius * 0.78
ctx.setStrokeColor(white)
ctx.setLineWidth(size * 0.045)
ctx.move(to: center)
ctx.addLine(to: CGPoint(
    x: center.x + cos(minuteAngle) * minuteLen,
    y: center.y + sin(minuteAngle) * minuteLen
))
ctx.strokePath()

// center pivot
ctx.setFillColor(white)
let pivot = size * 0.025
ctx.fillEllipse(in: CGRect(
    x: center.x - pivot,
    y: center.y - pivot,
    width: pivot * 2,
    height: pivot * 2
))

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
