#!/usr/bin/env swift
import AppKit
import Foundation

let logoPath = "docs/assets/codex-gauge-logo.png"
let iconsetPath = "native/assets/CodexGauge.iconset"
let icnsPath = "native/assets/CodexGauge.icns"

let porcelainTop = NSColor(deviceRed: 0.78, green: 0.85, blue: 0.86, alpha: 1.0)
let porcelainBottom = NSColor(deviceRed: 0.62, green: 0.72, blue: 0.74, alpha: 1.0)
let porcelainEdge = NSColor(deviceRed: 0.48, green: 0.57, blue: 0.59, alpha: 0.40)
let ink = NSColor(deviceWhite: 0.08, alpha: 0.98)
let track = NSColor(deviceWhite: 0.10, alpha: 0.96)
let meterBlue = NSColor(deviceRed: 134.0 / 255.0, green: 150.0 / 255.0, blue: 185.0 / 255.0, alpha: 1.0)
let softHighlight = NSColor.white.withAlphaComponent(0.22)
let softShadow = NSColor.black.withAlphaComponent(0.16)

func flipped(_ rect: NSRect, height: CGFloat) -> NSRect {
    NSRect(x: rect.minX, y: height - rect.maxY, width: rect.width, height: rect.height)
}

func rounded(_ rect: NSRect, radius: CGFloat, height: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: flipped(rect, height: height), xRadius: radius, yRadius: radius)
}

func drawText(_ value: String, rect: NSRect, size: CGFloat, weight: NSFont.Weight, color: NSColor, height: CGFloat) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    paragraph.lineBreakMode = .byClipping
    NSAttributedString(
        string: value,
        attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: size, weight: weight),
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ]
    ).draw(in: flipped(rect, height: height))
}

func drawMeter(row: NSRect, fraction: CGFloat, height: CGFloat) {
    let path = rounded(row, radius: max(2, row.height * 0.18), height: height)
    track.setFill()
    path.fill()

    let inner = row.insetBy(dx: row.height * 0.12, dy: row.height * 0.12)
    let fillWidth = max(inner.height * 1.4, inner.width * max(0, min(1, fraction)))
    let fillRect = NSRect(x: inner.minX, y: inner.minY, width: min(inner.width, fillWidth), height: inner.height)

    NSGraphicsContext.saveGraphicsState()
    path.addClip()
    meterBlue.setFill()
    flipped(fillRect, height: height).fill()
    NSGraphicsContext.restoreGraphicsState()
}

func drawLogo(size: CGFloat, includeWordmark: Bool) {
    let canvas = NSRect(x: 0, y: 0, width: size, height: size)
    NSGradient(colors: [porcelainTop, porcelainBottom])?.draw(in: NSBezierPath(rect: canvas), angle: 270)

    let outerInset = size * 0.085
    let outer = NSRect(x: outerInset, y: outerInset, width: size - outerInset * 2, height: size - outerInset * 2)
    let outerPath = rounded(outer, radius: size * 0.19, height: size)
    NSGradient(colors: [
        NSColor.white.withAlphaComponent(0.28),
        NSColor.white.withAlphaComponent(0.06),
    ])?.draw(in: outerPath, angle: 270)
    porcelainEdge.setStroke()
    outerPath.lineWidth = max(1, size * 0.012)
    outerPath.stroke()

    let panel = outer.insetBy(dx: size * 0.11, dy: size * 0.15)
    let panelPath = rounded(panel, radius: size * 0.11, height: size)
    ink.setFill()
    panelPath.fill()

    let labelWidth = size * 0.18
    let labelColor = NSColor.white.withAlphaComponent(0.90)
    drawText("5h", rect: NSRect(x: panel.minX + size * 0.038, y: panel.minY + size * 0.13, width: labelWidth, height: size * 0.12), size: size * 0.088, weight: .heavy, color: labelColor, height: size)
    drawText("7d", rect: NSRect(x: panel.minX + size * 0.038, y: panel.maxY - size * 0.25, width: labelWidth, height: size * 0.12), size: size * 0.088, weight: .heavy, color: labelColor, height: size)

    let meterX = panel.minX + size * 0.245
    let meterW = panel.width - size * 0.31
    let meterH = max(5, size * 0.06)
    drawMeter(row: NSRect(x: meterX, y: panel.minY + size * 0.165, width: meterW, height: meterH), fraction: 0.72, height: size)
    drawMeter(row: NSRect(x: meterX, y: panel.maxY - size * 0.205, width: meterW, height: meterH), fraction: 0.88, height: size)

    let highlight = NSRect(x: outer.minX + size * 0.08, y: outer.minY + size * 0.055, width: outer.width * 0.62, height: size * 0.055)
    softHighlight.setFill()
    rounded(highlight, radius: size * 0.027, height: size).fill()

    let foot = NSRect(x: outer.minX + size * 0.10, y: outer.maxY - size * 0.08, width: outer.width * 0.80, height: size * 0.035)
    softShadow.setFill()
    rounded(foot, radius: size * 0.018, height: size).fill()

    guard includeWordmark else {
        return
    }

    let wordmark = "CODEX GAUGE"
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let font = NSFont.systemFont(ofSize: size * 0.052, weight: .bold)
    NSAttributedString(
        string: wordmark,
        attributes: [
            .font: font,
            .foregroundColor: NSColor(deviceWhite: 0.10, alpha: 0.90),
            .paragraphStyle: paragraph,
            .kern: size * 0.004,
        ]
    ).draw(in: flipped(NSRect(x: outer.minX, y: outer.maxY - size * 0.155, width: outer.width, height: size * 0.08), height: size))
}

func writePNG(path: String, pixels: Int, includeWordmark: Bool) throws {
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    bitmap.size = NSSize(width: pixels, height: pixels)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    drawLogo(size: CGFloat(pixels), includeWordmark: includeWordmark)
    NSGraphicsContext.restoreGraphicsState()

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Could not encode \(path)")
    }
    let url = URL(fileURLWithPath: path)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: url)
    print("Wrote \(path)")
}

func run(_ executable: String, _ arguments: [String]) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        throw NSError(domain: "CodexGaugeLogo", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "\(executable) failed"])
    }
}

try FileManager.default.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)
let iconSizes: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

try writePNG(path: logoPath, pixels: 1024, includeWordmark: true)
for (name, size) in iconSizes {
    try writePNG(path: "\(iconsetPath)/\(name)", pixels: size, includeWordmark: false)
}
try run("/usr/bin/iconutil", ["-c", "icns", "-o", icnsPath, iconsetPath])
print("Wrote \(icnsPath)")
