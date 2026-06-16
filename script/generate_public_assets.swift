#!/usr/bin/env swift
import AppKit
import Foundation

let canvasSize = NSSize(width: 1280, height: 640)
let paperFixturePath = "docs/design/app-rendered-signal-console/paper-console-live.png"
let darkFixturePath = "docs/design/app-rendered-signal-console/signal-dark-live.png"
let menuBarPath = "docs/assets/codex-gauge-menubar-live.png"
let consoleOutputPath = "docs/assets/codex-gauge-signal-console.png"
let socialOutputPath = "docs/assets/codex-gauge-social-preview.png"
let provenanceText = "actual app-rendered Signal Console"

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

let paperPanel = loadImage(paperFixturePath)
let darkPanel = loadImage(darkFixturePath)
let menuBar = loadImage(menuBarPath)

try writePNG(consoleOutputPath) {
    fillCanvas(NSColor(calibratedRed: 0.94, green: 0.92, blue: 0.86, alpha: 1.0))
    NSGradient(colors: [
        NSColor(calibratedRed: 0.99, green: 0.98, blue: 0.94, alpha: 1.0),
        NSColor(calibratedRed: 0.89, green: 0.93, blue: 0.88, alpha: 1.0),
    ])?.draw(in: NSBezierPath(rect: NSRect(origin: .zero, size: canvasSize)), angle: 25)

    drawText("Actual app-rendered Signal Console", in: NSRect(x: 72, y: 72, width: 440, height: 92), size: 37, weight: .bold, color: NSColor(calibratedRed: 0.08, green: 0.13, blue: 0.12, alpha: 1.0))
    drawText("The same native view used by the menu bar popover. Public screenshot uses sample quota values, plus sample reset, SSD, CPU, and RAM signals.", in: NSRect(x: 74, y: 176, width: 430, height: 74), size: 18, weight: .regular, color: NSColor(calibratedRed: 0.26, green: 0.32, blue: 0.30, alpha: 0.92))

    drawPill("Live source", rect: NSRect(x: 74, y: 280, width: 132, height: 38), fill: NSColor(calibratedRed: 0.12, green: 0.68, blue: 0.49, alpha: 0.13), stroke: NSColor(calibratedRed: 0.12, green: 0.68, blue: 0.49, alpha: 0.30), text: NSColor(calibratedRed: 0.08, green: 0.24, blue: 0.19, alpha: 1.0), dot: NSColor(calibratedRed: 0.12, green: 0.68, blue: 0.49, alpha: 1.0))
    drawPill("5h + 7d", rect: NSRect(x: 220, y: 280, width: 118, height: 38), fill: NSColor(calibratedRed: 0.95, green: 0.69, blue: 0.30, alpha: 0.15), stroke: NSColor(calibratedRed: 0.95, green: 0.69, blue: 0.30, alpha: 0.34), text: NSColor(calibratedRed: 0.25, green: 0.20, blue: 0.10, alpha: 1.0))
    drawPill("Local report", rect: NSRect(x: 352, y: 280, width: 144, height: 38), fill: NSColor(calibratedRed: 0.12, green: 0.18, blue: 0.16, alpha: 0.08), stroke: NSColor(calibratedRed: 0.12, green: 0.18, blue: 0.16, alpha: 0.18), text: NSColor(calibratedRed: 0.10, green: 0.15, blue: 0.14, alpha: 1.0))

    drawRoundedRect(NSRect(x: 72, y: 382, width: 468, height: 84), radius: 26, fill: NSColor.white.withAlphaComponent(0.48), stroke: NSColor(calibratedRed: 0.13, green: 0.20, blue: 0.18, alpha: 0.16))
    drawImage(menuBar, in: NSRect(x: 92, y: 405, width: 395, height: 48))
    drawText("Menu bar first. Details only when you click.", in: NSRect(x: 78, y: 490, width: 420, height: 24), size: 16, weight: .medium, color: NSColor(calibratedRed: 0.34, green: 0.40, blue: 0.37, alpha: 0.90))

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
    shadow.shadowBlurRadius = 22
    shadow.shadowOffset = NSSize(width: 0, height: -8)
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    drawRoundedRect(NSRect(x: 604, y: 34, width: 604, height: 604), radius: 30, fill: NSColor.black.withAlphaComponent(0.08))
    NSGraphicsContext.restoreGraphicsState()
    drawImage(paperPanel, in: NSRect(x: 604, y: 34, width: 604, height: 604))
}

try writePNG(socialOutputPath) {
    fillCanvas(NSColor(calibratedRed: 0.02, green: 0.05, blue: 0.07, alpha: 1.0))
    NSGradient(colors: [
        NSColor(calibratedRed: 0.04, green: 0.12, blue: 0.15, alpha: 1.0),
        NSColor(calibratedRed: 0.01, green: 0.03, blue: 0.06, alpha: 1.0),
    ])?.draw(in: NSBezierPath(rect: NSRect(origin: .zero, size: canvasSize)), angle: 18)

    drawText("Codex Gauge", in: NSRect(x: 74, y: 74, width: 430, height: 58), size: 48, weight: .bold, color: NSColor.white.withAlphaComponent(0.96))
    drawText("Beautiful local quota visibility for Codex", in: NSRect(x: 78, y: 142, width: 460, height: 36), size: 24, weight: .semibold, color: NSColor(calibratedRed: 0.74, green: 0.88, blue: 0.86, alpha: 0.95))
    drawText("5-hour and 7-day usage, reset countdowns, SSD temperature, CPU/RAM context, safe diagnostics, and local-only reports from the macOS menu bar.", in: NSRect(x: 78, y: 202, width: 450, height: 116), size: 19, weight: .regular, color: NSColor.white.withAlphaComponent(0.72))

    drawPill("No browser cookies", rect: NSRect(x: 78, y: 328, width: 174, height: 40), fill: NSColor.white.withAlphaComponent(0.08), stroke: NSColor.white.withAlphaComponent(0.17), text: NSColor.white.withAlphaComponent(0.88))
    drawPill("No auth-file reads", rect: NSRect(x: 266, y: 328, width: 174, height: 40), fill: NSColor.white.withAlphaComponent(0.08), stroke: NSColor.white.withAlphaComponent(0.17), text: NSColor.white.withAlphaComponent(0.88))
    drawPill("Native menu bar", rect: NSRect(x: 78, y: 382, width: 174, height: 40), fill: NSColor(calibratedRed: 0.31, green: 0.94, blue: 0.68, alpha: 0.14), stroke: NSColor(calibratedRed: 0.31, green: 0.94, blue: 0.68, alpha: 0.34), text: NSColor(calibratedRed: 0.74, green: 1.00, blue: 0.88, alpha: 1.0), dot: NSColor(calibratedRed: 0.31, green: 0.94, blue: 0.68, alpha: 1.0))
    drawPill("sample app data", rect: NSRect(x: 266, y: 382, width: 164, height: 40), fill: NSColor(calibratedRed: 1.00, green: 0.78, blue: 0.35, alpha: 0.13), stroke: NSColor(calibratedRed: 1.00, green: 0.78, blue: 0.35, alpha: 0.28), text: NSColor(calibratedRed: 1.00, green: 0.88, blue: 0.62, alpha: 1.0))

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
