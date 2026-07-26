#!/usr/bin/env swift
import AppKit
import Foundation

let sourcePath = "native/assets/CodexGauge-source.png"
let logoPath = "docs/assets/codex-gauge-logo.png"
let iconsetPath = "native/assets/CodexGauge.iconset"
let icnsPath = "native/assets/CodexGauge.icns"

guard let sourceImage = NSImage(contentsOfFile: sourcePath) else {
    fatalError("Missing logo source: \(sourcePath)")
}

func writePNG(path: String, pixels: Int) throws {
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
    sourceImage.draw(
        in: NSRect(x: 0, y: 0, width: pixels, height: pixels),
        from: NSRect(origin: .zero, size: sourceImage.size),
        operation: .copy,
        fraction: 1,
        respectFlipped: true,
        hints: [.interpolation: NSImageInterpolation.high.rawValue]
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

func run(_ executable: String, _ arguments: [String]) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        throw NSError(
            domain: "CodexGaugeLogo",
            code: Int(process.terminationStatus),
            userInfo: [NSLocalizedDescriptionKey: "\(executable) failed"]
        )
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

try writePNG(path: logoPath, pixels: 1024)
for (name, size) in iconSizes {
    try writePNG(path: "\(iconsetPath)/\(name)", pixels: size)
}
try run("/usr/bin/iconutil", ["-c", "icns", "-o", icnsPath, iconsetPath])
print("Wrote \(icnsPath)")
