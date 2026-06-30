#!/usr/bin/env swift
import AppKit
import Foundation

struct PreviewTheme {
    let name: String
    let background: NSColor
    let panel: NSColor
    let panelSoft: NSColor
    let border: NSColor
    let text: NSColor
    let secondary: NSColor
    let muted: NSColor
    let mint: NSColor
    let amber: NSColor
    let coral: NSColor
    let blue: NSColor
}

struct PreviewState {
    let name: String
    let detail: String
    let source: String
    let fiveHour: Int?
    let sevenDay: Int?
    let reset: String
    let status: NSColor
}

let canvasSize = NSSize(width: 1280, height: 1220)
let outputPath = "docs/design/codex-gauge-theme-state-fixtures.png"

let themes = [
    PreviewTheme(
        name: "Blue Ceramic",
        background: NSColor(calibratedRed: 0.910, green: 0.953, blue: 0.980, alpha: 1.0),
        panel: NSColor(calibratedRed: 0.965, green: 0.984, blue: 1.000, alpha: 1.0),
        panelSoft: NSColor(calibratedRed: 0.910, green: 0.953, blue: 0.980, alpha: 1.0),
        border: NSColor(calibratedRed: 0.659, green: 0.749, blue: 0.816, alpha: 0.88),
        text: NSColor(calibratedRed: 0.063, green: 0.137, blue: 0.227, alpha: 0.98),
        secondary: NSColor(calibratedRed: 0.145, green: 0.275, blue: 0.380, alpha: 0.92),
        muted: NSColor(calibratedRed: 0.360, green: 0.492, blue: 0.580, alpha: 0.82),
        mint: NSColor(calibratedRed: 0.114, green: 0.733, blue: 0.718, alpha: 0.96),
        amber: NSColor(calibratedRed: 0.886, green: 0.651, blue: 0.208, alpha: 0.96),
        coral: NSColor(calibratedRed: 0.906, green: 0.384, blue: 0.361, alpha: 0.96),
        blue: NSColor(calibratedRed: 0.216, green: 0.424, blue: 0.561, alpha: 0.96)
    ),
    PreviewTheme(
        name: "Signal Dark",
        background: NSColor(calibratedRed: 0.02, green: 0.05, blue: 0.08, alpha: 1.0),
        panel: NSColor(calibratedRed: 0.07, green: 0.13, blue: 0.18, alpha: 1.0),
        panelSoft: NSColor(calibratedRed: 0.03, green: 0.07, blue: 0.10, alpha: 1.0),
        border: NSColor(calibratedRed: 0.68, green: 0.81, blue: 0.92, alpha: 0.30),
        text: NSColor(calibratedRed: 0.93, green: 0.97, blue: 1.00, alpha: 0.96),
        secondary: NSColor(calibratedRed: 0.82, green: 0.89, blue: 0.94, alpha: 0.98),
        muted: NSColor(calibratedRed: 0.62, green: 0.70, blue: 0.76, alpha: 0.92),
        mint: NSColor(calibratedRed: 0.31, green: 0.94, blue: 0.68, alpha: 0.96),
        amber: NSColor(calibratedRed: 1.00, green: 0.78, blue: 0.35, alpha: 0.96),
        coral: NSColor(calibratedRed: 1.00, green: 0.37, blue: 0.40, alpha: 0.96),
        blue: NSColor(calibratedRed: 0.47, green: 0.72, blue: 1.00, alpha: 0.96)
    ),
    PreviewTheme(
        name: "Mono Graphite",
        background: NSColor(calibratedWhite: 0.02, alpha: 1.0),
        panel: NSColor(calibratedWhite: 0.12, alpha: 1.0),
        panelSoft: NSColor(calibratedWhite: 0.05, alpha: 1.0),
        border: NSColor(calibratedWhite: 1.00, alpha: 0.30),
        text: NSColor(calibratedWhite: 0.94, alpha: 0.96),
        secondary: NSColor(calibratedWhite: 0.82, alpha: 0.98),
        muted: NSColor(calibratedWhite: 0.64, alpha: 0.92),
        mint: NSColor(calibratedWhite: 0.86, alpha: 0.96),
        amber: NSColor(calibratedWhite: 0.64, alpha: 0.96),
        coral: NSColor(calibratedWhite: 0.48, alpha: 0.96),
        blue: NSColor(calibratedWhite: 0.72, alpha: 0.96)
    ),
]

let states = [
    PreviewState(name: "Live", detail: "Current local app-server signal", source: "Source: Menu Bar", fiveHour: 82, sevenDay: 76, reset: "4h", status: NSColor.systemGreen),
    PreviewState(name: "Codex closed", detail: "Open Codex desktop once to enable live usage", source: "No live quota yet", fiveHour: nil, sevenDay: nil, reset: "--", status: NSColor.systemOrange),
    PreviewState(name: "Live only", detail: "No stored cache or snapshot", source: "Storage: Zero persistence", fiveHour: 58, sevenDay: 63, reset: "2h", status: NSColor.systemBlue),
    PreviewState(name: "Low quota", detail: "Adaptive refresh speeds up", source: "Source: Menu Bar", fiveHour: 9, sevenDay: 44, reset: "38m", status: NSColor.systemRed),
    PreviewState(name: "Battery mode", detail: "Usage plus battery only", source: "Power Saver active", fiveHour: 80, sevenDay: 79, reset: "60m", status: NSColor.systemBlue),
]

func canvasRect(_ rect: NSRect) -> NSRect {
    NSRect(x: rect.minX, y: canvasSize.height - rect.maxY, width: rect.width, height: rect.height)
}

func roundedPath(_ rect: NSRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: canvasRect(rect), xRadius: radius, yRadius: radius)
}

func roundedRect(_ rect: NSRect, radius: CGFloat, fill: NSColor, stroke: NSColor? = nil, lineWidth: CGFloat = 1) {
    let path = roundedPath(rect, radius: radius)
    fill.setFill()
    path.fill()
    if let stroke {
        stroke.setStroke()
        path.lineWidth = lineWidth
        path.stroke()
    }
}

func text(_ value: String, _ rect: NSRect, size: CGFloat, weight: NSFont.Weight, color: NSColor, mono: Bool = false) {
    let font = mono
        ? NSFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
        : NSFont.systemFont(ofSize: size, weight: weight)
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineBreakMode = .byTruncatingTail
    NSAttributedString(
        string: value,
        attributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ]
    ).draw(in: canvasRect(rect))
}

func quotaColor(_ value: Int?, theme: PreviewTheme) -> NSColor {
    guard let value else {
        return theme.muted
    }
    if value <= 15 {
        return theme.coral
    }
    if value <= 35 {
        return theme.amber
    }
    return theme.mint
}

func drawRail(value: Int?, rect: NSRect, theme: PreviewTheme) {
    roundedRect(rect, radius: rect.height / 2, fill: theme.border.withAlphaComponent(0.16))
    guard let value else {
        return
    }
    let width = max(6, rect.width * CGFloat(max(0, min(100, value))) / 100)
    roundedRect(NSRect(x: rect.minX, y: rect.minY, width: width, height: rect.height), radius: rect.height / 2, fill: quotaColor(value, theme: theme))
}

func drawMiniConsole(theme: PreviewTheme, state: PreviewState, rect: NSRect) {
    roundedRect(rect, radius: 24, fill: theme.panelSoft, stroke: theme.border, lineWidth: 1.4)
    NSGradient(colors: [theme.panel, theme.panelSoft])?.draw(in: roundedPath(rect.insetBy(dx: 1, dy: 1), radius: 23), angle: 90)
    roundedRect(rect, radius: 24, fill: NSColor.clear, stroke: theme.border, lineWidth: 1.4)

    text(theme.name, NSRect(x: rect.minX + 22, y: rect.minY + 18, width: 170, height: 24), size: 18, weight: .bold, color: theme.text)
    roundedRect(NSRect(x: rect.maxX - 94, y: rect.minY + 18, width: 70, height: 26), radius: 13, fill: state.status.withAlphaComponent(0.16), stroke: theme.border.withAlphaComponent(0.5))
    state.status.setFill()
    NSBezierPath(ovalIn: canvasRect(NSRect(x: rect.maxX - 82, y: rect.minY + 27, width: 8, height: 8))).fill()
    text(state.name, NSRect(x: rect.maxX - 68, y: rect.minY + 23, width: 42, height: 14), size: 10, weight: .semibold, color: theme.secondary)

    let strip = NSRect(x: rect.minX + 22, y: rect.minY + 56, width: rect.width - 44, height: 36)
    roundedRect(strip, radius: 12, fill: state.status.withAlphaComponent(0.10), stroke: theme.border.withAlphaComponent(0.42))
    text(state.detail, NSRect(x: strip.minX + 14, y: strip.minY + 10, width: strip.width - 28, height: 16), size: 12, weight: .medium, color: theme.secondary)

    let row5 = NSRect(x: rect.minX + 22, y: rect.minY + 104, width: rect.width - 44, height: 30)
    let row7 = NSRect(x: rect.minX + 22, y: rect.minY + 138, width: rect.width - 44, height: 30)
    for (label, value, row) in [("5h", state.fiveHour, row5), ("7d", state.sevenDay, row7)] {
        text(label, NSRect(x: row.minX, y: row.minY + 4, width: 32, height: 22), size: 17, weight: .bold, color: theme.text, mono: true)
        text(value.map { "\($0)%" } ?? "--", NSRect(x: row.maxX - 48, y: row.minY + 6, width: 46, height: 18), size: 13, weight: .bold, color: quotaColor(value, theme: theme), mono: true)
        drawRail(value: value, rect: NSRect(x: row.minX + 42, y: row.minY + 13, width: row.width - 98, height: 9), theme: theme)
    }

    let footer = NSRect(x: rect.minX + 22, y: rect.maxY - 24, width: rect.width - 44, height: 18)
    text(state.source, NSRect(x: footer.minX, y: footer.minY + 4, width: 160, height: 14), size: 10, weight: .medium, color: theme.muted)
    text("reset \(state.reset)", NSRect(x: footer.maxX - 80, y: footer.minY + 4, width: 80, height: 14), size: 10, weight: .semibold, color: theme.amber, mono: true)
}

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
NSColor(calibratedRed: 0.08, green: 0.09, blue: 0.10, alpha: 1.0).setFill()
NSRect(origin: .zero, size: canvasSize).fill()

text("Codex Gauge theme-state visual QA", NSRect(x: 44, y: 32, width: 520, height: 30), size: 24, weight: .bold, color: NSColor.white.withAlphaComponent(0.95))
text("Three themes across, five important runtime states down. Generated from script/generate_theme_state_previews.swift.", NSRect(x: 44, y: 66, width: 780, height: 18), size: 12, weight: .regular, color: NSColor.white.withAlphaComponent(0.62))

let startX: CGFloat = 44
let startY: CGFloat = 110
let gapX: CGFloat = 24
let gapY: CGFloat = 30
let cardWidth: CGFloat = (canvasSize.width - startX * 2 - gapX * 2) / 3
let cardHeight: CGFloat = 190

for (rowIndex, state) in states.enumerated() {
    text(state.name, NSRect(x: 44, y: startY + CGFloat(rowIndex) * (cardHeight + gapY) - 24, width: 220, height: 18), size: 13, weight: .semibold, color: NSColor.white.withAlphaComponent(0.70))
    for (columnIndex, theme) in themes.enumerated() {
        let rect = NSRect(
            x: startX + CGFloat(columnIndex) * (cardWidth + gapX),
            y: startY + CGFloat(rowIndex) * (cardHeight + gapY),
            width: cardWidth,
            height: cardHeight
        )
        drawMiniConsole(theme: theme, state: state, rect: rect)
    }
}

NSGraphicsContext.restoreGraphicsState()

let outputURL = URL(fileURLWithPath: outputPath)
try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
guard let data = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not encode PNG")
}
try data.write(to: outputURL)
print("Wrote \(outputPath)")
