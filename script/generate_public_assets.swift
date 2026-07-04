#!/usr/bin/env swift
import AppKit
import Foundation

let canvasSize = NSSize(width: 1280, height: 640)
let blueCeramicFixturePath = "docs/design/app-rendered-signal-console/blue-ceramic-live.png"
let darkFixturePath = "docs/design/app-rendered-signal-console/signal-dark-live.png"
let heroOutputPath = "docs/assets/codex-gauge-github-hero.png"
let menuBarPath = "docs/assets/codex-gauge-menubar-live.png"
let consoleOutputPath = "docs/assets/codex-gauge-signal-console.png"
let socialOutputPath = "docs/assets/codex-gauge-social-preview.png"
let provenanceText = "actual app-rendered Signal Console"
let menuBarSize = NSSize(width: 430, height: 96)

func canvasRect(_ rect: NSRect) -> NSRect {
    NSRect(x: rect.minX, y: canvasSize.height - rect.maxY, width: rect.width, height: rect.height)
}

func roundedPath(_ rect: NSRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: canvasRect(rect), xRadius: radius, yRadius: radius)
}

func fillCanvas(_ color: NSColor) {
    color.setFill()
    NSRect(origin: .zero, size: canvasSize).fill()
}

func drawRoundedRect(_ rect: NSRect, radius: CGFloat, fill: NSColor, stroke: NSColor? = nil, lineWidth: CGFloat = 1) {
    let path = roundedPath(rect, radius: radius)
    fill.setFill()
    path.fill()
    if let stroke {
        stroke.setStroke()
        path.lineWidth = lineWidth
        path.stroke()
    }
}

func drawText(
    _ value: String,
    in rect: NSRect,
    size: CGFloat,
    weight: NSFont.Weight,
    color: NSColor,
    alignment: NSTextAlignment = .left,
    mono: Bool = false
) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment
    paragraph.lineBreakMode = .byWordWrapping
    let font = mono
        ? NSFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
        : NSFont.systemFont(ofSize: size, weight: weight)
    NSAttributedString(
        string: value,
        attributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ]
    ).draw(in: canvasRect(rect))
}

func drawPill(_ value: String, rect: NSRect, fill: NSColor, stroke: NSColor, text: NSColor, dot: NSColor? = nil) {
    drawRoundedRect(rect, radius: rect.height / 2, fill: fill, stroke: stroke)
    if let dot {
        dot.setFill()
        NSBezierPath(ovalIn: canvasRect(NSRect(x: rect.minX + 14, y: rect.minY + rect.height / 2 - 4, width: 8, height: 8))).fill()
        drawText(value, in: NSRect(x: rect.minX + 30, y: rect.minY + 8, width: rect.width - 42, height: 16), size: 12, weight: .semibold, color: text)
    } else {
        drawText(value, in: NSRect(x: rect.minX + 16, y: rect.minY + 8, width: rect.width - 32, height: 16), size: 12, weight: .semibold, color: text, alignment: .center)
    }
}

func drawImage(_ image: NSImage, in rect: NSRect, fraction: CGFloat = 1) {
    image.draw(
        in: canvasRect(rect),
        from: NSRect(origin: .zero, size: image.size),
        operation: .sourceOver,
        fraction: fraction,
        respectFlipped: false,
        hints: [.interpolation: NSImageInterpolation.high.rawValue]
    )
}

func loadImage(_ path: String) -> NSImage {
    guard let image = NSImage(contentsOfFile: path) else {
        fatalError("Missing image: \(path)")
    }
    return image
}

func writePNG(_ path: String, drawing: () -> Void) throws {
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(canvasSize.width),
        pixelsHigh: Int(canvasSize.height),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    drawing()
    NSGraphicsContext.restoreGraphicsState()

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Could not encode \(path)")
    }
    let url = URL(fileURLWithPath: path)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: url)
    print("Wrote \(path)")
}

func menuBarText(_ value: String, at point: NSPoint, size: CGFloat, weight: NSFont.Weight, color: NSColor, mono: Bool = false) {
    let font = mono
        ? NSFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
        : NSFont.systemFont(ofSize: size, weight: weight)
    (value as NSString).draw(
        at: point,
        withAttributes: [
            .font: font,
            .foregroundColor: color,
        ]
    )
}

func drawMenuBarHorizontalQuotaBar(value: CGFloat, rect: NSRect, fill: NSColor, track: NSColor, stroke: NSColor) {
    _ = stroke
    let shell = NSBezierPath(roundedRect: rect, xRadius: 1.0, yRadius: 1.0)
    track.setFill()
    shell.fill()
    let fillInset: CGFloat = 1.0
    let innerRect = rect.insetBy(dx: fillInset, dy: fillInset)

    let fraction = max(0, min(1, value))
    guard fraction > 0 else {
        return
    }

    let fillRect = NSRect(
        x: innerRect.minX,
        y: innerRect.minY,
        width: min(innerRect.width, max(4.4, innerRect.width * fraction)),
        height: innerRect.height
    )
    NSGraphicsContext.saveGraphicsState()
    shell.addClip()
    fill.setFill()
    fillRect.fill()
    NSGraphicsContext.restoreGraphicsState()
}

func drawMenuBarCountdownText(_ value: String, rect: NSRect, fill: NSColor, stroke: NSColor, text: NSColor) {
    menuBarText(value, at: NSPoint(x: rect.minX + 2, y: rect.minY + 5), size: value.count > 3 ? 14 : 16, weight: .bold, color: text, mono: true)
}

func drawMenuBarRefreshCountdown(in rect: NSRect, ink: NSColor, fill: NSColor, stroke: NSColor) {
    drawMenuBarCountdownText("4h59m", rect: NSRect(x: rect.minX + 6, y: rect.midY + 4, width: 80, height: 22), fill: fill, stroke: stroke, text: ink)
    drawMenuBarCountdownText("6d23h", rect: NSRect(x: rect.minX + 6, y: rect.midY - 26, width: 80, height: 22), fill: fill, stroke: stroke, text: ink)
}

func writeMenuBarPNG(_ path: String) throws {
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(menuBarSize.width),
        pixelsHigh: Int(menuBarSize.height),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

    let ink = NSColor(calibratedRed: 0.22, green: 0.26, blue: 0.25, alpha: 0.98)
    let line = NSColor.clear
    let systemMonitorBlue = NSColor(deviceRed: 134.0 / 255.0, green: 150.0 / 255.0, blue: 185.0 / 255.0, alpha: 1.0)
    let meterTrack = NSColor(deviceWhite: 0.08, alpha: 0.95)
    let taupe = NSColor(calibratedRed: 0.52, green: 0.48, blue: 0.42, alpha: 0.96)

    NSGradient(colors: [
        NSColor(calibratedRed: 0.69, green: 0.77, blue: 0.78, alpha: 1.0),
        NSColor(calibratedRed: 0.55, green: 0.65, blue: 0.68, alpha: 1.0),
    ])?.draw(in: NSBezierPath(rect: NSRect(origin: .zero, size: menuBarSize)), angle: 0)

    let strip = NSRect(x: 64, y: 20, width: 252, height: 56)

    menuBarText("5h", at: NSPoint(x: strip.minX + 12, y: 48), size: 24, weight: .bold, color: ink, mono: true)
    menuBarText("7d", at: NSPoint(x: strip.minX + 12, y: 24), size: 24, weight: .bold, color: ink, mono: true)
    menuBarText("90%", at: NSPoint(x: strip.minX + 48, y: 49), size: 17, weight: .bold, color: ink, mono: true)
    menuBarText("80%", at: NSPoint(x: strip.minX + 48, y: 25), size: 17, weight: .bold, color: ink, mono: true)
    drawMenuBarHorizontalQuotaBar(value: 0.90, rect: NSRect(x: strip.minX + 112, y: 56, width: 46, height: 8), fill: systemMonitorBlue, track: meterTrack, stroke: line)
    drawMenuBarHorizontalQuotaBar(value: 0.80, rect: NSRect(x: strip.minX + 112, y: 32, width: 46, height: 8), fill: systemMonitorBlue, track: meterTrack, stroke: line)

    drawMenuBarRefreshCountdown(
        in: NSRect(x: strip.minX + 172, y: 23, width: 82, height: 50),
        ink: ink,
        fill: taupe.withAlphaComponent(0),
        stroke: taupe.withAlphaComponent(0)
    )

    NSGraphicsContext.restoreGraphicsState()

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Could not encode \(path)")
    }
    let url = URL(fileURLWithPath: path)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: url)
    print("Wrote \(path)")
}

try writeMenuBarPNG(menuBarPath)
let blueCeramicPanel = loadImage(blueCeramicFixturePath)
let darkPanel = loadImage(darkFixturePath)
let menuBar = loadImage(menuBarPath)

try writePNG(heroOutputPath) {
    fillCanvas(NSColor(calibratedRed: 0.90, green: 0.94, blue: 0.92, alpha: 1.0))
    NSGradient(colors: [
        NSColor(calibratedRed: 0.95, green: 0.97, blue: 0.94, alpha: 1.0),
        NSColor(calibratedRed: 0.76, green: 0.84, blue: 0.84, alpha: 1.0),
    ])?.draw(in: NSBezierPath(rect: NSRect(origin: .zero, size: canvasSize)), angle: 10)

    drawRoundedRect(NSRect(x: 0, y: 0, width: 1280, height: 74), radius: 0, fill: NSColor.white.withAlphaComponent(0.46))
    drawText("Codex Gauge", in: NSRect(x: 80, y: 108, width: 480, height: 58), size: 48, weight: .bold, color: NSColor(calibratedRed: 0.10, green: 0.15, blue: 0.15, alpha: 1.0))
    drawText("Codex quota where you actually look: the macOS menu bar.", in: NSRect(x: 82, y: 176, width: 500, height: 72), size: 25, weight: .semibold, color: NSColor(calibratedRed: 0.22, green: 0.30, blue: 0.30, alpha: 0.96))
    drawText("Rendered sample values. The installed app shows your live 5-hour and 7-day usage, with reset countdowns that keep moving.", in: NSRect(x: 84, y: 258, width: 500, height: 86), size: 18, weight: .regular, color: NSColor(calibratedRed: 0.33, green: 0.39, blue: 0.38, alpha: 0.94))

    drawPill("No cookies", rect: NSRect(x: 84, y: 382, width: 122, height: 38), fill: NSColor.white.withAlphaComponent(0.42), stroke: NSColor(calibratedRed: 0.34, green: 0.43, blue: 0.41, alpha: 0.22), text: NSColor(calibratedRed: 0.16, green: 0.22, blue: 0.21, alpha: 1.0))
    drawPill("No auth-file reads", rect: NSRect(x: 222, y: 382, width: 172, height: 38), fill: NSColor.white.withAlphaComponent(0.42), stroke: NSColor(calibratedRed: 0.34, green: 0.43, blue: 0.41, alpha: 0.22), text: NSColor(calibratedRed: 0.16, green: 0.22, blue: 0.21, alpha: 1.0))
    drawPill("local diagnostics", rect: NSRect(x: 410, y: 382, width: 166, height: 38), fill: NSColor(calibratedRed: 0.42, green: 0.54, blue: 0.49, alpha: 0.14), stroke: NSColor(calibratedRed: 0.42, green: 0.54, blue: 0.49, alpha: 0.32), text: NSColor(calibratedRed: 0.14, green: 0.27, blue: 0.22, alpha: 1.0), dot: NSColor(calibratedRed: 0.42, green: 0.54, blue: 0.49, alpha: 1.0))

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
    shadow.shadowBlurRadius = 28
    shadow.shadowOffset = NSSize(width: 0, height: -12)
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    drawRoundedRect(NSRect(x: 642, y: 116, width: 548, height: 340), radius: 30, fill: NSColor.black.withAlphaComponent(0.12))
    NSGraphicsContext.restoreGraphicsState()

    drawRoundedRect(NSRect(x: 642, y: 116, width: 548, height: 340), radius: 30, fill: NSColor.white.withAlphaComponent(0.52), stroke: NSColor(calibratedRed: 0.26, green: 0.36, blue: 0.36, alpha: 0.20))
    drawText("menu bar signal", in: NSRect(x: 686, y: 154, width: 220, height: 22), size: 14, weight: .semibold, color: NSColor(calibratedRed: 0.35, green: 0.43, blue: 0.40, alpha: 0.92))
    drawImage(menuBar, in: NSRect(x: 732, y: 178, width: 360, height: 80))
    drawRoundedRect(NSRect(x: 686, y: 294, width: 194, height: 96), radius: 18, fill: NSColor.white.withAlphaComponent(0.46), stroke: NSColor(calibratedRed: 0.26, green: 0.36, blue: 0.36, alpha: 0.15))
    drawText("5h", in: NSRect(x: 710, y: 318, width: 42, height: 24), size: 22, weight: .bold, color: NSColor(calibratedRed: 0.13, green: 0.18, blue: 0.18, alpha: 1.0), mono: true)
    drawText("usage", in: NSRect(x: 710, y: 348, width: 78, height: 18), size: 12, weight: .medium, color: NSColor(calibratedRed: 0.36, green: 0.44, blue: 0.42, alpha: 0.86))
    drawText("90%", in: NSRect(x: 788, y: 318, width: 72, height: 28), size: 24, weight: .bold, color: NSColor(calibratedRed: 0.23, green: 0.32, blue: 0.28, alpha: 1.0), mono: true)
    drawText("4h59m", in: NSRect(x: 788, y: 350, width: 72, height: 18), size: 12, weight: .semibold, color: NSColor(calibratedRed: 0.45, green: 0.41, blue: 0.35, alpha: 0.92), mono: true)

    drawRoundedRect(NSRect(x: 910, y: 294, width: 194, height: 96), radius: 18, fill: NSColor.white.withAlphaComponent(0.46), stroke: NSColor(calibratedRed: 0.26, green: 0.36, blue: 0.36, alpha: 0.15))
    drawText("7d", in: NSRect(x: 934, y: 318, width: 42, height: 24), size: 22, weight: .bold, color: NSColor(calibratedRed: 0.13, green: 0.18, blue: 0.18, alpha: 1.0), mono: true)
    drawText("quota", in: NSRect(x: 934, y: 348, width: 78, height: 18), size: 12, weight: .medium, color: NSColor(calibratedRed: 0.36, green: 0.44, blue: 0.42, alpha: 0.86))
    drawText("80%", in: NSRect(x: 1012, y: 318, width: 72, height: 28), size: 24, weight: .bold, color: NSColor(calibratedRed: 0.24, green: 0.34, blue: 0.38, alpha: 1.0), mono: true)
    drawText("6d23h", in: NSRect(x: 1012, y: 350, width: 72, height: 18), size: 12, weight: .semibold, color: NSColor(calibratedRed: 0.45, green: 0.41, blue: 0.35, alpha: 0.92), mono: true)

    drawText("The menu bar shows Codex quota and reset countdowns; the popover expands those same signals into a focused console.", in: NSRect(x: 686, y: 412, width: 420, height: 58), size: 16, weight: .regular, color: NSColor(calibratedRed: 0.35, green: 0.42, blue: 0.41, alpha: 0.92))
}

try writePNG(consoleOutputPath) {
    fillCanvas(NSColor(calibratedRed: 0.91, green: 0.95, blue: 0.98, alpha: 1.0))
    NSGradient(colors: [
        NSColor(calibratedRed: 0.96, green: 0.985, blue: 1.00, alpha: 1.0),
        NSColor(calibratedRed: 0.84, green: 0.91, blue: 0.96, alpha: 1.0),
    ])?.draw(in: NSBezierPath(rect: NSRect(origin: .zero, size: canvasSize)), angle: 25)

    drawText("Actual app-rendered Signal Console", in: NSRect(x: 72, y: 72, width: 440, height: 92), size: 37, weight: .bold, color: NSColor(calibratedRed: 0.08, green: 0.13, blue: 0.15, alpha: 1.0))
    drawText("Static public screenshot with sample quota values and illustrative reset countdowns. The installed app renders your live Codex values.", in: NSRect(x: 74, y: 176, width: 430, height: 86), size: 18, weight: .regular, color: NSColor(calibratedRed: 0.19, green: 0.28, blue: 0.31, alpha: 0.92))

    drawPill("Live source", rect: NSRect(x: 74, y: 280, width: 132, height: 38), fill: NSColor(calibratedRed: 0.05, green: 0.72, blue: 0.64, alpha: 0.13), stroke: NSColor(calibratedRed: 0.05, green: 0.72, blue: 0.64, alpha: 0.30), text: NSColor(calibratedRed: 0.06, green: 0.22, blue: 0.21, alpha: 1.0), dot: NSColor(calibratedRed: 0.05, green: 0.72, blue: 0.64, alpha: 1.0))
    drawPill("5h + 7d", rect: NSRect(x: 220, y: 280, width: 118, height: 38), fill: NSColor(calibratedRed: 1.00, green: 0.72, blue: 0.25, alpha: 0.15), stroke: NSColor(calibratedRed: 1.00, green: 0.72, blue: 0.25, alpha: 0.34), text: NSColor(calibratedRed: 0.28, green: 0.20, blue: 0.08, alpha: 1.0))
    drawPill("Live summary", rect: NSRect(x: 352, y: 280, width: 144, height: 38), fill: NSColor(calibratedRed: 0.216, green: 0.424, blue: 0.561, alpha: 0.09), stroke: NSColor(calibratedRed: 0.216, green: 0.424, blue: 0.561, alpha: 0.20), text: NSColor(calibratedRed: 0.063, green: 0.137, blue: 0.227, alpha: 1.0))

    drawRoundedRect(NSRect(x: 72, y: 382, width: 468, height: 84), radius: 26, fill: NSColor.white.withAlphaComponent(0.48), stroke: NSColor(calibratedRed: 0.10, green: 0.19, blue: 0.23, alpha: 0.16))
    drawImage(menuBar, in: NSRect(x: 160, y: 398, width: 260, height: 58))
    drawText("Menu bar first. Fuller detail when you click.", in: NSRect(x: 78, y: 490, width: 420, height: 24), size: 16, weight: .medium, color: NSColor(calibratedRed: 0.42, green: 0.50, blue: 0.53, alpha: 0.90))

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
    shadow.shadowBlurRadius = 22
    shadow.shadowOffset = NSSize(width: 0, height: -8)
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    drawRoundedRect(NSRect(x: 604, y: 34, width: 604, height: 604), radius: 30, fill: NSColor.black.withAlphaComponent(0.08))
    NSGraphicsContext.restoreGraphicsState()
    drawImage(blueCeramicPanel, in: NSRect(x: 604, y: 34, width: 604, height: 604))
}

try writePNG(socialOutputPath) {
    fillCanvas(NSColor(calibratedRed: 0.02, green: 0.05, blue: 0.07, alpha: 1.0))
    NSGradient(colors: [
        NSColor(calibratedRed: 0.04, green: 0.12, blue: 0.15, alpha: 1.0),
        NSColor(calibratedRed: 0.01, green: 0.03, blue: 0.06, alpha: 1.0),
    ])?.draw(in: NSBezierPath(rect: NSRect(origin: .zero, size: canvasSize)), angle: 18)

    drawText("Codex Gauge", in: NSRect(x: 74, y: 74, width: 430, height: 58), size: 48, weight: .bold, color: NSColor.white.withAlphaComponent(0.96))
    drawText("Quota visibility for the menu bar", in: NSRect(x: 78, y: 142, width: 460, height: 36), size: 24, weight: .semibold, color: NSColor(calibratedRed: 0.74, green: 0.88, blue: 0.86, alpha: 0.95))
    drawText("5-hour and 7-day usage percentages, live reset countdowns, safe diagnostics, and no browser-cookie reads.", in: NSRect(x: 78, y: 202, width: 450, height: 116), size: 19, weight: .regular, color: NSColor.white.withAlphaComponent(0.72))

    drawPill("No browser cookies", rect: NSRect(x: 78, y: 328, width: 174, height: 40), fill: NSColor.white.withAlphaComponent(0.08), stroke: NSColor.white.withAlphaComponent(0.17), text: NSColor.white.withAlphaComponent(0.88))
    drawPill("No auth-file reads", rect: NSRect(x: 266, y: 328, width: 174, height: 40), fill: NSColor.white.withAlphaComponent(0.08), stroke: NSColor.white.withAlphaComponent(0.17), text: NSColor.white.withAlphaComponent(0.88))
    drawPill("Native menu bar", rect: NSRect(x: 78, y: 382, width: 174, height: 40), fill: NSColor(calibratedRed: 0.05, green: 0.72, blue: 0.64, alpha: 0.14), stroke: NSColor(calibratedRed: 0.05, green: 0.72, blue: 0.64, alpha: 0.34), text: NSColor(calibratedRed: 0.70, green: 1.00, blue: 0.94, alpha: 1.0), dot: NSColor(calibratedRed: 0.05, green: 0.72, blue: 0.64, alpha: 1.0))
    drawPill("sample app data", rect: NSRect(x: 266, y: 382, width: 164, height: 40), fill: NSColor(calibratedRed: 1.00, green: 0.72, blue: 0.25, alpha: 0.13), stroke: NSColor(calibratedRed: 1.00, green: 0.72, blue: 0.25, alpha: 0.28), text: NSColor(calibratedRed: 1.00, green: 0.86, blue: 0.58, alpha: 1.0))

    drawText("Actual app-rendered Signal Console", in: NSRect(x: 80, y: 520, width: 440, height: 24), size: 16, weight: .medium, color: NSColor.white.withAlphaComponent(0.56))

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.38)
    shadow.shadowBlurRadius = 26
    shadow.shadowOffset = NSSize(width: 0, height: -8)
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    drawRoundedRect(NSRect(x: 598, y: 32, width: 586, height: 586), radius: 28, fill: NSColor.black.withAlphaComponent(0.22))
    NSGraphicsContext.restoreGraphicsState()
    drawImage(darkPanel, in: NSRect(x: 598, y: 32, width: 586, height: 586))
}
