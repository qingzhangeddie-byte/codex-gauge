#!/usr/bin/env swift
import AppKit
import Foundation

let canvasSize = NSSize(width: 1280, height: 640)
let blueCeramicFixturePath = "docs/design/app-rendered-signal-console/blue-ceramic-live.png"
let darkFixturePath = "docs/design/app-rendered-signal-console/signal-dark-live.png"
let menuBarPath = "docs/assets/codex-gauge-menubar-live.png"
let consoleOutputPath = "docs/assets/codex-gauge-signal-console.png"
let socialOutputPath = "docs/assets/codex-gauge-social-preview.png"
let provenanceText = "actual app-rendered Signal Console"
let menuBarSize = NSSize(width: 790, height: 96)

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

func drawMenuBarSegmentedRail(value: CGFloat, rect: NSRect, fill: NSColor, track: NSColor) {
    let count = 10
    let gap: CGFloat = 3
    let segmentWidth = (rect.width - gap * CGFloat(count - 1)) / CGFloat(count)
    let filled = Int(ceil(max(0, min(1, value)) * CGFloat(count)))
    for index in 0..<count {
        let segmentRect = NSRect(x: rect.minX + CGFloat(index) * (segmentWidth + gap), y: rect.minY, width: segmentWidth, height: rect.height)
        let segment = NSBezierPath(roundedRect: segmentRect, xRadius: rect.height / 2, yRadius: rect.height / 2)
        (index < filled ? fill : track).setFill()
        segment.fill()
    }
}

func drawMenuBarResetLane(value: CGFloat, rect: NSRect, marker: NSColor, track: NSColor) {
    let lane = NSBezierPath()
    lane.move(to: NSPoint(x: rect.minX, y: rect.midY))
    lane.line(to: NSPoint(x: rect.maxX, y: rect.midY))
    lane.lineWidth = rect.height
    lane.lineCapStyle = .round
    track.setStroke()
    lane.stroke()

    let fillEnd = rect.minX + rect.width * max(0, min(1, value))
    let fill = NSBezierPath()
    fill.move(to: NSPoint(x: rect.minX, y: rect.midY))
    fill.line(to: NSPoint(x: fillEnd, y: rect.midY))
    fill.lineWidth = rect.height
    fill.lineCapStyle = .round
    marker.withAlphaComponent(0.70).setStroke()
    fill.stroke()

    let faceRect = NSRect(x: fillEnd - 7, y: rect.midY - 7, width: 14, height: 14)
    let facePath = NSBezierPath(ovalIn: faceRect)
    marker.setFill()
    facePath.fill()
    marker.withAlphaComponent(0.45).setStroke()
    facePath.lineWidth = 0.8
    facePath.stroke()
}

func drawMenuBarMorandiDivider(_ x: CGFloat, in rect: NSRect, line: NSColor) {
    let shadow = NSBezierPath()
    shadow.move(to: NSPoint(x: x - 0.5, y: rect.minY + 10))
    shadow.line(to: NSPoint(x: x - 0.5, y: rect.maxY - 10))
    shadow.lineWidth = 1
    line.withAlphaComponent(0.42).setStroke()
    shadow.stroke()

    let highlight = NSBezierPath()
    highlight.move(to: NSPoint(x: x + 0.5, y: rect.minY + 10))
    highlight.line(to: NSPoint(x: x + 0.5, y: rect.maxY - 10))
    highlight.lineWidth = 1
    NSColor.white.withAlphaComponent(0.62).setStroke()
    highlight.stroke()
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

    let shellTop = NSColor(calibratedRed: 0.91, green: 0.91, blue: 0.87, alpha: 1.0)
    let shellBottom = NSColor(calibratedRed: 0.82, green: 0.85, blue: 0.80, alpha: 1.0)
    let ink = NSColor(calibratedRed: 0.22, green: 0.26, blue: 0.25, alpha: 0.98)
    let line = NSColor(calibratedRed: 0.52, green: 0.48, blue: 0.42, alpha: 0.62)
    let sage = NSColor(calibratedRed: 0.45, green: 0.56, blue: 0.48, alpha: 0.96)
    let mist = NSColor(calibratedRed: 0.39, green: 0.52, blue: 0.57, alpha: 0.96)
    let clay = NSColor(calibratedRed: 0.63, green: 0.42, blue: 0.39, alpha: 0.96)
    let taupe = NSColor(calibratedRed: 0.52, green: 0.48, blue: 0.42, alpha: 0.96)

    NSGradient(colors: [
        NSColor(calibratedRed: 0.86, green: 0.93, blue: 0.97, alpha: 1.0),
        NSColor(calibratedRed: 0.74, green: 0.86, blue: 0.93, alpha: 1.0),
    ])?.draw(in: NSBezierPath(rect: NSRect(origin: .zero, size: menuBarSize)), angle: 0)

    let strip = NSRect(x: 35, y: 20, width: 720, height: 56)
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.16)
    shadow.shadowBlurRadius = 12
    shadow.shadowOffset = NSSize(width: 0, height: -4)
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    NSBezierPath(roundedRect: strip, xRadius: 12, yRadius: 12).fill()
    NSGraphicsContext.restoreGraphicsState()

    let capsule = NSBezierPath(roundedRect: strip, xRadius: 12, yRadius: 12)
    NSGradient(colors: [shellTop, shellBottom])?.draw(in: capsule, angle: 90)
    sage.withAlphaComponent(0.08).setFill()
    capsule.fill()
    line.setStroke()
    capsule.lineWidth = 1.2
    capsule.stroke()

    let topRail = NSBezierPath(roundedRect: NSRect(x: strip.minX + 28, y: strip.maxY - 7, width: strip.width - 56, height: 2.2), xRadius: 1.1, yRadius: 1.1)
    sage.withAlphaComponent(0.28).setFill()
    topRail.fill()

    for x in [278, 386, 552, 658] as [CGFloat] {
        drawMenuBarMorandiDivider(x, in: strip, line: line)
    }

    menuBarText("5h", at: NSPoint(x: 58, y: 48), size: 24, weight: .bold, color: ink, mono: true)
    menuBarText("7d", at: NSPoint(x: 58, y: 24), size: 24, weight: .bold, color: ink, mono: true)
    drawMenuBarSegmentedRail(value: 0.90, rect: NSRect(x: 132, y: 56, width: 88, height: 8), fill: sage, track: line.withAlphaComponent(0.20))
    drawMenuBarSegmentedRail(value: 0.80, rect: NSRect(x: 132, y: 32, width: 88, height: 8), fill: mist.withAlphaComponent(0.88), track: line.withAlphaComponent(0.20))
    menuBarText("90%", at: NSPoint(x: 236, y: 47), size: 22, weight: .bold, color: ink, mono: true)
    menuBarText("80%", at: NSPoint(x: 236, y: 23), size: 22, weight: .bold, color: ink, mono: true)

    let temp = NSBezierPath(roundedRect: NSRect(x: 302, y: 34, width: 72, height: 28), xRadius: 9, yRadius: 9)
    mist.withAlphaComponent(0.18).setFill()
    temp.fill()
    mist.withAlphaComponent(0.58).setStroke()
    temp.lineWidth = 1
    temp.stroke()
    menuBarText("45°", at: NSPoint(x: 316, y: 40), size: 18, weight: .bold, color: ink, mono: true)

    drawMenuBarResetLane(value: 0.58, rect: NSRect(x: 404, y: 58, width: 60, height: 5), marker: taupe, track: taupe.withAlphaComponent(0.20))
    drawMenuBarResetLane(value: 0.24, rect: NSRect(x: 404, y: 34, width: 60, height: 5), marker: clay, track: taupe.withAlphaComponent(0.20))
    for rect in [NSRect(x: 480, y: 45, width: 62, height: 20), NSRect(x: 480, y: 21, width: 62, height: 20)] {
        let pill = NSBezierPath(roundedRect: rect, xRadius: 7, yRadius: 7)
        taupe.withAlphaComponent(0.13).setFill()
        pill.fill()
        taupe.withAlphaComponent(0.28).setStroke()
        pill.lineWidth = 1
        pill.stroke()
    }
    menuBarText("4h", at: NSPoint(x: 498, y: 47), size: 18, weight: .bold, color: ink, mono: true)
    menuBarText("6d8h", at: NSPoint(x: 490, y: 23), size: 18, weight: .bold, color: ink, mono: true)

    let chip = NSBezierPath(roundedRect: NSRect(x: 574, y: 28, width: 64, height: 40), xRadius: 9, yRadius: 9)
    mist.withAlphaComponent(0.11).setFill()
    chip.fill()
    mist.withAlphaComponent(0.36).setStroke()
    chip.lineWidth = 1
    chip.stroke()
    menuBarText("C43", at: NSPoint(x: 584, y: 47), size: 15, weight: .bold, color: ink, mono: true)
    menuBarText("R80", at: NSPoint(x: 584, y: 29), size: 15, weight: .bold, color: ink, mono: true)

    let battery = NSBezierPath(roundedRect: NSRect(x: 675, y: 38, width: 48, height: 22), xRadius: 5, yRadius: 5)
    mist.withAlphaComponent(0.13).setFill()
    battery.fill()
    mist.withAlphaComponent(0.68).setStroke()
    battery.lineWidth = 1.4
    battery.stroke()
    NSBezierPath(roundedRect: NSRect(x: 721, y: 45, width: 4, height: 8), xRadius: 2, yRadius: 2).fill()
    mist.withAlphaComponent(0.68).setFill()
    NSBezierPath(roundedRect: NSRect(x: 682, y: 45, width: 32, height: 8), xRadius: 3, yRadius: 3).fill()

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

try writePNG(consoleOutputPath) {
    fillCanvas(NSColor(calibratedRed: 0.91, green: 0.95, blue: 0.98, alpha: 1.0))
    NSGradient(colors: [
        NSColor(calibratedRed: 0.96, green: 0.985, blue: 1.00, alpha: 1.0),
        NSColor(calibratedRed: 0.84, green: 0.91, blue: 0.96, alpha: 1.0),
    ])?.draw(in: NSBezierPath(rect: NSRect(origin: .zero, size: canvasSize)), angle: 25)

    drawText("Actual app-rendered Signal Console", in: NSRect(x: 72, y: 72, width: 440, height: 92), size: 37, weight: .bold, color: NSColor(calibratedRed: 0.08, green: 0.13, blue: 0.15, alpha: 1.0))
    drawText("The same native view used by the menu bar popover. Public screenshot uses sample quota values, plus sample reset, SSD, CPU, and RAM signals.", in: NSRect(x: 74, y: 176, width: 430, height: 74), size: 18, weight: .regular, color: NSColor(calibratedRed: 0.19, green: 0.28, blue: 0.31, alpha: 0.92))

    drawPill("Live source", rect: NSRect(x: 74, y: 280, width: 132, height: 38), fill: NSColor(calibratedRed: 0.05, green: 0.72, blue: 0.64, alpha: 0.13), stroke: NSColor(calibratedRed: 0.05, green: 0.72, blue: 0.64, alpha: 0.30), text: NSColor(calibratedRed: 0.06, green: 0.22, blue: 0.21, alpha: 1.0), dot: NSColor(calibratedRed: 0.05, green: 0.72, blue: 0.64, alpha: 1.0))
    drawPill("5h + 7d", rect: NSRect(x: 220, y: 280, width: 118, height: 38), fill: NSColor(calibratedRed: 1.00, green: 0.72, blue: 0.25, alpha: 0.15), stroke: NSColor(calibratedRed: 1.00, green: 0.72, blue: 0.25, alpha: 0.34), text: NSColor(calibratedRed: 0.28, green: 0.20, blue: 0.08, alpha: 1.0))
    drawPill("Live summary", rect: NSRect(x: 352, y: 280, width: 144, height: 38), fill: NSColor(calibratedRed: 0.216, green: 0.424, blue: 0.561, alpha: 0.09), stroke: NSColor(calibratedRed: 0.216, green: 0.424, blue: 0.561, alpha: 0.20), text: NSColor(calibratedRed: 0.063, green: 0.137, blue: 0.227, alpha: 1.0))

    drawRoundedRect(NSRect(x: 72, y: 382, width: 468, height: 84), radius: 26, fill: NSColor.white.withAlphaComponent(0.48), stroke: NSColor(calibratedRed: 0.10, green: 0.19, blue: 0.23, alpha: 0.16))
    drawImage(menuBar, in: NSRect(x: 92, y: 405, width: 395, height: 48))
    drawText("Menu bar first. Details only when you click.", in: NSRect(x: 78, y: 490, width: 420, height: 24), size: 16, weight: .medium, color: NSColor(calibratedRed: 0.42, green: 0.50, blue: 0.53, alpha: 0.90))

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
    drawText("Beautiful local quota visibility for Codex", in: NSRect(x: 78, y: 142, width: 460, height: 36), size: 24, weight: .semibold, color: NSColor(calibratedRed: 0.74, green: 0.88, blue: 0.86, alpha: 0.95))
    drawText("5-hour and 7-day usage, reset countdowns, SSD temperature, CPU/RAM context, safe diagnostics, and local-only reports from the macOS menu bar.", in: NSRect(x: 78, y: 202, width: 450, height: 116), size: 19, weight: .regular, color: NSColor.white.withAlphaComponent(0.72))

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
