import Cocoa
import Darwin
import Foundation
import UserNotifications

private struct UsageSnapshot: Decodable {
    let title: String
    let updatedAt: String
    let codex: ServiceStatus
}

private struct ServiceStatus: Decodable {
    let ok: Bool
    let service: String
    let fiveHourLeft: Int?
    let sevenDayLeft: Int?
    let fiveHourReset: Double?
    let sevenDayReset: Double?
    let plan: String?
    let source: String?
    let dataTime: String?
    let error: String?
}

private struct GitHubRelease: Decodable {
    let tagName: String
    let name: String?
    let body: String?
    let htmlURL: String
    let publishedAt: String?
    let prerelease: Bool
    let draft: Bool
    let assets: [GitHubReleaseAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlURL = "html_url"
        case publishedAt = "published_at"
        case prerelease
        case draft
        case assets
    }
}

private struct GitHubReleaseAsset: Decodable {
    let name: String
    let browserDownloadURL: String
    let size: Int?
    let contentType: String?
    let digest: String?

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
        case size
        case contentType = "content_type"
        case digest
    }
}

private enum UpdateCheckMode {
    case manual
    case automatic
}

private struct PreparedUpdate {
    let release: GitHubRelease
    let asset: GitHubReleaseAsset
    let latestVersion: String
    let appURL: URL
    let workDirectory: URL
}

private struct DoctorCheck {
    let title: String
    let state: String
    let detail: String
}

private func healthSummaryText(_ checks: [DoctorCheck]) -> String {
    let okCount = checks.filter { $0.state == "green" }.count
    let optionalCount = checks.filter { $0.state == "grey" }.count
    let issueCount = checks.count - okCount - optionalCount
    if issueCount > 0 {
        return "\(okCount) OK · \(issueCount) check"
    }
    if optionalCount > 0 {
        return "\(okCount) OK · \(optionalCount) optional"
    }
    return "\(okCount) OK"
}

private struct SignalConsoleLayout {
    let bounds: NSRect
    private let margin: CGFloat = 18

    var panelRect: NSRect {
        bounds
    }

    var headerTitleRect: NSRect {
        NSRect(x: margin, y: 16, width: 220, height: 24)
    }

    var headerStatusRect: NSRect {
        NSRect(x: bounds.width - margin - 92, y: 17, width: 92, height: 20)
    }

    var fiveHourQuotaRowRect: NSRect {
        NSRect(x: margin, y: 58, width: bounds.width - margin * 2, height: 62)
    }

    var sevenDayQuotaRowRect: NSRect {
        NSRect(x: margin, y: 126, width: bounds.width - margin * 2, height: 62)
    }

    var freshnessRect: NSRect {
        NSRect(x: margin, y: 184, width: bounds.width - margin * 2 - 132, height: 20)
    }

    var nextRefreshRect: NSRect {
        NSRect(x: bounds.width - margin - 124, y: 184, width: 124, height: 20)
    }

    var openChatGPTButtonRect: NSRect {
        NSRect(x: margin, y: 226, width: 200, height: 34)
    }

    var iconButtonRects: [NSRect] {
        let size: CGFloat = 34
        let gap: CGFloat = 8
        let right = bounds.width - margin
        return (0..<3).map { index in
            NSRect(x: right - size - CGFloat(2 - index) * (size + gap), y: 226, width: size, height: size)
        }
    }
}

private struct GaugePalette {
    let background: NSColor
    let border: NSColor
    let track: NSColor
    let resetTrack: NSColor
    let primaryText: NSColor
    let secondaryText: NSColor
    let mutedText: NSColor
}

private final class CodexGaugeStatusItemView: NSView {
    var onDraw: ((NSRect) -> Void)?
    var onClick: ((NSEvent) -> Void)?

    override var acceptsFirstResponder: Bool {
        true
    }

    override func draw(_ dirtyRect: NSRect) {
        NSGraphicsContext.current?.shouldAntialias = true
        onDraw?(bounds)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        onClick?(event)
    }

    override func rightMouseUp(with event: NSEvent) {
        onClick?(event)
    }
}

private let blueCeramicThemeKey = "blueCeramic"
private let porcelainLabThemeKey = "porcelainLab"
private let paperConsoleThemeKey = "paperConsole"
private let signalDarkThemeKey = "signalDark"
private let monoGraphiteThemeKey = "monoGraphite"

private struct SignalConsoleTheme {
    let key: String
    let name: String
    let appearance: NSAppearance.Name
    let material: NSVisualEffectView.Material
    let panelBackground: NSColor
    let panelStrongBackground: NSColor
    let panelSoftBackground: NSColor
    let panelBorder: NSColor
    let textPrimary: NSColor
    let textSecondary: NSColor
    let textMuted: NSColor
    let buttonPrimaryText: NSColor
    let secondaryButtonBackground: NSColor
    let commandButtonBackground: NSColor
    let trackFill: NSColor
    let baselineStroke: NSColor
    let mintAccent: NSColor
    let amberAccent: NSColor
    let coralAccent: NSColor
    let blueAccent: NSColor
    let mintSoft: NSColor
    let amberSoft: NSColor
    let coralSoft: NSColor
    let blueSoft: NSColor
    let quotaLowEnd: NSColor
    let quotaHighEnd: NSColor
    let resetMidAccent: NSColor
    let menuDarkPalette: GaugePalette
    let menuLightPalette: GaugePalette
}

private func monoAccent(_ white: CGFloat, alpha: CGFloat = 1.0) -> NSColor {
    NSColor(calibratedWhite: white, alpha: alpha)
}

private func blueCeramicTheme() -> SignalConsoleTheme {
    SignalConsoleTheme(
        key: blueCeramicThemeKey,
        name: "Blue Ceramic",
        appearance: .aqua,
        material: .popover,
        panelBackground: NSColor(calibratedRed: 0.965, green: 0.984, blue: 1.000, alpha: 1.0),
        panelStrongBackground: NSColor(calibratedRed: 0.910, green: 0.953, blue: 0.980, alpha: 1.0),
        panelSoftBackground: NSColor(calibratedRed: 0.216, green: 0.424, blue: 0.561, alpha: 0.070),
        panelBorder: NSColor(calibratedRed: 0.659, green: 0.749, blue: 0.816, alpha: 0.88),
        textPrimary: NSColor(calibratedRed: 0.063, green: 0.137, blue: 0.227, alpha: 0.98),
        textSecondary: NSColor(calibratedRed: 0.145, green: 0.275, blue: 0.380, alpha: 0.92),
        textMuted: NSColor(calibratedRed: 0.360, green: 0.492, blue: 0.580, alpha: 0.82),
        buttonPrimaryText: NSColor.white,
        secondaryButtonBackground: NSColor(calibratedRed: 0.910, green: 0.953, blue: 0.980, alpha: 0.84),
        commandButtonBackground: NSColor.white.withAlphaComponent(0.66),
        trackFill: NSColor(calibratedRed: 0.760, green: 0.858, blue: 0.902, alpha: 0.72),
        baselineStroke: NSColor(calibratedRed: 0.659, green: 0.749, blue: 0.816, alpha: 0.48),
        mintAccent: NSColor(calibratedRed: 0.114, green: 0.733, blue: 0.718, alpha: 0.96),
        amberAccent: NSColor(calibratedRed: 0.886, green: 0.651, blue: 0.208, alpha: 0.96),
        coralAccent: NSColor(calibratedRed: 0.906, green: 0.384, blue: 0.361, alpha: 0.96),
        blueAccent: NSColor(calibratedRed: 0.216, green: 0.424, blue: 0.561, alpha: 0.96),
        mintSoft: NSColor(calibratedRed: 0.114, green: 0.733, blue: 0.718, alpha: 0.14),
        amberSoft: NSColor(calibratedRed: 0.886, green: 0.651, blue: 0.208, alpha: 0.16),
        coralSoft: NSColor(calibratedRed: 0.906, green: 0.384, blue: 0.361, alpha: 0.14),
        blueSoft: NSColor(calibratedRed: 0.216, green: 0.424, blue: 0.561, alpha: 0.12),
        quotaLowEnd: NSColor(calibratedRed: 0.906, green: 0.384, blue: 0.361, alpha: 0.96),
        quotaHighEnd: NSColor(calibratedRed: 0.114, green: 0.733, blue: 0.718, alpha: 0.96),
        resetMidAccent: NSColor(calibratedRed: 0.886, green: 0.651, blue: 0.208, alpha: 0.96),
        menuDarkPalette: GaugePalette(
            background: NSColor(calibratedRed: 0.063, green: 0.137, blue: 0.227, alpha: 0.88),
            border: NSColor(calibratedRed: 0.659, green: 0.749, blue: 0.816, alpha: 0.54),
            track: NSColor.white.withAlphaComponent(0.18),
            resetTrack: NSColor(calibratedRed: 0.886, green: 0.651, blue: 0.208, alpha: 0.28),
            primaryText: NSColor.white.withAlphaComponent(0.96),
            secondaryText: NSColor.white.withAlphaComponent(0.72),
            mutedText: NSColor.white.withAlphaComponent(0.44)
        ),
        menuLightPalette: GaugePalette(
            background: NSColor(calibratedRed: 0.965, green: 0.984, blue: 1.000, alpha: 0.92),
            border: NSColor(calibratedRed: 0.659, green: 0.749, blue: 0.816, alpha: 0.76),
            track: NSColor(calibratedRed: 0.760, green: 0.858, blue: 0.902, alpha: 0.76),
            resetTrack: NSColor(calibratedRed: 0.886, green: 0.651, blue: 0.208, alpha: 0.26),
            primaryText: NSColor(calibratedRed: 0.063, green: 0.137, blue: 0.227, alpha: 0.94),
            secondaryText: NSColor(calibratedRed: 0.145, green: 0.275, blue: 0.380, alpha: 0.74),
            mutedText: NSColor(calibratedRed: 0.360, green: 0.492, blue: 0.580, alpha: 0.54)
        )
    )
}

private func signalDarkTheme() -> SignalConsoleTheme {
    SignalConsoleTheme(
        key: signalDarkThemeKey,
        name: "Signal Dark",
        appearance: .darkAqua,
        material: .hudWindow,
        panelBackground: NSColor(calibratedRed: 0.03, green: 0.07, blue: 0.10, alpha: 1.0),
        panelStrongBackground: NSColor(calibratedRed: 0.07, green: 0.13, blue: 0.18, alpha: 1.0),
        panelSoftBackground: NSColor.white.withAlphaComponent(0.075),
        panelBorder: NSColor(calibratedRed: 0.68, green: 0.81, blue: 0.92, alpha: 0.30),
        textPrimary: NSColor(calibratedRed: 0.93, green: 0.97, blue: 1.00, alpha: 0.96),
        textSecondary: NSColor(calibratedRed: 0.82, green: 0.89, blue: 0.94, alpha: 0.98),
        textMuted: NSColor(calibratedRed: 0.62, green: 0.70, blue: 0.76, alpha: 0.92),
        buttonPrimaryText: NSColor(calibratedRed: 0.03, green: 0.07, blue: 0.10, alpha: 1.0),
        secondaryButtonBackground: NSColor.white.withAlphaComponent(0.12),
        commandButtonBackground: NSColor.white.withAlphaComponent(0.08),
        trackFill: NSColor.white.withAlphaComponent(0.12),
        baselineStroke: NSColor.white.withAlphaComponent(0.16),
        mintAccent: NSColor(calibratedRed: 0.31, green: 0.94, blue: 0.68, alpha: 0.96),
        amberAccent: NSColor(calibratedRed: 1.00, green: 0.78, blue: 0.35, alpha: 0.96),
        coralAccent: NSColor(calibratedRed: 1.00, green: 0.37, blue: 0.40, alpha: 0.96),
        blueAccent: NSColor(calibratedRed: 0.47, green: 0.72, blue: 1.00, alpha: 0.96),
        mintSoft: NSColor(calibratedRed: 0.31, green: 0.94, blue: 0.68, alpha: 0.18),
        amberSoft: NSColor(calibratedRed: 1.00, green: 0.78, blue: 0.35, alpha: 0.18),
        coralSoft: NSColor(calibratedRed: 1.00, green: 0.37, blue: 0.40, alpha: 0.20),
        blueSoft: NSColor(calibratedRed: 0.47, green: 0.72, blue: 1.00, alpha: 0.16),
        quotaLowEnd: NSColor(calibratedRed: 1.00, green: 0.58, blue: 0.38, alpha: 0.96),
        quotaHighEnd: NSColor(calibratedRed: 0.72, green: 0.94, blue: 0.51, alpha: 0.96),
        resetMidAccent: NSColor(calibratedRed: 1.00, green: 0.58, blue: 0.38, alpha: 0.96),
        menuDarkPalette: GaugePalette(
            background: NSColor(calibratedRed: 0.05, green: 0.11, blue: 0.12, alpha: 0.88),
            border: NSColor(calibratedRed: 0.30, green: 0.62, blue: 0.58, alpha: 0.62),
            track: NSColor.white.withAlphaComponent(0.18),
            resetTrack: NSColor(calibratedRed: 1.00, green: 0.68, blue: 0.22, alpha: 0.24),
            primaryText: NSColor.white.withAlphaComponent(0.94),
            secondaryText: NSColor.white.withAlphaComponent(0.72),
            mutedText: NSColor.white.withAlphaComponent(0.42)
        ),
        menuLightPalette: GaugePalette(
            background: NSColor.white.withAlphaComponent(0.72),
            border: NSColor.black.withAlphaComponent(0.22),
            track: NSColor.black.withAlphaComponent(0.15),
            resetTrack: NSColor(calibratedRed: 0.92, green: 0.50, blue: 0.12, alpha: 0.26),
            primaryText: NSColor.black.withAlphaComponent(0.82),
            secondaryText: NSColor.black.withAlphaComponent(0.58),
            mutedText: NSColor.black.withAlphaComponent(0.34)
        )
    )
}

private func porcelainLabTheme() -> SignalConsoleTheme {
    SignalConsoleTheme(
        key: porcelainLabThemeKey,
        name: "Porcelain Lab",
        appearance: .aqua,
        material: .popover,
        panelBackground: NSColor(calibratedRed: 0.96, green: 0.985, blue: 1.00, alpha: 1.0),
        panelStrongBackground: NSColor(calibratedRed: 0.89, green: 0.94, blue: 0.97, alpha: 1.0),
        panelSoftBackground: NSColor(calibratedRed: 0.09, green: 0.18, blue: 0.24, alpha: 0.065),
        panelBorder: NSColor(calibratedRed: 0.10, green: 0.19, blue: 0.23, alpha: 0.20),
        textPrimary: NSColor(calibratedRed: 0.08, green: 0.13, blue: 0.15, alpha: 0.96),
        textSecondary: NSColor(calibratedRed: 0.19, green: 0.28, blue: 0.31, alpha: 0.96),
        textMuted: NSColor(calibratedRed: 0.42, green: 0.50, blue: 0.53, alpha: 0.92),
        buttonPrimaryText: NSColor(calibratedRed: 0.06, green: 0.11, blue: 0.12, alpha: 1.0),
        secondaryButtonBackground: NSColor(calibratedRed: 0.09, green: 0.18, blue: 0.24, alpha: 0.075),
        commandButtonBackground: NSColor(calibratedRed: 0.09, green: 0.18, blue: 0.24, alpha: 0.055),
        trackFill: NSColor(calibratedRed: 0.09, green: 0.18, blue: 0.24, alpha: 0.13),
        baselineStroke: NSColor(calibratedRed: 0.09, green: 0.18, blue: 0.24, alpha: 0.15),
        mintAccent: NSColor(calibratedRed: 0.05, green: 0.72, blue: 0.64, alpha: 0.96),
        amberAccent: NSColor(calibratedRed: 1.00, green: 0.72, blue: 0.25, alpha: 0.96),
        coralAccent: NSColor(calibratedRed: 0.93, green: 0.27, blue: 0.31, alpha: 0.96),
        blueAccent: NSColor(calibratedRed: 0.24, green: 0.37, blue: 0.92, alpha: 0.96),
        mintSoft: NSColor(calibratedRed: 0.05, green: 0.72, blue: 0.64, alpha: 0.16),
        amberSoft: NSColor(calibratedRed: 1.00, green: 0.72, blue: 0.25, alpha: 0.20),
        coralSoft: NSColor(calibratedRed: 0.93, green: 0.27, blue: 0.31, alpha: 0.16),
        blueSoft: NSColor(calibratedRed: 0.24, green: 0.37, blue: 0.92, alpha: 0.13),
        quotaLowEnd: NSColor(calibratedRed: 0.93, green: 0.27, blue: 0.31, alpha: 0.96),
        quotaHighEnd: NSColor(calibratedRed: 0.05, green: 0.72, blue: 0.64, alpha: 0.96),
        resetMidAccent: NSColor(calibratedRed: 1.00, green: 0.72, blue: 0.25, alpha: 0.96),
        menuDarkPalette: GaugePalette(
            background: NSColor(calibratedRed: 0.04, green: 0.10, blue: 0.13, alpha: 0.90),
            border: NSColor(calibratedRed: 0.36, green: 0.86, blue: 0.82, alpha: 0.58),
            track: NSColor.white.withAlphaComponent(0.18),
            resetTrack: NSColor(calibratedRed: 1.00, green: 0.72, blue: 0.25, alpha: 0.30),
            primaryText: NSColor.white.withAlphaComponent(0.95),
            secondaryText: NSColor.white.withAlphaComponent(0.70),
            mutedText: NSColor.white.withAlphaComponent(0.42)
        ),
        menuLightPalette: GaugePalette(
            background: NSColor(calibratedRed: 0.05, green: 0.12, blue: 0.16, alpha: 0.84),
            border: NSColor(calibratedRed: 0.32, green: 0.72, blue: 0.82, alpha: 0.54),
            track: NSColor.white.withAlphaComponent(0.20),
            resetTrack: NSColor(calibratedRed: 1.00, green: 0.72, blue: 0.25, alpha: 0.30),
            primaryText: NSColor.white.withAlphaComponent(0.96),
            secondaryText: NSColor.white.withAlphaComponent(0.72),
            mutedText: NSColor.white.withAlphaComponent(0.44)
        )
    )
}

private func paperConsoleTheme() -> SignalConsoleTheme {
    porcelainLabTheme()
}

private func monoGraphiteTheme() -> SignalConsoleTheme {
    SignalConsoleTheme(
        key: monoGraphiteThemeKey,
        name: "Mono Graphite",
        appearance: .darkAqua,
        material: .hudWindow,
        panelBackground: monoAccent(0.05, alpha: 1.0),
        panelStrongBackground: monoAccent(0.12, alpha: 1.0),
        panelSoftBackground: monoAccent(1.00, alpha: 0.075),
        panelBorder: monoAccent(1.00, alpha: 0.30),
        textPrimary: monoAccent(0.94, alpha: 0.96),
        textSecondary: monoAccent(0.82, alpha: 0.98),
        textMuted: monoAccent(0.64, alpha: 0.92),
        buttonPrimaryText: monoAccent(0.05),
        secondaryButtonBackground: monoAccent(1.00, alpha: 0.12),
        commandButtonBackground: monoAccent(1.00, alpha: 0.08),
        trackFill: monoAccent(1.00, alpha: 0.12),
        baselineStroke: monoAccent(1.00, alpha: 0.16),
        mintAccent: monoAccent(0.86, alpha: 0.96),
        amberAccent: monoAccent(0.64, alpha: 0.96),
        coralAccent: monoAccent(0.48, alpha: 0.96),
        blueAccent: monoAccent(0.72, alpha: 0.96),
        mintSoft: monoAccent(0.86, alpha: 0.18),
        amberSoft: monoAccent(0.64, alpha: 0.18),
        coralSoft: monoAccent(0.48, alpha: 0.20),
        blueSoft: monoAccent(0.72, alpha: 0.16),
        quotaLowEnd: monoAccent(0.58, alpha: 0.96),
        quotaHighEnd: monoAccent(0.78, alpha: 0.96),
        resetMidAccent: monoAccent(0.58, alpha: 0.96),
        menuDarkPalette: GaugePalette(
            background: monoAccent(0.06, alpha: 0.90),
            border: monoAccent(0.76, alpha: 0.40),
            track: monoAccent(1.00, alpha: 0.16),
            resetTrack: monoAccent(1.00, alpha: 0.16),
            primaryText: monoAccent(0.94, alpha: 0.94),
            secondaryText: monoAccent(0.74, alpha: 0.74),
            mutedText: monoAccent(0.52, alpha: 0.52)
        ),
        menuLightPalette: GaugePalette(
            background: monoAccent(0.94, alpha: 0.86),
            border: monoAccent(0.18, alpha: 0.25),
            track: monoAccent(0.12, alpha: 0.16),
            resetTrack: monoAccent(0.12, alpha: 0.16),
            primaryText: monoAccent(0.08, alpha: 0.84),
            secondaryText: monoAccent(0.16, alpha: 0.58),
            mutedText: monoAccent(0.34, alpha: 0.36)
        )
    )
}

private final class ThemedUtilityPanelView: NSView {
    private let theme: SignalConsoleTheme

    init(frame frameRect: NSRect, theme: SignalConsoleTheme) {
        self.theme = theme
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = theme.panelBackground.cgColor
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        theme.panelBackground.setFill()
        bounds.fill()

        let panel = bounds.insetBy(dx: 10, dy: 10)
        let path = NSBezierPath(roundedRect: panel, xRadius: 18, yRadius: 18)
        NSGradient(colors: [
            theme.panelStrongBackground,
            theme.panelBackground,
        ])?.draw(in: path, angle: 90)
        theme.panelBorder.setStroke()
        path.lineWidth = 1
        path.stroke()
        drawUtilityCircuitMotif(in: panel)
        if bounds.width >= 560 {
            drawUtilitySidebar(in: panel)
        }
    }

    private func drawUtilitySidebar(in panel: NSRect) {
        let sidebar = NSRect(x: panel.minX, y: panel.minY, width: 150, height: panel.height)
        let divider = NSBezierPath()
        divider.move(to: NSPoint(x: sidebar.maxX, y: sidebar.minY))
        divider.line(to: NSPoint(x: sidebar.maxX, y: sidebar.maxY))
        divider.lineWidth = 1
        theme.panelBorder.withAlphaComponent(0.48).setStroke()
        divider.stroke()

        drawUtilityLogoMark(in: NSRect(x: sidebar.minX + 24, y: sidebar.maxY - 54, width: 34, height: 34), color: theme.blueAccent)
        drawUtilityText("Codex Gauge", in: NSRect(x: sidebar.minX + 64, y: sidebar.maxY - 42, width: 74, height: 14), size: 11, weight: .semibold, color: theme.textPrimary)
        let items = ["General", "Appearance", "Signals", "Updates", "About"]
        for (index, item) in items.enumerated() {
            let y = sidebar.maxY - 92 - CGFloat(index) * 34
            let rect = NSRect(x: sidebar.minX + 18, y: y, width: 116, height: 24)
            if index == 0 {
                let selected = NSBezierPath(roundedRect: rect, xRadius: 7, yRadius: 7)
                theme.blueSoft.setFill()
                selected.fill()
                theme.blueAccent.withAlphaComponent(0.32).setStroke()
                selected.lineWidth = 1
                selected.stroke()
            }
            drawUtilityText(item, in: NSRect(x: rect.minX + 34, y: rect.minY + 5, width: 72, height: 12), size: 10, weight: index == 0 ? .semibold : .regular, color: index == 0 ? theme.blueAccent : theme.textSecondary)
            drawUtilitySidebarGlyph(index: index, center: NSPoint(x: rect.minX + 17, y: rect.midY))
        }
    }

    private func drawUtilitySidebarGlyph(index: Int, center: NSPoint) {
        let color = index == 0 ? theme.blueAccent : theme.textSecondary
        let path = NSBezierPath()
        switch index {
        case 0:
            path.appendOval(in: NSRect(x: center.x - 5, y: center.y - 5, width: 10, height: 10))
        case 1:
            path.move(to: NSPoint(x: center.x - 5, y: center.y - 4))
            path.line(to: NSPoint(x: center.x + 5, y: center.y + 4))
        case 2:
            path.move(to: NSPoint(x: center.x - 6, y: center.y))
            path.line(to: NSPoint(x: center.x - 2, y: center.y))
            path.line(to: NSPoint(x: center.x, y: center.y + 5))
            path.line(to: NSPoint(x: center.x + 2, y: center.y - 5))
            path.line(to: NSPoint(x: center.x + 5, y: center.y))
        default:
            path.move(to: NSPoint(x: center.x - 5, y: center.y - 4))
            path.line(to: NSPoint(x: center.x + 5, y: center.y - 4))
            path.move(to: NSPoint(x: center.x - 5, y: center.y))
            path.line(to: NSPoint(x: center.x + 5, y: center.y))
            path.move(to: NSPoint(x: center.x - 5, y: center.y + 4))
            path.line(to: NSPoint(x: center.x + 5, y: center.y + 4))
        }
        path.lineWidth = 1.3
        color.withAlphaComponent(0.88).setStroke()
        path.stroke()
    }

    private func drawUtilityCircuitMotif(in panel: NSRect) {
        let color = theme.panelBorder.withAlphaComponent(0.48)
        let paths: [[NSPoint]] = [
            [NSPoint(x: panel.maxX - 88, y: panel.maxY - 70), NSPoint(x: panel.maxX - 42, y: panel.maxY - 70), NSPoint(x: panel.maxX - 42, y: panel.maxY - 120)],
            [NSPoint(x: panel.maxX - 112, y: panel.minY + 92), NSPoint(x: panel.maxX - 70, y: panel.minY + 92), NSPoint(x: panel.maxX - 70, y: panel.minY + 58), NSPoint(x: panel.maxX - 36, y: panel.minY + 58)],
            [NSPoint(x: panel.minX + 36, y: panel.minY + 68), NSPoint(x: panel.minX + 82, y: panel.minY + 68), NSPoint(x: panel.minX + 82, y: panel.minY + 36)],
        ]
        for points in paths {
            drawUtilityCircuitPath(points, color: color)
        }
    }

    private func drawUtilityCircuitPath(_ points: [NSPoint], color: NSColor) {
        guard let first = points.first else {
            return
        }
        let path = NSBezierPath()
        path.move(to: first)
        for point in points.dropFirst() {
            path.line(to: point)
        }
        path.lineWidth = 0.9
        color.setStroke()
        path.stroke()
        for point in points {
            let node = NSBezierPath(ovalIn: NSRect(x: point.x - 2, y: point.y - 2, width: 4, height: 4))
            color.withAlphaComponent(0.72).setStroke()
            node.lineWidth = 0.8
            node.stroke()
        }
    }

    private func drawUtilityLogoMark(in rect: NSRect, color: NSColor) {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: rect.maxX - 7, y: rect.minY + 7))
        path.line(to: NSPoint(x: rect.minX + 11, y: rect.minY + 7))
        path.line(to: NSPoint(x: rect.minX + 5, y: rect.midY))
        path.line(to: NSPoint(x: rect.minX + 11, y: rect.maxY - 7))
        path.line(to: NSPoint(x: rect.maxX - 7, y: rect.maxY - 7))
        path.lineWidth = 1.4
        color.setStroke()
        path.stroke()
        for point in [
            NSPoint(x: rect.maxX - 4, y: rect.minY + 7),
            NSPoint(x: rect.maxX - 4, y: rect.maxY - 7),
            NSPoint(x: rect.minX + 5, y: rect.midY),
        ] {
            let dot = NSBezierPath(ovalIn: NSRect(x: point.x - 2, y: point.y - 2, width: 4, height: 4))
            color.setFill()
            dot.fill()
        }
    }

    private func drawUtilityText(_ text: String, in rect: NSRect, size: CGFloat, weight: NSFont.Weight, color: NSColor) {
        (text as NSString).draw(
            in: rect,
            withAttributes: [
                .font: NSFont.systemFont(ofSize: size, weight: weight),
                .foregroundColor: color,
            ]
        )
    }
}

private struct SignalConsoleModel {
    let planName: String
    let sourcePill: String
    let stateTitle: String
    let stateDetail: String
    let statusTitle: String
    let statusDetail: String
    let fiveHourLeft: Int?
    let sevenDayLeft: Int?
    let fiveHourResetText: String
    let sevenDayResetText: String
    let lastRefreshText: String
    let liveAgeText: String
    let nextRefreshText: String
    let source: String?
    let isUnavailable: Bool
    let isRefreshing: Bool
}

private final class SignalConsolePanelView: NSView {
    private var model: SignalConsoleModel
    private var theme: SignalConsoleTheme
    private weak var target: AnyObject?
    private let openCodexAction: Selector
    private let refreshAction: Selector
    private let preferencesAction: Selector
    private let quitAction: Selector

    override var isFlipped: Bool {
        true
    }

    init(
        frame frameRect: NSRect,
        model: SignalConsoleModel,
        theme: SignalConsoleTheme,
        target: AnyObject,
        openCodexAction: Selector,
        refreshAction: Selector,
        preferencesAction: Selector,
        quitAction: Selector
    ) {
        self.model = model
        self.theme = theme
        self.target = target
        self.openCodexAction = openCodexAction
        self.refreshAction = refreshAction
        self.preferencesAction = preferencesAction
        self.quitAction = quitAction
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        addSignalConsoleButtons()
        updateAccessibility()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        drawSignalConsolePanel()
    }

    func update(model: SignalConsoleModel) {
        self.model = model
        updateAccessibility()
        needsDisplay = true
    }

    func apply(theme: SignalConsoleTheme) {
        self.theme = theme
        for case let button as NSButton in subviews {
            let primary = button.title == "Open ChatGPT"
            button.layer?.backgroundColor = (primary ? morandiQuotaBlue : theme.commandButtonBackground).cgColor
            button.contentTintColor = theme.textPrimary
            if primary {
                button.attributedTitle = NSAttributedString(
                    string: button.title,
                    attributes: textAttributes(size: 13, weight: .semibold, color: theme.buttonPrimaryText, alignment: .center)
                )
            }
        }
        needsDisplay = true
    }

    private func updateAccessibility() {
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("Codex Gauge quota")
        setAccessibilityValue(
            "5-hour \(percentText(model.fiveHourLeft)) left, resets \(model.fiveHourResetText). "
                + "7-day \(percentText(model.sevenDayLeft)) left, resets \(model.sevenDayResetText). "
                + "Next refresh \(model.nextRefreshText)."
        )
    }

    private func addSignalConsoleButtons() {
        let layout = SignalConsoleLayout(bounds: bounds)
        let iconRects = layout.iconButtonRects
        addButton(title: "Open ChatGPT", frame: layout.openChatGPTButtonRect, action: openCodexAction, style: .primary)
        addIconButton(symbol: "arrow.clockwise", label: "Refresh now", frame: iconRects[0], action: refreshAction)
        addIconButton(symbol: "gearshape", label: "Preferences", frame: iconRects[1], action: preferencesAction)
        addIconButton(symbol: "power", label: "Quit Codex Gauge", frame: iconRects[2], action: quitAction)
    }

    private enum SignalButtonStyle {
        case primary
        case secondary
        case command
    }

    private func addButton(title: String, frame: NSRect, action: Selector, style: SignalButtonStyle) {
        let button = NSButton(title: title, target: target, action: action)
        button.frame = frame
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.cornerRadius = 7
        button.layer?.backgroundColor = buttonBackground(style).cgColor
        button.attributedTitle = NSAttributedString(
            string: title,
            attributes: textAttributes(
                size: 13,
                weight: style == .primary ? .semibold : .medium,
                color: buttonTextColor(style),
                alignment: .center
            )
        )
        button.alignment = .center
        addSubview(button)
    }

    private func addIconButton(symbol: String, label: String, frame: NSRect, action: Selector) {
        let button = NSButton(frame: frame)
        button.target = target
        button.action = action
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.cornerRadius = 7
        button.layer?.backgroundColor = theme.commandButtonBackground.cgColor
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        button.imagePosition = .imageOnly
        button.contentTintColor = textPrimary
        button.toolTip = label
        button.setAccessibilityLabel(label)
        addSubview(button)
    }

    private func buttonBackground(_ style: SignalButtonStyle) -> NSColor {
        switch style {
        case .primary:
            return morandiQuotaBlue
        case .secondary:
            return theme.secondaryButtonBackground
        case .command:
            return theme.commandButtonBackground
        }
    }

    private func buttonTextColor(_ style: SignalButtonStyle) -> NSColor {
        switch style {
        case .primary:
            return theme.buttonPrimaryText
        case .secondary, .command:
            return textPrimary
        }
    }

    private func drawSignalConsolePanel() {
        drawPanelBackground()
        drawHeader()
        drawSignalHeroCard()
        drawStatusStrip()
    }

    private func drawPanelBackground() {
        let layout = SignalConsoleLayout(bounds: bounds)
        let rect = layout.panelRect
        panelBackground.setFill()
        rect.fill()
        let wash = NSBezierPath(rect: NSRect(x: rect.minX, y: rect.minY, width: rect.width, height: 48))
        NSGradient(colors: [panelStrongBackground, panelBackground])?.draw(in: wash, angle: 90)
    }

    private func drawPanelAccentRail() {
        let layout = SignalConsoleLayout(bounds: bounds)
        let rect = layout.panelRect
        let rail = NSRect(x: rect.minX + 38, y: rect.minY + 8, width: rect.width - 76, height: 2.4)
        drawRoundedGradient(
            rail,
            radius: 1.2,
            gradient: NSGradient(colors: [
                blueAccent.withAlphaComponent(0.22),
                mintAccent.withAlphaComponent(0.48),
                amberAccent.withAlphaComponent(0.30),
            ]),
            stroke: nil
        )
    }

    private func drawHeader() {
        let layout = SignalConsoleLayout(bounds: bounds)
        let title = layout.headerTitleRect
        let status = layout.headerStatusRect
        drawText("Codex Gauge", x: title.minX, y: title.minY, width: 118, height: title.height, size: 16, weight: .semibold, color: textPrimary)
        drawText(model.planName, x: title.minX + 124, y: title.minY + 3, width: 96, height: 18, size: 10, weight: .medium, color: textMuted)
        let stateColor = sourceColor(source: model.source, unavailable: model.isUnavailable)
        drawCircle(center: NSPoint(x: status.minX + 7, y: status.midY), radius: 3.5, color: stateColor, stroke: nil)
        drawText(headerSignalText(), x: status.minX + 16, y: status.minY + 2, width: status.width - 16, height: 16, size: 11, weight: .semibold, color: stateColor)
        drawInstrumentDivider(y: 48, xInset: 18)
    }

    private func drawStatusStrip() {
        let layout = SignalConsoleLayout(bounds: bounds)
        let stateColor = sourceColor(source: model.source, unavailable: model.isUnavailable)
        let freshness = model.isUnavailable ? model.stateDetail : "Updated \(model.liveAgeText)"
        drawCircle(center: NSPoint(x: layout.freshnessRect.minX + 4, y: layout.freshnessRect.midY), radius: 2.8, color: stateColor, stroke: nil)
        drawText(freshness, x: layout.freshnessRect.minX + 12, y: layout.freshnessRect.minY + 2, width: layout.freshnessRect.width - 12, height: 16, size: 10.5, weight: .medium, color: textSecondary)
        drawText("Next \(model.nextRefreshText)", x: layout.nextRefreshRect.minX, y: layout.nextRefreshRect.minY + 2, width: layout.nextRefreshRect.width, height: 16, size: 10.5, weight: .medium, color: textMuted, mono: true, alignment: .right)
        drawInstrumentDivider(y: 214, xInset: 18)
    }

    private func drawClosedSignalState(in rect: NSRect) {
        drawRoundedRect(rect, radius: rect.height / 2, fill: amberSoft, stroke: panelBorder.withAlphaComponent(0.26))
        drawCircle(center: NSPoint(x: rect.minX + 14, y: rect.midY), radius: 3.5, color: amberAccent, stroke: nil)
        drawText("No live quota yet", x: rect.minX + 24, y: rect.minY + 7, width: rect.width - 32, height: 14, size: 9, weight: .medium, color: textPrimary)
    }

    private func drawSignalHeroCard() {
        let layout = SignalConsoleLayout(bounds: bounds)
        drawQuotaWindowRow(
            window: "5h",
            label: "5-hour quota",
            value: model.fiveHourLeft,
            resetText: model.fiveHourResetText,
            rect: layout.fiveHourQuotaRowRect
        )
        drawInstrumentDivider(y: 123, xInset: 18)
        drawQuotaWindowRow(
            window: "7d",
            label: "7-day quota",
            value: model.sevenDayLeft,
            resetText: model.sevenDayResetText,
            rect: layout.sevenDayQuotaRowRect
        )
    }

    private func drawQuotaWindowRow(window: String, label: String, value: Int?, resetText: String, rect: NSRect) {
        drawText(window, x: rect.minX, y: rect.minY + 3, width: 30, height: 20, size: 15, weight: .bold, color: textPrimary, mono: true)
        drawText(percentText(value), x: rect.minX + 38, y: rect.minY, width: 62, height: 24, size: 18, weight: .bold, color: value == nil ? textMuted : quotaColor(value), mono: true)
        drawText(label, x: rect.minX + 102, y: rect.minY + 5, width: 92, height: 16, size: 10.5, weight: .medium, color: textSecondary)
        drawText("resets \(resetText)", x: rect.maxX - 116, y: rect.minY + 5, width: 116, height: 16, size: 10.5, weight: .medium, color: resetTextColor(resetText), mono: true, alignment: .right)
        drawQuotaRail(value: value, rect: NSRect(x: rect.minX, y: rect.minY + 34, width: rect.width, height: 8))
    }

    private func drawInstrumentRowBaseline(_ rect: NSRect) {
        let rules = NSBezierPath()
        rules.move(to: NSPoint(x: rect.minX, y: rect.minY + 1))
        rules.line(to: NSPoint(x: rect.maxX, y: rect.minY + 1))
        rules.move(to: NSPoint(x: rect.minX, y: rect.maxY - 1))
        rules.line(to: NSPoint(x: rect.maxX, y: rect.maxY - 1))
        rules.move(to: NSPoint(x: rect.minX + 58, y: rect.minY + 10))
        rules.line(to: NSPoint(x: rect.minX + 58, y: rect.maxY - 10))
        rules.move(to: NSPoint(x: rect.minX + 274, y: rect.minY + 10))
        rules.line(to: NSPoint(x: rect.minX + 274, y: rect.maxY - 10))
        rules.lineWidth = 0.8
        panelBorder.withAlphaComponent(0.44).setStroke()
        rules.stroke()
    }

    private func drawTrendSparkline(values: [Int], rect: NSRect) {
        let baseline = NSBezierPath()
        baseline.move(to: NSPoint(x: rect.minX, y: rect.midY + 6))
        baseline.line(to: NSPoint(x: rect.maxX, y: rect.midY + 6))
        baseline.lineWidth = 1
        baseline.setLineDash([5, 5], count: 2, phase: 0)
        theme.baselineStroke.setStroke()
        baseline.stroke()

        guard !values.isEmpty else {
            return
        }
        let shown = Array(values.suffix(24))
        let gap: CGFloat = 2
        let barWidth = max(2, (rect.width - gap * CGFloat(shown.count - 1)) / CGFloat(shown.count))
        for (index, value) in shown.enumerated() {
            let height = max(2, rect.height * CGFloat(max(0, min(100, value))) / 100)
            let x = rect.minX + CGFloat(index) * (barWidth + gap)
            let bar = NSRect(x: x, y: rect.maxY - height, width: barWidth, height: height)
            let alpha = 0.22 + 0.18 * CGFloat(index + 1) / CGFloat(shown.count)
            let color = trendBarColor(value: value).withAlphaComponent(alpha)
            drawRoundedRect(bar, radius: 1, fill: color, stroke: nil)
        }
    }

    private func trendBarColor(value: Int) -> NSColor {
        return quotaColor(value)
    }

    private func trendDeltaTextColor(values: [Int]) -> NSColor {
        guard let first = values.first, let last = values.last else {
            return textMuted
        }
        let delta = last - first
        if delta <= -2 {
            return coralAccent
        }
        if delta >= 2 {
            return mintAccent
        }
        return textMuted
    }

    private func drawSectionLabel(_ text: String, y: CGFloat) {
        drawText(text, x: 28, y: y, width: 92, height: 24, size: 15, weight: .semibold, color: textSecondary)
    }

    private func drawDivider(y: CGFloat) {
        drawInstrumentDivider(y: y)
    }

    private func drawInstrumentDivider(y: CGFloat, xInset: CGFloat = 28) {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: xInset, y: y))
        path.line(to: NSPoint(x: bounds.width - xInset, y: y))
        path.lineWidth = 1
        panelBorder.withAlphaComponent(0.58).setStroke()
        path.stroke()
    }

    private func drawCircuitLogoMark(in rect: NSRect, color: NSColor) {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: rect.maxX - 6, y: rect.minY + 6))
        path.line(to: NSPoint(x: rect.minX + 10, y: rect.minY + 6))
        path.line(to: NSPoint(x: rect.minX + 4, y: rect.midY))
        path.line(to: NSPoint(x: rect.minX + 10, y: rect.maxY - 6))
        path.line(to: NSPoint(x: rect.maxX - 6, y: rect.maxY - 6))
        path.lineWidth = 1.5
        color.setStroke()
        path.stroke()

        let inner = NSBezierPath()
        inner.move(to: NSPoint(x: rect.maxX - 11, y: rect.minY + 11))
        inner.line(to: NSPoint(x: rect.minX + 15, y: rect.minY + 11))
        inner.line(to: NSPoint(x: rect.minX + 10, y: rect.midY))
        inner.line(to: NSPoint(x: rect.minX + 15, y: rect.maxY - 11))
        inner.line(to: NSPoint(x: rect.maxX - 11, y: rect.maxY - 11))
        inner.lineWidth = 0.9
        color.withAlphaComponent(0.56).setStroke()
        inner.stroke()

        for point in [
            NSPoint(x: rect.maxX - 4, y: rect.minY + 6),
            NSPoint(x: rect.maxX - 4, y: rect.maxY - 6),
            NSPoint(x: rect.minX + 4, y: rect.midY),
        ] {
            drawCircle(center: point, radius: 2, color: color, stroke: nil)
        }
    }

    private func drawCircuitTraceMotif(in rect: NSRect, color: NSColor) {
        let paths: [[NSPoint]] = [
            [NSPoint(x: rect.minX, y: rect.midY), NSPoint(x: rect.minX + rect.width * 0.34, y: rect.midY), NSPoint(x: rect.minX + rect.width * 0.34, y: rect.minY + rect.height * 0.28), NSPoint(x: rect.maxX, y: rect.minY + rect.height * 0.28)],
            [NSPoint(x: rect.minX + rect.width * 0.18, y: rect.minY + rect.height * 0.75), NSPoint(x: rect.minX + rect.width * 0.58, y: rect.minY + rect.height * 0.75), NSPoint(x: rect.minX + rect.width * 0.58, y: rect.maxY)],
            [NSPoint(x: rect.minX + rect.width * 0.30, y: rect.minY), NSPoint(x: rect.minX + rect.width * 0.30, y: rect.minY + rect.height * 0.48), NSPoint(x: rect.maxX, y: rect.minY + rect.height * 0.48)],
        ]
        for points in paths {
            drawCircuitPath(points, color: color)
        }
    }

    private func drawCircuitPath(_ points: [NSPoint], color: NSColor) {
        guard let first = points.first else {
            return
        }
        let path = NSBezierPath()
        path.move(to: first)
        for point in points.dropFirst() {
            path.line(to: point)
        }
        path.lineWidth = 0.8
        color.setStroke()
        path.stroke()
        for point in points {
            drawCircle(center: point, radius: 1.7, color: panelBackground.withAlphaComponent(0.1), stroke: color.withAlphaComponent(0.74))
        }
    }

    private func drawChevron(in rect: NSRect, color: NSColor) {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: rect.minX, y: rect.minY))
        path.line(to: NSPoint(x: rect.maxX, y: rect.midY))
        path.line(to: NSPoint(x: rect.minX, y: rect.maxY))
        path.lineWidth = 1.7
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        color.withAlphaComponent(0.82).setStroke()
        path.stroke()
    }

    private func drawPill(text: String, rect: NSRect, color: NSColor, dotColor: NSColor? = nil) {
        drawRoundedRect(rect, radius: rect.height / 2, fill: color, stroke: panelBorder.withAlphaComponent(0.42))
        if let dotColor {
            drawCircle(center: NSPoint(x: rect.minX + 13, y: rect.midY), radius: 3.5, color: dotColor, stroke: nil)
            drawText(text, x: rect.minX + 22, y: rect.minY + 4, width: rect.width - 30, height: rect.height - 8, size: 12, weight: .regular, color: textSecondary)
        } else {
            drawText(text, x: rect.minX + 10, y: rect.minY + 4, width: rect.width - 20, height: rect.height - 8, size: 12, weight: .regular, color: textSecondary)
        }
    }

    private func drawQuotaRail(value: Int?, rect: NSRect) {
        drawRoundedRect(rect, radius: rect.height / 2, fill: theme.trackFill, stroke: nil)
        guard let value else {
            return
        }
        let fillWidth = max(rect.height, rect.width * clamped(value))
        let fillRect = NSRect(x: rect.minX, y: rect.minY, width: min(rect.width, fillWidth), height: rect.height)
        let gradient = quotaFillGradient(value: value)
        drawRoundedGradient(fillRect, radius: rect.height / 2, gradient: gradient, stroke: nil)
    }

    private func quotaFillGradient(value: Int) -> NSGradient? {
        if value < 10 {
            return NSGradient(colors: [coralAccent, theme.quotaLowEnd])
        }
        if value < 25 {
            return NSGradient(colors: [amberAccent, amberAccent])
        }
        return NSGradient(colors: [morandiQuotaBlue, morandiQuotaBlue])
    }

    private func drawWrappedText(_ text: String, rect: NSRect, size: CGFloat, weight: NSFont.Weight, color: NSColor) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = 1.5
        (text as NSString).draw(
            in: rect,
            withAttributes: [
                .font: NSFont.systemFont(ofSize: size, weight: weight),
                .foregroundColor: color,
                .paragraphStyle: paragraph,
            ]
        )
    }

    private func drawRoundedGradient(_ rect: NSRect, radius: CGFloat, gradient: NSGradient?, stroke: NSColor?) {
        let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        gradient?.draw(in: path, angle: 0)
        if let stroke {
            stroke.setStroke()
            path.lineWidth = 1
            path.stroke()
        }
    }

    private func headerSignalText() -> String {
        model.isUnavailable ? "Unavailable" : (model.isRefreshing ? "Refreshing" : "Live")
    }

    private func headerSignalColor() -> NSColor {
        sourceColor(source: model.source, unavailable: model.isUnavailable)
    }

    private func statusStripDetail() -> String {
        if model.isUnavailable {
            return "Open ChatGPT for live quota"
        }
        if model.isRefreshing {
            return "Refreshing quota now."
        }
        return "Live \(model.liveAgeText) · refreshes every 5 min"
    }

    private func shortTrendText(_ text: String) -> String {
        if text.localizedCaseInsensitiveContains("stable") {
            return "steady"
        }
        if text.localizedCaseInsensitiveContains("collecting") {
            return "collecting"
        }
        return text
            .replacingOccurrences(of: "this window", with: "")
            .replacingOccurrences(of: "in 24h", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func trendSignalText(values: [Int], fallback: String) -> String {
        guard values.count >= 2, let first = values.first, let last = values.last else {
            let fallbackText = shortTrendText(fallback)
            if fallbackText.localizedCaseInsensitiveContains("no data") || fallbackText.isEmpty {
                return "collecting"
            }
            return fallbackText
        }
        let delta = last - first
        if abs(delta) < 2 {
            return "steady"
        }
        return delta > 0 ? "+\(delta)%" : "\(delta)%"
    }

    private func trendSignalColor(values: [Int]) -> NSColor {
        guard values.count >= 2, let first = values.first, let last = values.last else {
            return textSecondary
        }
        let delta = last - first
        if delta <= -2 {
            return coralAccent
        }
        if delta >= 2 {
            return mintAccent
        }
        return textSecondary
    }

    private func drawSegmentedRail(value: Int?, rect: NSRect, fill: NSColor, segments: Int) {
        let gap: CGFloat = 2
        let segmentWidth = max(2, (rect.width - gap * CGFloat(segments - 1)) / CGFloat(segments))
        let filled = Int(ceil(clamped(value) * CGFloat(segments)))
        for index in 0..<segments {
            let x = rect.minX + CGFloat(index) * (segmentWidth + gap)
            let segmentRect = NSRect(x: x, y: rect.minY, width: segmentWidth, height: rect.height)
            let color = index < filled ? fill : theme.trackFill
            drawRoundedRect(segmentRect, radius: min(3, rect.height / 2), fill: color, stroke: nil)
        }
    }

    private func drawRoundedRect(_ rect: NSRect, radius: CGFloat, fill: NSColor, stroke: NSColor?) {
        let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        fill.setFill()
        path.fill()
        if let stroke {
            stroke.setStroke()
            path.lineWidth = 1
            path.stroke()
        }
    }

    private func drawCircle(center: NSPoint, radius: CGFloat, color: NSColor, stroke: NSColor?) {
        let rect = NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        let path = NSBezierPath(ovalIn: rect)
        color.setFill()
        path.fill()
        if let stroke {
            stroke.setStroke()
            path.lineWidth = 1
            path.stroke()
        }
    }

    private func drawText(
        _ text: String,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat,
        size: CGFloat,
        weight: NSFont.Weight,
        color: NSColor,
        mono: Bool = false,
        alignment: NSTextAlignment = .left
    ) {
        (text as NSString).draw(
            in: NSRect(x: x, y: y, width: width, height: height),
            withAttributes: textAttributes(size: size, weight: weight, color: color, mono: mono, alignment: alignment)
        )
    }

    private func textAttributes(
        size: CGFloat,
        weight: NSFont.Weight,
        color: NSColor,
        mono: Bool = false,
        alignment: NSTextAlignment = .left
    ) -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        return [
            .font: mono ? NSFont.monospacedDigitSystemFont(ofSize: size, weight: weight) : NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ]
    }

    private func percentText(_ value: Int?) -> String {
        value.map { "\($0)%" } ?? "--"
    }

    private func clamped(_ value: Int?) -> CGFloat {
        guard let value else {
            return 0
        }
        return CGFloat(max(0, min(100, value))) / 100
    }

    private func trendDeltaText(_ values: [Int]) -> String {
        guard let first = values.first, let last = values.last else {
            return "collecting"
        }
        let delta = last - first
        if abs(delta) < 2 {
            return "stable"
        }
        return delta > 0 ? "+\(delta)%" : "\(delta)%"
    }

    private func quotaColor(_ value: Int?) -> NSColor {
        guard let value else {
            return textMuted
        }
        switch max(0, min(100, value)) {
        case 0..<10:
            return coralAccent
        case 10..<25:
            return amberAccent
        default:
            return morandiQuotaBlue
        }
    }

    private var morandiQuotaBlue: NSColor {
        // Sampled from the adjacent iStat Menus CPU fill block (#8696B9).
        NSColor(deviceRed: 134.0 / 255.0, green: 150.0 / 255.0, blue: 185.0 / 255.0, alpha: 1.0)
    }

    private func sourceColor(source: String?, unavailable: Bool) -> NSColor {
        _ = source
        if unavailable {
            return amberAccent
        }
        return mintAccent
    }

    private func doctorColor(_ state: String) -> NSColor {
        switch state {
        case "green":
            return mintAccent
        case "amber":
            return amberAccent
        case "red":
            return coralAccent
        default:
            return NSColor(calibratedRed: 0.47, green: 0.52, blue: 0.58, alpha: 1.0)
        }
    }

    private func doctorDetailText(_ value: String) -> String {
        switch value {
        case "Installed in Applications":
            return "Installed"
        case "Bundled helper readable":
            return "Bundled helper"
        case "Live data is current":
            return "Live data OK"
        case "Optional, off by default":
            return "Optional"
        default:
            return value
        }
    }

    private func healthShortLabel(_ title: String) -> String {
        switch title {
        case "ChatGPT app found":
            return "ChatGPT"
        case "Helper works":
            return "Helper"
        case "Live data available":
            return "Live"
        case "Session storage":
            return "Store"
        case "Notifications permission":
            return "Alerts"
        default:
            return title
        }
    }

    private func resetTextColor(_ value: String) -> NSColor {
        value == "--" ? textMuted : textPrimary
    }

    private var panelBackground: NSColor {
        theme.panelBackground
    }

    private var activeSignalConsoleTheme: SignalConsoleTheme {
        theme
    }

    private var panelStrongBackground: NSColor {
        theme.panelStrongBackground
    }

    private var panelSoftBackground: NSColor {
        theme.panelSoftBackground
    }

    private var cardBackground: NSColor {
        panelSoftBackground
    }

    private var panelBorder: NSColor {
        theme.panelBorder
    }

    private var textPrimary: NSColor {
        theme.textPrimary
    }

    private var textSecondary: NSColor {
        theme.textSecondary
    }

    private var textMuted: NSColor {
        theme.textMuted
    }

    private var mintAccent: NSColor {
        theme.mintAccent
    }

    private var amberAccent: NSColor {
        theme.amberAccent
    }

    private var coralAccent: NSColor {
        theme.coralAccent
    }

    private var blueAccent: NSColor {
        theme.blueAccent
    }

    private var mintSoft: NSColor {
        theme.mintSoft
    }

    private var amberSoft: NSColor {
        theme.amberSoft
    }

    private var coralSoft: NSColor {
        theme.coralSoft
    }

    private var blueSoft: NSColor {
        theme.blueSoft
    }
}

private let renderedSignalConsoleFixtureDirectory = "docs/design/app-rendered-signal-console"

private final class SignalConsolePreviewTarget: NSObject {
    @objc func noop(_ sender: Any?) {}
}

private struct SignalConsolePreviewCase {
    let filename: String
    let theme: SignalConsoleTheme
    let model: SignalConsoleModel
}

private func renderSignalConsoleFixtures(outputDirectory: String? = nil) throws {
    _ = NSApplication.shared
    let outputURL = URL(fileURLWithPath: outputDirectory ?? renderedSignalConsoleFixtureDirectory, isDirectory: true)
    try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
    for item in try FileManager.default.contentsOfDirectory(at: outputURL, includingPropertiesForKeys: nil) where item.pathExtension == "png" {
        try FileManager.default.removeItem(at: item)
    }

    for previewCase in signalConsolePreviewCases() {
        let image = try renderSignalConsolePanel(model: previewCase.model, theme: previewCase.theme)
        guard let data = image.tiffRepresentation,
              let representation = NSBitmapImageRep(data: data),
              let png = representation.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "CodexGaugePreview", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not encode \(previewCase.filename)"])
        }
        try png.write(to: outputURL.appendingPathComponent(previewCase.filename))
    }
}

private func renderSignalConsolePanel(model: SignalConsoleModel, theme: SignalConsoleTheme) throws -> NSImage {
    let target = SignalConsolePreviewTarget()
    let panel = SignalConsolePanelView(
        frame: NSRect(origin: .zero, size: NSSize(width: 380, height: 272)),
        model: model,
        theme: theme,
        target: target,
        openCodexAction: #selector(SignalConsolePreviewTarget.noop(_:)),
        refreshAction: #selector(SignalConsolePreviewTarget.noop(_:)),
        preferencesAction: #selector(SignalConsolePreviewTarget.noop(_:)),
        quitAction: #selector(SignalConsolePreviewTarget.noop(_:))
    )
    panel.layoutSubtreeIfNeeded()
    panel.displayIfNeeded()
    guard let bitmap = panel.bitmapImageRepForCachingDisplay(in: panel.bounds) else {
        throw NSError(domain: "CodexGaugePreview", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not allocate preview bitmap"])
    }
    panel.cacheDisplay(in: panel.bounds, to: bitmap)
    let image = NSImage(size: panel.bounds.size)
    image.addRepresentation(bitmap)
    return image
}

private func signalConsolePreviewCases() -> [SignalConsolePreviewCase] {
    let themes: [(slug: String, theme: SignalConsoleTheme)] = [
        ("blue-ceramic", blueCeramicTheme()),
        ("signal-dark", signalDarkTheme()),
        ("mono-graphite", monoGraphiteTheme()),
    ]
    let states: [(slug: String, model: SignalConsoleModel)] = [
        ("live", signalConsolePreviewModel(
            title: "Live",
            detail: "Current",
            statusTitle: "Live data is current",
            statusDetail: "Read from local Codex app-server",
            fiveHourLeft: 82,
            sevenDayLeft: 76,
            fiveHourResetText: "4h59m",
            sevenDayResetText: "6d23h",
            source: "live",
            unavailable: false
        )),
        ("codex-closed", signalConsolePreviewModel(
            title: "ChatGPT unavailable",
            detail: "Open ChatGPT",
            statusTitle: "Open ChatGPT once to enable live usage",
            statusDetail: "After ChatGPT is open, Codex Gauge refreshes hands-free from the menu bar.",
            fiveHourLeft: nil,
            sevenDayLeft: nil,
            fiveHourResetText: "--",
            sevenDayResetText: "--",
            source: nil,
            unavailable: true
        )),
        ("low-quota", signalConsolePreviewModel(
            title: "Live",
            detail: "Current",
            statusTitle: "Live data is current",
            statusDetail: "Read from local Codex app-server",
            fiveHourLeft: 9,
            sevenDayLeft: 44,
            fiveHourResetText: "38m",
            sevenDayResetText: "2d4h",
            source: "live",
            unavailable: false
        )),
        ("reset-soon", signalConsolePreviewModel(
            title: "Live",
            detail: "Reset soon",
            statusTitle: "Reset countdown visible",
            statusDetail: "Minute-level 5-hour countdown stays readable in the menu bar.",
            fiveHourLeft: 80,
            sevenDayLeft: 79,
            fiveHourResetText: "59m",
            sevenDayResetText: "6d20h",
            source: "live",
            unavailable: false
        )),
    ]

    return themes.flatMap { item in
        states.map { state in
            SignalConsolePreviewCase(filename: "\(item.slug)-\(state.slug).png", theme: item.theme, model: state.model)
        }
    }
}

private func signalConsolePreviewModel(
    title: String,
    detail: String,
    statusTitle: String,
    statusDetail: String,
    fiveHourLeft: Int?,
    sevenDayLeft: Int?,
    fiveHourResetText: String,
    sevenDayResetText: String,
    source: String?,
    unavailable: Bool
) -> SignalConsoleModel {
    return SignalConsoleModel(
        planName: unavailable ? "Live only" : "Codex Pro",
        sourcePill: "Source: Menu Bar",
        stateTitle: title,
        stateDetail: detail,
        statusTitle: statusTitle,
        statusDetail: statusDetail,
        fiveHourLeft: fiveHourLeft,
        sevenDayLeft: sevenDayLeft,
        fiveHourResetText: fiveHourResetText,
        sevenDayResetText: sevenDayResetText,
        lastRefreshText: unavailable ? "none" : "21:12",
        liveAgeText: unavailable ? "unknown" : "2m ago",
        nextRefreshText: unavailable ? "1:00" : "4:58",
        source: source,
        isUnavailable: unavailable,
        isRefreshing: false
    )
}

private final class CodexGaugeApp: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let runtimeLogQueue = DispatchQueue(label: "app.codexgauge.runtime-log", qos: .utility)
    private let menu = NSMenu()
    private var signalPopover: NSPopover?
    private weak var signalConsolePanelView: SignalConsolePanelView?
    private var timer: Timer?
    private var animationTimer: Timer?
    private var popoverCountdownTimer: Timer?
    private var preferencesWindow: NSWindow?
    private var setupDoctorWindow: NSWindow?
    private var firstRunSetupWindow: NSWindow?
    private var firstRunSetupPopover: NSPopover?
    private var refreshPopup: NSPopUpButton?
    private var themePopup: NSPopUpButton?
    private var notificationsCheckbox: NSButton?
    private var launchAtLoginCheckbox: NSButton?
    private var snapshot: UsageSnapshot?
    private var lastError: String?
    private var isRefreshing = false
    private var activeRefreshProcess: Process?
    private var refreshGeneration = 0
    private var allowTermination = false
    private var activity: NSObjectProtocol?
    private var moodPulseStep = 0
    private var previousFiveHourLeft: Int?
    private var nextRefreshAt: Date?
    private var liveUnavailableSince: Date?
    private var didNotifyLiveUnavailable = false
    private var resetHighlightUntil: Date?
    private var isCheckingForUpdates = false
    private var isInstallingUpdate = false
    private var lastUpdateSummary: String?
    private var automaticUpdateTimer: Timer?
    private var automaticUpdateCheckDidRun = false
    private var automaticUpdateSkippedTagName: String?
    private var runtimeLogMessages: [String] = []
    private var sessionSignalConsoleThemeKey = blueCeramicThemeKey
    private var sessionRefreshMode = "adaptive"
    private var sessionNotificationsEnabled = false
    private let moodAnimationFrameLimit = 8
    private let normalRefreshInterval: TimeInterval = 5 * 60
    private let watchRefreshInterval: TimeInterval = 3 * 60
    private let criticalRefreshInterval: TimeInterval = 2 * 60
    private let recoveryRefreshInterval: TimeInterval = 60
    private let tenMinuteRefreshInterval: TimeInterval = 10 * 60
    private let refreshTimeout: TimeInterval = 35
    private let maximumStaleDisplayAge: TimeInterval = 10 * 60
    private let statusItemWidth: CGFloat = 94
    private var currentStatusImageScale: CGFloat = 2.0
    private var statusItemStatus: ServiceStatus?
    private lazy var statusItemView = CodexGaugeStatusItemView(
        frame: NSRect(x: 0, y: 0, width: statusItemWidth, height: NSStatusBar.system.thickness)
    )
    private let menuBarUsagePercentRect = NSRect(x: 2, y: 3, width: 54, height: 16)
    private let menuBarHorizontalRailRect = NSRect(x: 46, y: 3, width: 22, height: 16)
    private let menuBarRefreshCountdownRect = NSRect(x: 69, y: 2, width: 24, height: 18)
    private let signalPopoverSize = NSSize(width: 380, height: 272)
    private let quotaRailSize = NSSize(width: 22, height: 5)
    private let signalRailSegments = 10
    private let codexHostBundleIdentifier = "com.openai.codex"
    private let bundledCodexCliSuffix = "Contents/Resources/codex"
    private let codexHostFallbackPaths = [
        "/Applications/ChatGPT.app",
        NSHomeDirectory() + "/Applications/ChatGPT.app",
        "/Applications/Codex.app",
        NSHomeDirectory() + "/Applications/Codex.app",
    ]
    private let normalQuotaColor = NSColor(calibratedRed: 0.58, green: 1.00, blue: 0.89, alpha: 0.95)
    private let warningQuotaColor = NSColor(calibratedRed: 1.00, green: 0.74, blue: 0.34, alpha: 0.96)
    private let criticalQuotaColor = NSColor(calibratedRed: 1.00, green: 0.34, blue: 0.40, alpha: 0.96)
    private let fiveHourMenuLabel = "5-hour left"
    private let sevenDayMenuLabel = "7-day left"
    private let liveRefreshMenuLabel = "Live · refreshed"
    private let fiveHourResetMenuLabel = "5h resets"
    private let sevenDayResetMenuLabel = "7d resets"
    private let launchAgentLabel = "app.codexgauge.menubar"
    private let launchAgentPlistName = "app.codexgauge.menubar.plist"
    private let latestReleaseAPIURL = "https://api.github.com/repos/qingzhangeddie-byte/codex-gauge/releases/latest"
    private let refreshModeKey = "refreshMode"
    private let notificationsEnabledKey = "notificationsEnabled"
    private let launchAtLoginKey = "launchAtLogin"
    private let firstRunSetupSeenKey = "firstRunSetupSeen"
    private let adaptiveRefreshMode = "adaptive"
    private let fiveMinuteRefreshMode = "5m"
    private let tenMinuteRefreshMode = "10m"
    private let fiveHourLowNotification = "fiveHourLowNotification"
    private let fiveHourRestoredNotification = "fiveHourRestoredNotification"
    private let liveUnavailableNotification = "liveUnavailableNotification"
    private let liveUnavailableNotificationDelay: TimeInterval = 900
    private let automaticUpdateCheckDelay: TimeInterval = 2 * 60
    private let maxRuntimeLogMessages = 64

    private lazy var resourcesDir = Bundle.main.resourcePath ?? FileManager.default.currentDirectoryPath
    private lazy var pythonPath = infoString("CodexGaugePythonPath", fallback: "/usr/bin/python3")
    private lazy var appVersion = infoString("CFBundleShortVersionString", fallback: "0.9.6")
    private lazy var releaseURL = infoString("CodexGaugeReleaseURL", fallback: "https://github.com/qingzhangeddie-byte/codex-gauge/releases")
    private lazy var expectedUpdateSigningTeamID = infoString("CodexGaugeUpdateTeamID", fallback: "").trimmingCharacters(in: .whitespacesAndNewlines)
    private lazy var usagePath = resolveUsagePath()

    private var codexHostAppURL: URL? {
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: codexHostBundleIdentifier) {
            return appURL
        }
        return codexHostFallbackPaths
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
            .first { FileManager.default.fileExists(atPath: $0.path) }
    }

    private var codexCliBundlePath: String? {
        var candidates = codexHostFallbackPaths.map {
            URL(fileURLWithPath: $0, isDirectory: true)
                .appendingPathComponent(bundledCodexCliSuffix)
                .path
        }
        if let appURL = codexHostAppURL {
            candidates.insert(appURL.appendingPathComponent(bundledCodexCliSuffix).path, at: 0)
        }
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }
    private lazy var launchAgentPlistPath = NSHomeDirectory() + "/Library/LaunchAgents/" + launchAgentPlistName

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        registerDefaultPreferences()
        ProcessInfo.processInfo.disableAutomaticTermination("Codex Gauge menu bar status item")
        ProcessInfo.processInfo.disableSuddenTermination()
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.automaticTerminationDisabled, .suddenTerminationDisabled],
            reason: "Codex Gauge menu bar status item"
        )
        installStatusItemView()
        setStatusImage(title: "Codex quota")
        rebuildMenu()
        let workspaceNotifications = NSWorkspace.shared.notificationCenter
        workspaceNotifications.addObserver(
            self,
            selector: #selector(workspaceDidWake(_:)),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        workspaceNotifications.addObserver(
            self,
            selector: #selector(workspaceApplicationDidActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        refresh()
        scheduleAutomaticUpdateCheck()
    }

    func applicationWillTerminate(_ notification: Notification) {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        activeRefreshProcess?.terminate()
        timer?.invalidate()
        automaticUpdateTimer?.invalidate()
        animationTimer?.invalidate()
        popoverCountdownTimer?.invalidate()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        allowTermination ? .terminateNow : .terminateCancel
    }

    @objc private func workspaceDidWake(_ notification: Notification) {
        refresh(force: true)
    }

    @objc private func workspaceApplicationDidActivate(_ notification: Notification) {
        guard
            let runningApplication = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
            runningApplication.bundleIdentifier == codexHostBundleIdentifier
        else {
            return
        }
        refresh()
    }

    private func installStatusItemView() {
        statusItem.length = statusItemWidth
        guard let button = statusItem.button else {
            return
        }
        button.image = nil
        button.title = ""
        button.toolTip = "Codex quota"
        button.target = self
        button.action = #selector(toggleSignalConsole(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.setAccessibilityLabel("Codex Gauge")
        statusItemView.frame = button.bounds.isEmpty
            ? NSRect(x: 0, y: 0, width: statusItemWidth, height: NSStatusBar.system.thickness)
            : button.bounds
        statusItemView.autoresizingMask = [.width, .height]
        statusItemView.toolTip = "Codex quota"
        statusItemView.setAccessibilityLabel("Codex Gauge")
        statusItemView.onDraw = { [weak self] rect in
            self?.drawStatusItemView(in: rect)
        }
        statusItemView.onClick = { [weak self] _ in
            guard let self else {
                return
            }
            self.toggleSignalConsole(self.statusItem.button ?? self.statusItemView)
        }
        if statusItemView.superview !== button {
            statusItemView.removeFromSuperview()
            button.addSubview(statusItemView)
        }
    }

    @objc private func toggleSignalConsole(_ sender: Any?) {
        if let signalPopover, signalPopover.isShown {
            signalPopover.performClose(sender)
            stopPopoverCountdownTimer()
            return
        }
        showSignalConsolePopover()
    }

    private func showSignalConsolePopover() {
        refresh()
        let anchorView = statusItem.button ?? statusItemView
        let popover = signalPopover ?? NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.appearance = NSAppearance(named: currentSignalConsoleTheme().appearance)
        popover.contentSize = signalPopoverSize
        popover.contentViewController = makeSignalConsoleViewController()
        signalPopover = popover
        popover.show(relativeTo: anchorView.bounds, of: anchorView, preferredEdge: .minY)
        startPopoverCountdownTimer()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func refreshSignalPopoverIfNeeded() {
        guard signalPopover?.isShown == true else {
            return
        }
        signalConsolePanelView?.update(model: signalConsoleModel())
    }

    private func applyTimerTolerance(_ timer: Timer, interval: TimeInterval) {
        timer.tolerance = min(max(interval * 0.2, 0.05), max(0.2, min(interval * 0.5, 60)))
    }

    private func startPopoverCountdownTimer() {
        stopPopoverCountdownTimer()
        let nextTimer = Timer(timeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            guard let signalPopover = self.signalPopover, signalPopover.isShown else {
                timer.invalidate()
                self.popoverCountdownTimer = nil
                return
            }
            self.refreshSignalPopoverIfNeeded()
        }
        applyTimerTolerance(nextTimer, interval: 1.0)
        popoverCountdownTimer = nextTimer
        RunLoop.main.add(nextTimer, forMode: .common)
    }

    private func stopPopoverCountdownTimer() {
        popoverCountdownTimer?.invalidate()
        popoverCountdownTimer = nil
    }

    private func makeSignalConsoleViewController() -> NSViewController {
        let controller = NSViewController()
        let theme = currentSignalConsoleTheme()
        let visual = NSVisualEffectView(frame: NSRect(origin: .zero, size: signalPopoverSize))
        visual.material = theme.material
        visual.blendingMode = .withinWindow
        visual.state = .active
        visual.appearance = NSAppearance(named: theme.appearance)
        visual.wantsLayer = true
        visual.layer?.cornerRadius = 18
        visual.layer?.masksToBounds = true

        let panel = SignalConsolePanelView(
            frame: visual.bounds,
            model: signalConsoleModel(),
            theme: theme,
            target: self,
            openCodexAction: #selector(openCodexApp),
            refreshAction: #selector(refreshNow),
            preferencesAction: #selector(openPreferences),
            quitAction: #selector(quit)
        )
        panel.autoresizingMask = [.width, .height]
        visual.addSubview(panel)
        signalConsolePanelView = panel
        controller.view = visual
        controller.preferredContentSize = signalPopoverSize
        return controller
    }

    private func signalConsoleModel() -> SignalConsoleModel {
        let now = Date()

        if let snapshot {
            let status = snapshot.codex
            let unavailable = isUnavailableStatus(status)
            let title = signalStateTitle(status)
            let statusAgeText = relativeAgeText(status.dataTime ?? snapshot.updatedAt, now: now)
            return SignalConsoleModel(
                planName: status.ok ? planTitle(status) : "Codex Gauge",
                sourcePill: "Live only",
                stateTitle: title.title,
                stateDetail: title.detail,
                statusTitle: sourceStatusTitle(status),
                statusDetail: sourceStatusDetail(status),
                fiveHourLeft: unavailable ? nil : status.fiveHourLeft,
                sevenDayLeft: unavailable ? nil : status.sevenDayLeft,
                fiveHourResetText: unavailable ? "--" : fiveHourResetCountdown(status.fiveHourReset),
                sevenDayResetText: unavailable ? "--" : sevenDayResetCountdown(status.sevenDayReset),
                lastRefreshText: shortTime(status.dataTime ?? snapshot.updatedAt),
                liveAgeText: statusAgeText,
                nextRefreshText: nextRefreshCountdownText(now: now),
                source: status.source,
                isUnavailable: unavailable,
                isRefreshing: isRefreshing
            )
        }

        let detail = lastError == nil
            ? "After ChatGPT is open, Codex Gauge refreshes hands-free from the menu bar."
            : clipped(lastError ?? "", limit: 96)
        return SignalConsoleModel(
            planName: "Live only",
            sourcePill: "Live only",
            stateTitle: "ChatGPT unavailable",
            stateDetail: "Open ChatGPT",
            statusTitle: "Open ChatGPT once to enable live usage",
            statusDetail: detail,
            fiveHourLeft: nil,
            sevenDayLeft: nil,
            fiveHourResetText: "--",
            sevenDayResetText: "--",
            lastRefreshText: "none",
            liveAgeText: "unknown",
            nextRefreshText: nextRefreshCountdownText(now: now),
            source: nil,
            isUnavailable: true,
            isRefreshing: isRefreshing
        )
    }

    private func signalStateTitle(_ status: ServiceStatus) -> (title: String, detail: String) {
        if isUnavailableStatus(status) {
            return ("ChatGPT unavailable", "Open ChatGPT")
        }
        return ("Live", "Current")
    }

    @objc private func refreshNow() {
        timer?.invalidate()
        nextRefreshAt = nil
        refresh(force: true)
    }

    @objc private func openCodexAnalytics() {
        openURL("https://chatgpt.com/codex/cloud/settings/analytics")
    }

    @objc private func openReleases() {
        openURL(releaseURL)
    }

    private func scheduleAutomaticUpdateCheck() {
        automaticUpdateTimer?.invalidate()
        let nextTimer = Timer(timeInterval: automaticUpdateCheckDelay, repeats: false) { [weak self] _ in
            self?.performAutomaticUpdateCheckIfAllowed()
        }
        applyTimerTolerance(nextTimer, interval: automaticUpdateCheckDelay)
        automaticUpdateTimer = nextTimer
        RunLoop.main.add(nextTimer, forMode: .common)
    }

    private func performAutomaticUpdateCheckIfAllowed() {
        automaticUpdateTimer?.invalidate()
        automaticUpdateTimer = nil
        guard !automaticUpdateCheckDidRun else {
            return
        }
        guard !isCheckingForUpdates, !isInstallingUpdate else {
            automaticUpdateCheckDidRun = true
            return
        }
        automaticUpdateCheckDidRun = true
        performUpdateCheck(mode: .automatic)
    }

    @objc private func checkForUpdates() {
        automaticUpdateTimer?.invalidate()
        automaticUpdateTimer = nil
        automaticUpdateCheckDidRun = true
        performUpdateCheck(mode: .manual)
    }

    private func performUpdateCheck(mode: UpdateCheckMode) {
        guard !isCheckingForUpdates, !isInstallingUpdate else {
            if mode == .manual {
                showReportAlert(title: "Update already in progress", detail: lastUpdateSummary ?? "Codex Gauge is already checking or installing an update.")
            }
            return
        }
        isCheckingForUpdates = true
        lastUpdateSummary = "Update: checking GitHub Releases..."
        rebuildMenu()
        fetchLatestRelease { [weak self] result in
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                self.isCheckingForUpdates = false
                switch result {
                case .success(let release):
                    self.handleLatestRelease(release, mode: mode)
                case .failure(let error):
                    self.handleUpdateCheckFailure(error, mode: mode)
                }
            }
        }
    }

    private func handleUpdateCheckFailure(_ error: Error, mode: UpdateCheckMode) {
        guard mode == .manual else {
            lastUpdateSummary = "Update check unavailable"
            rebuildMenu()
            appendLog("automatic update check failed=\(error.localizedDescription)")
            return
        }
        lastUpdateSummary = "Update check failed"
        rebuildMenu()
        showReportAlert(title: "Could not check for updates", detail: clipped(error.localizedDescription, limit: 220))
    }

    private func fetchLatestRelease(completion: @escaping (Result<GitHubRelease, Error>) -> Void) {
        guard let url = URL(string: latestReleaseAPIURL) else {
            completion(.failure(updateError("The GitHub Releases API URL is invalid.")))
            return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("CodexGauge/\(appVersion)", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                completion(.failure(error))
                return
            }
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                completion(.failure(self.updateError("GitHub returned an unexpected response.")))
                return
            }
            guard let data else {
                completion(.failure(self.updateError("GitHub returned no release data.")))
                return
            }
            do {
                completion(.success(try JSONDecoder().decode(GitHubRelease.self, from: data)))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    private func handleLatestRelease(_ release: GitHubRelease, mode: UpdateCheckMode) {
        let latestVersion = normalizedVersion(release.tagName)
        guard appVersionIsNewer(latestVersion, than: appVersion), !release.draft else {
            lastUpdateSummary = "Update: current v\(appVersion)"
            rebuildMenu()
            if mode == .manual {
                showUpdateInfo(title: "Codex Gauge is up to date", release: release, asset: updateAsset(in: release), latestVersion: latestVersion)
            }
            return
        }
        guard let asset = updateAsset(in: release) else {
            lastUpdateSummary = "Update available: \(release.tagName)"
            rebuildMenu()
            if mode == .manual {
                showReportAlert(title: "Update available", detail: "Codex Gauge \(release.tagName) is available, but this release does not include a downloadable CodexGauge zip asset. The release page will open instead.")
                openURL(release.htmlURL)
            }
            return
        }
        lastUpdateSummary = "Update available: \(release.tagName)"
        rebuildMenu()
        if mode == .automatic, automaticUpdateSkippedTagName == release.tagName {
            return
        }
        showUpdatePrompt(release: release, asset: asset, latestVersion: latestVersion, mode: mode)
    }

    private func showUpdateInfo(title: String, release: GitHubRelease, asset: GitHubReleaseAsset?, latestVersion: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = releaseInfoText(release: release, asset: asset, latestVersion: latestVersion)
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Release Page")
        if alert.runModal() == .alertSecondButtonReturn {
            openURL(release.htmlURL)
        }
    }

    private func showUpdatePrompt(release: GitHubRelease, asset: GitHubReleaseAsset, latestVersion: String, mode: UpdateCheckMode) {
        let alert = NSAlert()
        alert.messageText = "Update Available"
        alert.informativeText = releaseInfoText(release: release, asset: asset, latestVersion: latestVersion)
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Install Update")
        alert.addButton(withTitle: "Skip this version")
        alert.addButton(withTitle: "Remind me later")
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            downloadAndInstallUpdate(release: release, asset: asset, latestVersion: latestVersion)
        case .alertSecondButtonReturn:
            automaticUpdateSkippedTagName = release.tagName
            lastUpdateSummary = "Update skipped: \(release.tagName)"
            rebuildMenu()
        default:
            if mode == .automatic {
                lastUpdateSummary = "Update postponed: \(release.tagName)"
                rebuildMenu()
            }
        }
    }

    private func downloadAndInstallUpdate(release: GitHubRelease, asset: GitHubReleaseAsset, latestVersion: String) {
        guard let url = URL(string: asset.browserDownloadURL), url.host == "github.com" else {
            showReportAlert(title: "Update download blocked", detail: "Codex Gauge only downloads release assets from github.com.")
            return
        }
        isInstallingUpdate = true
        lastUpdateSummary = "Update: downloading \(release.tagName)..."
        rebuildMenu()
        URLSession.shared.downloadTask(with: url) { [weak self] temporaryURL, response, error in
            guard let self else {
                return
            }
            do {
                if let error {
                    throw error
                }
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                    throw self.updateError("GitHub returned an unexpected download response.")
                }
                guard let temporaryURL else {
                    throw self.updateError("The update download did not produce a file.")
                }
                let prepared = try self.prepareDownloadedUpdate(
                    downloadedZipURL: temporaryURL,
                    release: release,
                    asset: asset,
                    latestVersion: latestVersion
                )
                DispatchQueue.main.async {
                    self.installPreparedUpdate(prepared)
                }
            } catch {
                DispatchQueue.main.async {
                    self.isInstallingUpdate = false
                    self.lastUpdateSummary = "Update failed"
                    self.rebuildMenu()
                    self.showReportAlert(title: "Update failed", detail: self.clipped(error.localizedDescription, limit: 240))
                }
            }
        }.resume()
    }

    private func prepareDownloadedUpdate(downloadedZipURL: URL, release: GitHubRelease, asset: GitHubReleaseAsset, latestVersion: String) throws -> PreparedUpdate {
        let manager = FileManager.default
        let workDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("CodexGauge-update-\(UUID().uuidString)", isDirectory: true)
        let zipURL = workDirectory.appendingPathComponent(asset.name)
        let extractDirectory = workDirectory.appendingPathComponent("extracted", isDirectory: true)
        try manager.createDirectory(at: workDirectory, withIntermediateDirectories: true)
        try manager.createDirectory(at: extractDirectory, withIntermediateDirectories: true)
        try manager.copyItem(at: downloadedZipURL, to: zipURL)
        try verifyDownloadedUpdateChecksum(zipURL, release: release, asset: asset)
        try runProcess("/usr/bin/ditto", arguments: ["-x", "-k", zipURL.path, extractDirectory.path])
        let appURL = try findDownloadedCodexGaugeApp(in: extractDirectory)
        try verifyDownloadedUpdateApp(appURL, expectedVersion: latestVersion)
        return PreparedUpdate(release: release, asset: asset, latestVersion: latestVersion, appURL: appURL, workDirectory: workDirectory)
    }

    private func findDownloadedCodexGaugeApp(in directory: URL) throws -> URL {
        let manager = FileManager.default
        guard let enumerator = manager.enumerator(at: directory, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
            throw updateError("The update archive could not be inspected.")
        }
        for case let candidate as URL in enumerator {
            if candidate.lastPathComponent == "CodexGauge.app" {
                return candidate
            }
        }
        throw updateError("The update archive did not contain CodexGauge.app.")
    }

    private func verifyDownloadedUpdateChecksum(_ zipURL: URL, release: GitHubRelease, asset: GitHubReleaseAsset) throws {
        let expectedSHA256 = try expectedSHA256(for: asset, in: release)
        let actualSHA256 = try sha256OfFile(zipURL)
        guard actualSHA256 == expectedSHA256 else {
            throw updateError("The downloaded update checksum did not match the release checksum.")
        }
    }

    private func expectedSHA256(for asset: GitHubReleaseAsset, in release: GitHubRelease) throws -> String {
        if let digest = asset.digest?.trimmingCharacters(in: .whitespacesAndNewlines),
           digest.lowercased().hasPrefix("sha256:") {
            return try parseSHA256(String(digest.dropFirst("sha256:".count)), expectedFileName: nil)
        }

        guard let checksumAsset = matchingChecksumAsset(for: asset, in: release) else {
            throw updateError("The release is missing a SHA-256 checksum asset for \(asset.name).")
        }
        guard let url = URL(string: checksumAsset.browserDownloadURL), url.host == "github.com" else {
            throw updateError("The update checksum must be downloaded from github.com.")
        }
        let data = try Data(contentsOf: url)
        guard let checksumText = String(data: data, encoding: .utf8) else {
            throw updateError("The update checksum file was not valid UTF-8.")
        }
        return try parseSHA256(checksumText, expectedFileName: asset.name)
    }

    private func matchingChecksumAsset(for asset: GitHubReleaseAsset, in release: GitHubRelease) -> GitHubReleaseAsset? {
        let expectedName = "\(asset.name).sha256".lowercased()
        return release.assets.first { candidate in
            candidate.name.lowercased() == expectedName
        }
    }

    private func sha256OfFile(_ zipURL: URL) throws -> String {
        let output = try runProcess("/usr/bin/shasum", arguments: ["-a", "256", zipURL.path])
        return try parseSHA256(output, expectedFileName: zipURL.lastPathComponent)
    }

    private func parseSHA256(_ text: String, expectedFileName: String?) throws -> String {
        let hexCharacters = CharacterSet(charactersIn: "0123456789abcdef")
        for line in text.split(whereSeparator: \.isNewline) {
            let fields = line.split { $0 == " " || $0 == "\t" }.map(String.init)
            guard let candidate = fields.first?.lowercased(),
                  candidate.count == 64,
                  candidate.rangeOfCharacter(from: hexCharacters.inverted) == nil else {
                continue
            }
            if let expectedFileName, fields.count > 1 {
                let fileFields = fields.dropFirst().map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " *")) }
                guard fileFields.contains(where: { $0 == expectedFileName || $0.hasSuffix("/\(expectedFileName)") }) else {
                    continue
                }
            }
            return candidate
        }
        throw updateError("The release checksum did not contain a SHA-256 value for \(expectedFileName ?? "the update asset").")
    }

    private func verifyDownloadedUpdateApp(_ appURL: URL, expectedVersion: String) throws {
        guard let bundle = Bundle(url: appURL) else {
            throw updateError("The downloaded app bundle is invalid.")
        }
        let bundleIdentifier = (bundle.object(forInfoDictionaryKey: "CFBundleIdentifier") as? String) ?? bundle.bundleIdentifier
        guard bundleIdentifier == "app.codexgauge.menubar" else {
            throw updateError("The downloaded app bundle identifier did not match Codex Gauge.")
        }
        let version = (bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0.0.0"
        guard compareVersionStrings(version, expectedVersion) != .orderedAscending else {
            throw updateError("The downloaded app version \(version) is older than \(expectedVersion).")
        }
        let binary = appURL.appendingPathComponent("Contents/MacOS/CodexGauge")
        let helper = appURL.appendingPathComponent("Contents/Resources/codex_status.py")
        guard FileManager.default.isExecutableFile(atPath: binary.path),
              FileManager.default.isReadableFile(atPath: helper.path) else {
            throw updateError("The downloaded app is missing a required bundled helper.")
        }
        try verifyDownloadedUpdateSignature(appURL)
    }

    private func verifyDownloadedUpdateSignature(_ appURL: URL) throws {
        let expectedTeamID = expectedUpdateSigningTeamID
        guard !expectedTeamID.isEmpty else {
            throw updateError("Automatic update installation requires a pinned Developer ID Team ID.")
        }
        try runProcess("/usr/bin/codesign", arguments: ["--verify", "--deep", "--strict", appURL.path])
        let signatureDetails = try runProcess("/usr/bin/codesign", arguments: ["--display", "--verbose=4", appURL.path])
        guard signatureDetails.contains("TeamIdentifier=\(expectedTeamID)") else {
            throw updateError("The downloaded app was not signed by the expected Codex Gauge publisher.")
        }
        try runProcess("/usr/sbin/spctl", arguments: ["--assess", "--type", "execute", "--verbose=4", appURL.path])
    }

    private func installPreparedUpdate(_ update: PreparedUpdate) {
        do {
            lastUpdateSummary = "Update: installing \(update.release.tagName)..."
            rebuildMenu()
            try runDetachedUpdateInstaller(update)
            allowTermination = true
            NSApp.terminate(nil)
        } catch {
            isInstallingUpdate = false
            lastUpdateSummary = "Update failed"
            rebuildMenu()
            showReportAlert(title: "Could not install update", detail: clipped(error.localizedDescription, limit: 240))
        }
    }

    private func runDetachedUpdateInstaller(_ update: PreparedUpdate) throws {
        let scriptURL = update.workDirectory.appendingPathComponent("install-update.sh")
        let targetPath = currentAppBundlePath()
        let script = """
        #!/bin/zsh
        set -euo pipefail
        SOURCE_APP="$1"
        TARGET_APP="$2"
        CURRENT_PID="$3"
        CLEANUP_DIR="$4"
        AGENT_LABEL="app.codexgauge.menubar"
        AGENT_PLIST="$HOME/Library/LaunchAgents/app.codexgauge.menubar.plist"
        UPDATE_TARGET="$TARGET_APP.update"
        install_launch_agent() {
          /bin/mkdir -p "$HOME/Library/LaunchAgents"
          /bin/cat >"$AGENT_PLIST" <<PLIST
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
          <key>Label</key>
          <string>$AGENT_LABEL</string>
          <key>ProgramArguments</key>
          <array>
            <string>/usr/bin/open</string>
            <string>-na</string>
            <string>$TARGET_APP</string>
          </array>
          <key>RunAtLoad</key>
          <true/>
        </dict>
        </plist>
        PLIST
          /bin/chmod 644 "$AGENT_PLIST"
        }
        while /bin/kill -0 "$CURRENT_PID" >/dev/null 2>&1; do
          /bin/sleep 0.2
        done
        /bin/rm -f "$AGENT_PLIST" >/dev/null 2>&1 || true
        /bin/rm -rf "$UPDATE_TARGET"
        /usr/bin/ditto --norsrc --noextattr "$SOURCE_APP" "$UPDATE_TARGET"
        /usr/bin/codesign --verify --deep --strict "$UPDATE_TARGET"
        /bin/rm -rf "$TARGET_APP"
        /bin/mv "$UPDATE_TARGET" "$TARGET_APP"
        install_launch_agent
        /usr/bin/open -na "$TARGET_APP"
        /bin/rm -rf "$CLEANUP_DIR"
        """
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptURL.path)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = [scriptURL.path, update.appURL.path, targetPath, "\(getpid())", update.workDirectory.path]
        try process.run()
    }

    private func currentAppBundlePath() -> String {
        let path = Bundle.main.bundlePath
        if path.hasSuffix(".app") {
            return path
        }
        return "/Applications/CodexGauge.app"
    }

    private func updateAsset(in release: GitHubRelease) -> GitHubReleaseAsset? {
        let zipAssets = release.assets.filter { asset in
            let lower = asset.name.lowercased()
            return lower.hasSuffix(".zip") && !lower.hasSuffix(".zip.sha256")
        }
        return zipAssets.first { $0.name.lowercased().contains("codexgauge") } ?? zipAssets.first
    }

    private func updateError(_ message: String) -> NSError {
        NSError(domain: "CodexGaugeUpdater", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }

    @discardableResult
    private func runProcess(_ executable: String, arguments: [String]) throws -> String {
        let process = Process()
        let output = Pipe()
        let error = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = error
        try process.run()
        process.waitUntilExit()
        let outputText = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let errorText = String(data: error.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw updateError(errorText.isEmpty ? "\(executable) failed with status \(process.terminationStatus)" : errorText)
        }
        return outputText + errorText
    }

    private func releaseInfoText(release: GitHubRelease, asset: GitHubReleaseAsset?, latestVersion: String) -> String {
        var lines = [
            "Current: v\(appVersion)",
            "Latest: \(release.tagName) (\(latestVersion))",
        ]
        if let name = release.name, !name.isEmpty {
            lines.append("Title: \(name)")
        }
        if let publishedAt = release.publishedAt {
            lines.append("Published: \(publishedAt)")
        }
        if let asset {
            lines.append("Download: \(asset.name)\(assetSizeText(asset.size))")
        }
        let notes = clipped(release.body ?? "No release notes were provided.", limit: 900)
        lines.append("")
        lines.append("Release notes:")
        lines.append(notes)
        return lines.joined(separator: "\n")
    }

    private func assetSizeText(_ size: Int?) -> String {
        guard let size else {
            return ""
        }
        if size >= 1_000_000 {
            return String(format: " · %.1f MB", Double(size) / 1_000_000.0)
        }
        if size >= 1_000 {
            return String(format: " · %.0f KB", Double(size) / 1_000.0)
        }
        return " · \(size) B"
    }

    private func appVersionIsNewer(_ candidate: String, than current: String) -> Bool {
        compareVersionStrings(candidate, current) == .orderedDescending
    }

    private func compareVersionStrings(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = versionComponents(lhs)
        let right = versionComponents(rhs)
        let count = max(left.count, right.count)
        for index in 0..<count {
            let leftValue = index < left.count ? left[index] : 0
            let rightValue = index < right.count ? right[index] : 0
            if leftValue < rightValue {
                return .orderedAscending
            }
            if leftValue > rightValue {
                return .orderedDescending
            }
        }
        return .orderedSame
    }

    private func versionComponents(_ value: String) -> [Int] {
        normalizedVersion(value)
            .split { character in
                character == "." || character == "-" || character == "+"
            }
            .map { component in
                Int(component.prefix { $0.isNumber }) ?? 0
            }
    }

    private func normalizedVersion(_ value: String) -> String {
        value.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
    }

    @objc private func openPreferences() {
        let window = preferencesWindow ?? makePreferencesWindow()
        preferencesWindow = window
        syncPreferencesControls()
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func closePreferences() {
        preferencesWindow?.close()
        preferencesWindow = nil
    }

    @objc private func resetSessionPreferences() {
        registerDefaultPreferences()
        syncPreferencesControls()
        refreshSignalPopoverIfNeeded()
        rebuildMenu()
        if let snapshot {
            setStatusImage(title: statusTooltipTitle(snapshot), status: snapshot.codex)
        } else {
            setStatusImage(title: "Codex quota")
        }
        if !isRefreshing {
            scheduleNextRefresh(after: nextRefreshInterval(for: snapshot?.codex))
        }
    }

    private func showFirstRunSetupIfNeeded() {
        return
    }

    private func showFirstRunSetupPopover(from button: NSStatusBarButton) {
        let size = NSSize(width: 460, height: 360)
        let controller = NSViewController()
        controller.view = makeFirstRunSetupContentView(size: size)
        controller.preferredContentSize = size

        firstRunSetupPopover?.performClose(nil)
        let popover = NSPopover()
        popover.behavior = .applicationDefined
        popover.animates = true
        popover.appearance = NSAppearance(named: currentSignalConsoleTheme().appearance)
        popover.contentSize = size
        popover.contentViewController = controller
        firstRunSetupPopover = popover
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
        appendLog("first-run setup shown popover=\(popover.isShown) buttonWindow=\(button.window != nil)")
        if !popover.isShown {
            appendLog("first-run setup popover fallback=window")
            let window = firstRunSetupWindow ?? makeFirstRunSetupWindow()
            firstRunSetupWindow = window
            window.center()
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
    }

    @objc private func completeFirstRunSetup() {
        firstRunSetupWindow?.close()
        firstRunSetupWindow = nil
        firstRunSetupPopover?.performClose(nil)
        firstRunSetupPopover = nil
    }

    @objc private func openSetupDoctor() {
        let window = makeSetupDoctorWindow()
        setupDoctorWindow = window
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func copyDiagnostics() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(safeDiagnosticsText(), forType: .string)
        appendLog("safe diagnostics copied")
    }

    private func showReportAlert(title: String, detail: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = detail
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func openCodexApp() {
        guard let appURL = codexHostAppURL else {
            showReportAlert(title: "ChatGPT not found", detail: "Install ChatGPT or the Codex CLI to load live Codex usage.")
            return
        }
        NSWorkspace.shared.open(appURL)
    }

    @objc private func quit() {
        allowTermination = true
        unloadLaunchAgent()
        NSApp.terminate(nil)
    }

    @objc private func refreshPreferenceChanged(_ sender: Any?) {
        guard
            let popup = sender as? NSPopUpButton,
            let mode = popup.selectedItem?.representedObject as? String
        else {
            return
        }
        sessionRefreshMode = mode
        if !isRefreshing {
            scheduleNextRefresh(after: nextRefreshInterval(for: snapshot?.codex))
            rebuildMenu()
        }
    }

    @objc private func themePreferenceChanged(_ sender: Any?) {
        guard
            let popup = sender as? NSPopUpButton,
            let key = popup.selectedItem?.representedObject as? String
        else {
            return
        }
        sessionSignalConsoleThemeKey = key
        if let signalPopover, signalPopover.isShown {
            signalPopover.appearance = NSAppearance(named: currentSignalConsoleTheme().appearance)
            signalConsolePanelView?.apply(theme: currentSignalConsoleTheme())
        }
        if let snapshot {
            setStatusImage(title: statusTooltipTitle(snapshot), status: snapshot.codex)
        } else {
            setStatusImage(title: "Codex quota")
        }
        refreshSignalPopoverIfNeeded()
    }

    @objc private func notificationsPreferenceChanged(_ sender: Any?) {
        guard let checkbox = sender as? NSButton else {
            return
        }
        let enabled = checkbox.state == .on
        sessionNotificationsEnabled = enabled
        if enabled {
            requestNotificationAuthorization()
        }
    }

    @objc private func launchAtLoginPreferenceChanged(_ sender: Any?) {
        guard let checkbox = sender as? NSButton else {
            return
        }
        if checkbox.state == .on {
            if !installLaunchAgentForCurrentApp() {
                checkbox.state = .off
                showReportAlert(title: "Startup not enabled", detail: "Codex Gauge could not write the LaunchAgent. Try installing the app again or check permissions for ~/Library/LaunchAgents.")
            }
        } else {
            removeLaunchAgentPlist()
            unloadLaunchAgent()
        }
    }

    private func refresh(force: Bool = false) {
        if isRefreshing {
            guard force else {
                return
            }
            refreshGeneration += 1
            if activeRefreshProcess?.isRunning == true {
                activeRefreshProcess?.terminate()
            }
            activeRefreshProcess = nil
            isRefreshing = false
        }
        refreshGeneration += 1
        let generation = refreshGeneration
        isRefreshing = true
        nextRefreshAt = nil
        if snapshot == nil {
            setStatusImage(title: "Refreshing Codex quota")
        }
        rebuildMenu()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.arguments = [usagePath, "--status-json"]
        process.environment = helperEnvironment()
        process.currentDirectoryURL = FileManager.default.temporaryDirectory

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        let bufferQueue = DispatchQueue(label: "app.codexgauge.menubar.output")
        var stdoutBuffer = Data()
        var stderrBuffer = Data()
        stdout.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                return
            }
            bufferQueue.async {
                stdoutBuffer.append(data)
            }
        }
        stderr.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                return
            }
            bufferQueue.async {
                stderrBuffer.append(data)
            }
        }

        process.terminationHandler = { [weak self] proc in
            stdout.fileHandleForReading.readabilityHandler = nil
            stderr.fileHandleForReading.readabilityHandler = nil
            let remainingOutput = stdout.fileHandleForReading.readDataToEndOfFile()
            let remainingError = stderr.fileHandleForReading.readDataToEndOfFile()
            bufferQueue.async {
                stdoutBuffer.append(remainingOutput)
                stderrBuffer.append(remainingError)
                let output = String(data: stdoutBuffer, encoding: .utf8) ?? ""
                let errorOutput = String(data: stderrBuffer, encoding: .utf8) ?? ""
                DispatchQueue.main.async {
                    self?.finishRefresh(
                        status: proc.terminationStatus,
                        output: output,
                        errorOutput: errorOutput,
                        generation: generation
                    )
                }
            }
        }

        activeRefreshProcess = process
        do {
            try process.run()
        } catch {
            finishRefresh(
                status: -1,
                output: "",
                errorOutput: error.localizedDescription,
                generation: generation
            )
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + refreshTimeout) { [weak self] in
            guard let self, self.refreshGeneration == generation, self.isRefreshing else {
                return
            }
            if process.isRunning {
                process.terminate()
            }
            self.finishRefresh(
                status: -2,
                output: "",
                errorOutput: "Live refresh timed out.",
                generation: generation
            )
        }
    }

    private func startMoodAnimation(for status: ServiceStatus) {
        guard status.ok else {
            stopMoodAnimation()
            return
        }
        guard animationTimer == nil else {
            return
        }
        animationTimer?.invalidate()
        moodPulseStep = 1
        if let snapshot {
            setStatusImage(title: statusTooltipTitle(snapshot), status: snapshot.codex)
        }
        let nextTimer = Timer(timeInterval: 1.2, repeats: false) { [weak self] timer in
            timer.invalidate()
            guard let self else {
                return
            }
            self.animationTimer = nil
            self.moodPulseStep = 0
            if let snapshot = self.snapshot {
                self.setStatusImage(title: self.statusTooltipTitle(snapshot), status: snapshot.codex)
            } else {
                self.setStatusImage(title: "Codex quota")
            }
        }
        applyTimerTolerance(nextTimer, interval: 1.2)
        animationTimer = nextTimer
        RunLoop.main.add(nextTimer, forMode: .common)
    }

    private func stopMoodAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        moodPulseStep = 0
    }

    private func registerDefaultPreferences() {
        sessionSignalConsoleThemeKey = blueCeramicThemeKey
        sessionRefreshMode = adaptiveRefreshMode
        sessionNotificationsEnabled = false
    }

    private func makeThemedUtilityContentView(size: NSSize) -> ThemedUtilityPanelView {
        ThemedUtilityPanelView(
            frame: NSRect(origin: .zero, size: size),
            theme: currentSignalConsoleTheme()
        )
    }

    private func utilityLabel(_ text: String, frame: NSRect, size: CGFloat, weight: NSFont.Weight, color: NSColor) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: size, weight: weight)
        label.textColor = color
        label.frame = frame
        if frame.height > 24 {
            label.lineBreakMode = .byWordWrapping
            label.cell?.wraps = true
            label.cell?.usesSingleLineMode = false
        }
        return label
    }

    private func styleUtilityButton(_ button: NSButton, primary: Bool = false) {
        let theme = currentSignalConsoleTheme()
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.cornerRadius = 9
        button.layer?.backgroundColor = (primary ? theme.mintAccent : theme.commandButtonBackground).cgColor
        button.attributedTitle = NSAttributedString(
            string: button.title,
            attributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: primary ? .semibold : .medium),
                .foregroundColor: primary ? theme.buttonPrimaryText : theme.textPrimary,
            ]
        )
    }

    private func addUtilityStatusRow(to content: NSView, y: CGFloat, title: String, detail: String, state: String) {
        let theme = currentSignalConsoleTheme()
        let card = NSView(frame: NSRect(x: 24, y: y, width: content.bounds.width - 48, height: 36))
        card.wantsLayer = true
        card.layer?.cornerRadius = 10
        card.layer?.backgroundColor = theme.commandButtonBackground.cgColor
        card.layer?.borderColor = theme.panelBorder.withAlphaComponent(0.28).cgColor
        card.layer?.borderWidth = 1
        content.addSubview(card)

        let dot = NSView(frame: NSRect(x: 12, y: 13, width: 10, height: 10))
        dot.wantsLayer = true
        dot.layer?.cornerRadius = 5
        dot.layer?.backgroundColor = doctorStatusColor(state).cgColor
        card.addSubview(dot)

        card.addSubview(utilityLabel(title, frame: NSRect(x: 32, y: 13, width: 150, height: 16), size: 12, weight: .semibold, color: theme.textPrimary))
        card.addSubview(utilityLabel(detail, frame: NSRect(x: 190, y: 13, width: card.bounds.width - 204, height: 16), size: 11, weight: .regular, color: theme.textSecondary))
    }

    private func makeFirstRunSetupContentView(size: NSSize) -> ThemedUtilityPanelView {
        let theme = currentSignalConsoleTheme()
        let content = makeThemedUtilityContentView(size: size)

        content.addSubview(utilityLabel("Codex Gauge is ready", frame: NSRect(x: 28, y: 306, width: 260, height: 26), size: 18, weight: .semibold, color: theme.textPrimary))
        content.addSubview(utilityLabel("Local first. No cookies.", frame: NSRect(x: 28, y: 280, width: 260, height: 18), size: 12, weight: .medium, color: theme.mintAccent))
        content.addSubview(utilityLabel("Open ChatGPT once, then Codex Gauge keeps your 5-hour and 7-day quota visible from the menu bar.", frame: NSRect(x: 28, y: 248, width: 400, height: 34), size: 12, weight: .regular, color: theme.textSecondary))

        addUtilityStatusRow(to: content, y: 192, title: "Live source", detail: "Uses the local Codex app-server", state: "green")
        addUtilityStatusRow(to: content, y: 148, title: "Menu bar", detail: "Refreshes hands-free after setup", state: "green")
        addUtilityStatusRow(to: content, y: 104, title: "Privacy", detail: "No browser cookies or auth-file reads", state: "green")

        let openCodex = NSButton(title: "Open ChatGPT", target: self, action: #selector(openCodexApp))
        openCodex.frame = NSRect(x: 28, y: 42, width: 116, height: 32)
        styleUtilityButton(openCodex)
        content.addSubview(openCodex)

        let runCheck = NSButton(title: "Run Check", target: self, action: #selector(openSetupDoctor))
        runCheck.frame = NSRect(x: 152, y: 42, width: 104, height: 32)
        styleUtilityButton(runCheck)
        content.addSubview(runCheck)

        let start = NSButton(title: "Start in menu bar", target: self, action: #selector(completeFirstRunSetup))
        start.frame = NSRect(x: 280, y: 42, width: 148, height: 32)
        styleUtilityButton(start, primary: true)
        content.addSubview(start)

        return content
    }

    private func makeFirstRunSetupWindow() -> NSWindow {
        let theme = currentSignalConsoleTheme()
        let size = NSSize(width: 460, height: 360)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Codex Gauge Setup"
        window.appearance = NSAppearance(named: theme.appearance)
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        window.contentView = makeFirstRunSetupContentView(size: size)

        return window
    }

    private func makePreferencesWindow() -> NSWindow {
        let theme = currentSignalConsoleTheme()
        let size = NSSize(width: 640, height: 460)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Codex Gauge Preferences"
        window.appearance = NSAppearance(named: theme.appearance)
        window.isReleasedWhenClosed = false

        let content = makeThemedUtilityContentView(size: size)
        window.contentView = content

        let labelX: CGFloat = 184
        let controlX: CGFloat = 392
        let leftColumnX: CGFloat = labelX
        let rightColumnX: CGFloat = 404
        let controlWidth: CGFloat = 190
        let columnWidth: CGFloat = 188
        content.addSubview(utilityLabel("Codex Gauge  •  Preferences", frame: NSRect(x: labelX, y: 410, width: 278, height: 24), size: 16, weight: .semibold, color: theme.textPrimary))

        content.addSubview(utilityLabel("Refresh", frame: NSRect(x: labelX, y: 364, width: 150, height: 18), size: 13, weight: .bold, color: theme.textPrimary))
        content.addSubview(utilityLabel("Refresh cadence", frame: NSRect(x: labelX, y: 334, width: 150, height: 18), size: 12, weight: .regular, color: theme.textSecondary))

        let popup = NSPopUpButton(frame: NSRect(x: controlX, y: 330, width: controlWidth, height: 28), pullsDown: false)
        popup.addItems(withTitles: ["Adaptive", "Every 5 minutes", "Every 10 minutes"])
        popup.item(withTitle: "Adaptive")?.representedObject = adaptiveRefreshMode
        popup.item(withTitle: "Every 5 minutes")?.representedObject = fiveMinuteRefreshMode
        popup.item(withTitle: "Every 10 minutes")?.representedObject = tenMinuteRefreshMode
        popup.target = self
        popup.action = #selector(refreshPreferenceChanged)
        content.addSubview(popup)
        refreshPopup = popup

        content.addSubview(utilityLabel("Live signal source", frame: NSRect(x: labelX, y: 300, width: 150, height: 18), size: 12, weight: .regular, color: theme.textSecondary))
        let sourceDisplay = NSPopUpButton(frame: NSRect(x: controlX, y: 296, width: controlWidth, height: 28), pullsDown: false)
        sourceDisplay.addItems(withTitles: ["Menu Bar (Default)"])
        sourceDisplay.isEnabled = false
        content.addSubview(sourceDisplay)
        content.addSubview(utilityLabel("Shorter intervals use more power.", frame: NSRect(x: labelX, y: 274, width: 220, height: 16), size: 10, weight: .regular, color: theme.textMuted))

        content.addSubview(utilityLabel("Appearance", frame: NSRect(x: leftColumnX, y: 244, width: 150, height: 18), size: 13, weight: .bold, color: theme.textPrimary))
        content.addSubview(utilityLabel("Signal Console theme", frame: NSRect(x: leftColumnX, y: 220, width: 150, height: 18), size: 11, weight: .regular, color: theme.textSecondary))

        let themeSelect = NSPopUpButton(frame: NSRect(x: leftColumnX, y: 192, width: columnWidth, height: 28), pullsDown: false)
        themeSelect.addItems(withTitles: ["Blue Ceramic", "Porcelain Lab", "Signal Dark", "Mono Graphite"])
        themeSelect.item(withTitle: "Blue Ceramic")?.representedObject = blueCeramicThemeKey
        themeSelect.item(withTitle: "Porcelain Lab")?.representedObject = porcelainLabThemeKey
        themeSelect.item(withTitle: "Signal Dark")?.representedObject = signalDarkThemeKey
        themeSelect.item(withTitle: "Mono Graphite")?.representedObject = monoGraphiteThemeKey
        themeSelect.target = self
        themeSelect.action = #selector(themePreferenceChanged)
        content.addSubview(themeSelect)
        themePopup = themeSelect

        let notifications = NSButton(checkboxWithTitle: "Quota notifications", target: self, action: #selector(notificationsPreferenceChanged))
        notifications.frame = NSRect(x: leftColumnX, y: 162, width: columnWidth, height: 22)
        notifications.contentTintColor = theme.textSecondary
        content.addSubview(notifications)
        notificationsCheckbox = notifications

        let login = NSButton(checkboxWithTitle: "Launch at login", target: self, action: #selector(launchAtLoginPreferenceChanged))
        login.frame = NSRect(x: leftColumnX, y: 136, width: columnWidth, height: 22)
        login.contentTintColor = theme.textSecondary
        content.addSubview(login)
        launchAtLoginCheckbox = login

        content.addSubview(utilityLabel("Updates", frame: NSRect(x: rightColumnX, y: 244, width: 150, height: 18), size: 13, weight: .bold, color: theme.textPrimary))
        let updates = NSButton(checkboxWithTitle: "Check automatically", target: nil, action: nil)
        updates.frame = NSRect(x: rightColumnX, y: 216, width: 142, height: 22)
        updates.state = .on
        updates.contentTintColor = theme.textSecondary
        updates.isEnabled = false
        content.addSubview(updates)

        let updateCheck = NSButton(title: "Check Now", target: self, action: #selector(checkForUpdates))
        updateCheck.frame = NSRect(x: rightColumnX, y: 178, width: 92, height: 28)
        styleUtilityButton(updateCheck)
        content.addSubview(updateCheck)

        let resetDefaults = NSButton(title: "Reset to Defaults...", target: self, action: #selector(resetSessionPreferences))
        resetDefaults.frame = NSRect(x: labelX, y: 20, width: 126, height: 30)
        styleUtilityButton(resetDefaults)
        content.addSubview(resetDefaults)

        let done = NSButton(title: "Done", target: self, action: #selector(closePreferences))
        done.frame = NSRect(x: size.width - 106, y: 20, width: 78, height: 30)
        styleUtilityButton(done, primary: true)
        content.addSubview(done)

        return window
    }

    private func syncPreferencesControls() {
        let mode = currentRefreshMode()
        refreshPopup?.selectItem(withTitle: refreshTitle(for: mode))
        themePopup?.selectItem(withTitle: currentSignalConsoleTheme().name)
        notificationsCheckbox?.state = notificationsEnabled() ? .on : .off
        launchAtLoginCheckbox?.state = isLaunchAgentConfigured() ? .on : .off
    }

    private func refreshTitle(for mode: String) -> String {
        switch mode {
        case fiveMinuteRefreshMode:
            return "Every 5 minutes"
        case tenMinuteRefreshMode:
            return "Every 10 minutes"
        default:
            return "Adaptive"
        }
    }

    private func currentSignalConsoleTheme() -> SignalConsoleTheme {
        switch currentSignalConsoleThemeKey() {
        case blueCeramicThemeKey:
            return blueCeramicTheme()
        case porcelainLabThemeKey:
            return porcelainLabTheme()
        case signalDarkThemeKey:
            return signalDarkTheme()
        case monoGraphiteThemeKey:
            return monoGraphiteTheme()
        default:
            return blueCeramicTheme()
        }
    }

    private func currentSignalConsoleThemeKey() -> String {
        let key = sessionSignalConsoleThemeKey
        switch key {
        case blueCeramicThemeKey, porcelainLabThemeKey, paperConsoleThemeKey, signalDarkThemeKey, monoGraphiteThemeKey:
            return key
        default:
            return blueCeramicThemeKey
        }
    }

    private func currentRefreshMode() -> String {
        let mode = sessionRefreshMode
        switch mode {
        case fiveMinuteRefreshMode, tenMinuteRefreshMode:
            return mode
        default:
            return adaptiveRefreshMode
        }
    }

    private func fixedRefreshInterval() -> TimeInterval? {
        switch currentRefreshMode() {
        case fiveMinuteRefreshMode:
            return normalRefreshInterval
        case tenMinuteRefreshMode:
            return tenMinuteRefreshInterval
        default:
            return nil
        }
    }

    private func helperEnvironment() -> [String: String] {
        let userName = NSUserName()
        var helperEnv: [String: String] = [
            "CODEX_CI": "1",
            "CODEX_HOME": NSHomeDirectory() + "/.codex",
            "CODEX_SHELL": "1",
            "HOME": NSHomeDirectory(),
            "LOGNAME": userName,
            "PATH": "/Applications/ChatGPT.app/Contents/Resources:/Applications/Codex.app/Contents/Resources:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin",
            "PYTHONUNBUFFERED": "1",
            "SHELL": "/bin/zsh",
            "TMPDIR": NSTemporaryDirectory(),
            "USER": userName,
            "CODEX_GAUGE_PYTHON_PATH": pythonPath,
            "CODEX_GAUGE_STATUS_HELPER": usagePath,
        ]
        if let codexCliBundlePath, FileManager.default.isExecutableFile(atPath: codexCliBundlePath) {
            helperEnv["CODEX_GAUGE_CODEX_CLI_PATH"] = codexCliBundlePath
        }
        return helperEnv
    }

    private func canPreserveSnapshot(_ snapshot: UsageSnapshot, now: Date = Date()) -> Bool {
        guard !isUnavailableStatus(snapshot.codex) else {
            return false
        }
        let timestamp = snapshot.codex.dataTime ?? snapshot.updatedAt
        guard let capturedAt = isoDate(timestamp) else {
            return false
        }
        return now.timeIntervalSince(capturedAt) <= maximumStaleDisplayAge
    }

    private func finishRefresh(status: Int32, output: String, errorOutput: String, generation: Int) {
        guard refreshGeneration == generation, isRefreshing else {
            return
        }
        activeRefreshProcess = nil
        isRefreshing = false
        let previousSnapshot = snapshot
        appendLog("refresh finished status=\(status) stdout=\(clipped(output, limit: 600)) stderr=\(clipped(errorOutput, limit: 600))")
        if status == 0 {
            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let data = Data(output.utf8)
                let decoded = try decoder.decode(UsageSnapshot.self, from: data)
                if isLiveRefreshFailure(decoded.codex), let previousSnapshot, canPreserveSnapshot(previousSnapshot) {
                    snapshot = previousSnapshot
                    lastError = decoded.codex.error ?? "Codex live usage unavailable."
                    handleNotificationTransitions(decoded.codex)
                    stopMoodAnimation()
                    setStatusImage(title: statusTooltipTitle(previousSnapshot), status: previousSnapshot.codex)
                    appendLog("preserved last visible quota after refresh failure error=\(lastError ?? "")")
                    scheduleNextRefresh(after: lastError == nil ? nextRefreshInterval(for: snapshot?.codex) : recoveryRefreshInterval)
                    rebuildMenu()
                    return
                }
                snapshot = decoded
                lastError = isLiveRefreshFailure(decoded.codex) ? (decoded.codex.error ?? "Codex live usage unavailable.") : nil
                handleNotificationTransitions(decoded.codex)
                setStatusImage(title: statusTooltipTitle(decoded), status: decoded.codex)
                startMoodAnimation(for: decoded.codex)
                appendLog("title=\(decoded.title) ok=\(decoded.codex.ok) source=\(decoded.codex.source ?? "") error=\(decoded.codex.error ?? "")")
            } catch {
                lastError = "Could not parse status JSON: \(error.localizedDescription)"
                stopMoodAnimation()
                if let previousSnapshot, canPreserveSnapshot(previousSnapshot) {
                    snapshot = previousSnapshot
                    setStatusImage(title: statusTooltipTitle(previousSnapshot), status: previousSnapshot.codex)
                } else {
                    snapshot = nil
                    setStatusImage(title: "Open ChatGPT to refresh live usage")
                }
                appendLog("parse error=\(error.localizedDescription)")
            }
        } else {
            stopMoodAnimation()
            let detail = errorOutput.isEmpty ? output : errorOutput
            lastError = detail.isEmpty ? "Status command exited with code \(status)" : clipped(detail, limit: 160)
            if let previousSnapshot, canPreserveSnapshot(previousSnapshot) {
                snapshot = previousSnapshot
                setStatusImage(title: statusTooltipTitle(previousSnapshot), status: previousSnapshot.codex)
            } else {
                snapshot = nil
                setStatusImage(title: "Open ChatGPT to refresh live usage")
            }
        }
        scheduleNextRefresh(after: lastError == nil ? nextRefreshInterval(for: snapshot?.codex) : recoveryRefreshInterval)
        rebuildMenu()
    }

    private func notificationsEnabled() -> Bool {
        sessionNotificationsEnabled
    }

    private func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] granted, error in
            DispatchQueue.main.async {
                if let error {
                    self?.appendLog("notification authorization failed=\(error.localizedDescription)")
                }
                if !granted {
                    self?.sessionNotificationsEnabled = false
                    self?.notificationsCheckbox?.state = .off
                }
            }
        }
    }

    private func handleNotificationTransitions(_ status: ServiceStatus) {
        let isLive = status.ok && !isNonLiveSource(status.source)
        if isLive {
            liveUnavailableSince = nil
            didNotifyLiveUnavailable = false
        } else {
            let started = liveUnavailableSince ?? Date()
            liveUnavailableSince = started
            if notificationsEnabled(),
               !didNotifyLiveUnavailable,
               Date().timeIntervalSince(started) >= liveUnavailableNotificationDelay {
                postNotification(
                    identifier: liveUnavailableNotification,
                    title: "Codex live usage is unavailable",
                    body: "Codex Gauge is temporarily showing its last in-memory reading while live usage retries."
                )
                didNotifyLiveUnavailable = true
            }
        }

        guard notificationsEnabled() else {
            previousFiveHourLeft = status.fiveHourLeft
            return
        }

        guard let current = status.fiveHourLeft else {
            return
        }

        if previousFiveHourLeft == nil, current < 10 {
            postNotification(
                identifier: fiveHourLowNotification,
                title: "Codex 5-hour quota is low",
                body: "Your 5-hour Codex quota is below 10%."
            )
        } else if let previous = previousFiveHourLeft, previous >= 10, current < 10 {
            postNotification(
                identifier: fiveHourLowNotification,
                title: "Codex 5-hour quota is low",
                body: "Your 5-hour Codex quota just dropped below 10%."
            )
        } else if let previous = previousFiveHourLeft, previous < 10, current >= 90 {
            resetHighlightUntil = Date().addingTimeInterval(180)
            postNotification(
                identifier: fiveHourRestoredNotification,
                title: "Codex 5-hour quota is back",
                body: "Your 5-hour Codex quota has refreshed."
            )
        } else if let previous = previousFiveHourLeft, current - previous >= 50 {
            resetHighlightUntil = Date().addingTimeInterval(180)
        }
        previousFiveHourLeft = current
    }

    private func postNotification(identifier: String, title: String, body: String) {
        guard notificationsEnabled() else {
            return
        }
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
                return
            }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: "\(identifier)-\(Int(Date().timeIntervalSince1970))",
                content: content,
                trigger: nil
            )
            center.add(request)
        }
    }

    private func makeSetupDoctorWindow() -> NSWindow {
        let theme = currentSignalConsoleTheme()
        let checks = runSetupDoctorChecks()
        let rowHeight: CGFloat = 42
        let height = 142 + CGFloat(checks.count) * rowHeight
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: height),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Setup Doctor"
        window.appearance = NSAppearance(named: theme.appearance)
        window.isReleasedWhenClosed = false
        let content = makeThemedUtilityContentView(size: NSSize(width: 440, height: height))
        window.contentView = content

        content.addSubview(utilityLabel("Setup Doctor", frame: NSRect(x: 24, y: height - 46, width: 240, height: 24), size: 16, weight: .semibold, color: theme.textPrimary))
        content.addSubview(utilityLabel("Checks local pieces only. No cookies, auth files, prompts, responses, or logs are copied.", frame: NSRect(x: 24, y: height - 72, width: 392, height: 18), size: 11, weight: .regular, color: theme.textSecondary))

        var y = height - 118
        for check in checks {
            addUtilityStatusRow(to: content, y: y, title: check.title, detail: check.detail, state: check.state)
            y -= rowHeight
        }

        let refresh = NSButton(title: "Run Full Diagnostics", target: self, action: #selector(openSetupDoctor))
        refresh.frame = NSRect(x: 24, y: 20, width: 144, height: 28)
        styleUtilityButton(refresh)
        content.addSubview(refresh)

        let diagnostics = NSButton(title: "Copy Diagnostics", target: self, action: #selector(copyDiagnostics))
        diagnostics.frame = NSRect(x: 176, y: 20, width: 136, height: 28)
        styleUtilityButton(diagnostics, primary: true)
        content.addSubview(diagnostics)

        return window
    }

    private func runSetupDoctorChecks() -> [DoctorCheck] {
        let codexFound = codexHostAppURL != nil
        let helperWorks = FileManager.default.isReadableFile(atPath: usagePath)
        let liveAvailable = snapshot?.codex.ok == true && snapshot?.codex.source == "live"
        let launchAgentRunning = isLaunchAgentConfigured()
        let notificationsAllowed = notificationsEnabled()
        return [
            DoctorCheck(
                title: "ChatGPT app found",
                state: codexFound ? "green" : "amber",
                detail: codexFound ? "Codex host is installed" : "Install or open ChatGPT"
            ),
            DoctorCheck(
                title: "Helper works",
                state: helperWorks ? "green" : "red",
                detail: helperWorks ? "Bundled helper readable" : "Reinstall Codex Gauge"
            ),
            DoctorCheck(
                title: "Live data available",
                state: liveAvailable ? "green" : "amber",
                detail: liveAvailable ? "Live data is current" : "Open ChatGPT, then Refresh Now"
            ),
            DoctorCheck(
                title: "Launch at login",
                state: launchAgentRunning ? "amber" : "green",
                detail: launchAgentRunning ? "Startup enabled" : "Startup off"
            ),
            DoctorCheck(
                title: "Notifications permission",
                state: notificationsAllowed ? "green" : "grey",
                detail: notificationsAllowed ? "Quota alerts enabled" : "Optional, off by default"
            ),
        ]
    }

    private func doctorStatusColor(_ state: String) -> NSColor {
        switch state {
        case "green":
            return NSColor(calibratedRed: 0.18, green: 0.74, blue: 0.50, alpha: 1.0)
        case "amber":
            return NSColor(calibratedRed: 1.00, green: 0.62, blue: 0.22, alpha: 1.0)
        case "red":
            return NSColor(calibratedRed: 0.92, green: 0.24, blue: 0.28, alpha: 1.0)
        default:
            return NSColor(calibratedWhite: 0.56, alpha: 1.0)
        }
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        if isRefreshing {
            addDisabled("Refreshing...")
            menu.addItem(NSMenuItem.separator())
        }

        if let snapshot {
            addCodexDetail(snapshot)
            addErrorIfNeeded(snapshot.codex)
        } else if let lastError {
            addDisabled("Status unavailable")
            addDisabled("Open ChatGPT to refresh live usage")
            addDisabled(clipped(lastError, limit: 96))
        } else {
            addDisabled("Waiting for first refresh")
            addDisabled("Open ChatGPT to refresh live usage")
        }

        menu.addItem(NSMenuItem.separator())
        addDisabled("Codex Gauge v" + appVersion)
        addDisabled("Live only · no usage history")
        if let lastUpdateSummary {
            addDisabled(lastUpdateSummary)
        }
        addAction("Check for Updates...", action: #selector(checkForUpdates))
        addAction("Release Page...", action: #selector(openReleases))
        addAction("Preferences...", action: #selector(openPreferences))
        menu.addItem(NSMenuItem.separator())
        addAction("Refresh Now", action: #selector(refreshNow))
        addAction("Open ChatGPT", action: #selector(openCodexApp))
        addAction("Setup Doctor", action: #selector(openSetupDoctor))
        addAction("Copy Diagnostics", action: #selector(copyDiagnostics))
        addAction("Open Codex Analytics", action: #selector(openCodexAnalytics))
        menu.addItem(NSMenuItem.separator())
        addAction("Quit", action: #selector(quit))
        refreshSignalPopoverIfNeeded()
    }

    private func serviceLine(_ status: ServiceStatus) -> String {
        if status.ok {
            var line = "\(status.service): 5h \(percent(status.fiveHourLeft))  7d \(percent(status.sevenDayLeft))"
            if let plan = status.plan, !plan.isEmpty, plan != "?" {
                line += "  \(plan)"
            }
            if let source = status.source, !source.isEmpty {
                line += "  \(source)"
            }
            return line
        }
        return "\(status.service): unavailable"
    }

    private func sourceStatusTitle(_ status: ServiceStatus) -> String {
        if isUnavailableStatus(status) {
            return "Open ChatGPT once to enable live usage"
        }
        return status.ok ? "Live data is current" : "Open ChatGPT to refresh live usage"
    }

    private func sourceStatusDetail(_ status: ServiceStatus) -> String {
        if isUnavailableStatus(status) {
            return "After Codex is open, Codex Gauge refreshes hands-free from the menu bar."
        }
        return "Read from local Codex app-server"
    }

    private func isUnavailableStatus(_ status: ServiceStatus) -> Bool {
        !status.ok || (status.fiveHourLeft == nil && status.sevenDayLeft == nil)
    }

    private func addCodexDetail(_ snapshot: UsageSnapshot) {
        let status = snapshot.codex
        if status.ok {
            addDisabled(planTitle(status), monospaced: false)
            addDisabled(sourceStatusTitle(status))
            addDisabled(sourceStatusDetail(status))
            addDisabled("\(fiveHourMenuLabel)    \(percent(status.fiveHourLeft))  \(barString(status.fiveHourLeft))", monospaced: true)
            addDisabled("\(sevenDayMenuLabel)     \(percent(status.sevenDayLeft))  \(barString(status.sevenDayLeft))", monospaced: true)
            addDisabled("\(fiveHourResetMenuLabel) \(resetCountdown(status.fiveHourReset))")
            addDisabled("\(sevenDayResetMenuLabel) \(resetCountdown(status.sevenDayReset))")
            if let resetHighlightUntil, resetHighlightUntil > Date() {
                addDisabled("5h refreshed")
            }
            addDisabled("\(refreshLabel(status)) \(shortTime(status.dataTime ?? snapshot.updatedAt))")
            return
        }

        addDisabled("Codex")
        addDisabled(sourceStatusTitle(status))
        addDisabled(sourceStatusDetail(status))
        addDisabled(serviceLine(status))
    }

    private func addErrorIfNeeded(_ status: ServiceStatus) {
        guard let error = status.error, !error.isEmpty else {
            return
        }
        addDisabled("  \(clipped(error, limit: 96))")
    }

    private func setStatusImage(title: String, status: ServiceStatus? = nil) {
        statusItem.length = statusItemWidth
        statusItemStatus = status
        let tooltip = menuBarTooltipTitle(title: title, status: status)
        let accessibilityLabel = "Codex Gauge \(menuBarAccessibilitySummary(status))"
        statusItem.button?.toolTip = tooltip
        statusItem.button?.setAccessibilityLabel(accessibilityLabel)
        statusItemView.toolTip = tooltip
        statusItemView.setAccessibilityLabel(accessibilityLabel)
        statusItemView.needsDisplay = true
    }

    private func isLiveWarningStatus(_ status: ServiceStatus?) -> Bool {
        if lastError != nil {
            return true
        }
        guard let status else {
            return false
        }
        return !status.ok || isNonLiveSource(status.source) || !(status.error ?? "").isEmpty
    }

    private func isLiveRefreshFailure(_ status: ServiceStatus) -> Bool {
        !status.ok || isUnavailableStatus(status) || isNonLiveSource(status.source)
    }

    private func menuBarTooltipTitle(title: String, status: ServiceStatus?) -> String {
        var parts = [title]
        if let status, status.ok, !isUnavailableStatus(status) {
            parts.append("5h resets \(fiveHourResetCountdown(status.fiveHourReset))")
            parts.append("7d resets \(sevenDayResetCountdown(status.sevenDayReset))")
        }
        return parts.joined(separator: " · ")
    }

    private func menuBarAccessibilitySummary(_ status: ServiceStatus?) -> String {
        guard let status, status.ok, !isUnavailableStatus(status) else {
            return "unavailable"
        }
        let fiveHour = status.fiveHourLeft.map { "\($0)%" } ?? "--"
        let sevenDay = status.sevenDayLeft.map { "\($0)%" } ?? "--"
        return "5h \(fiveHour), 7d \(sevenDay)"
    }

    private func statusPixelAligned(_ value: CGFloat) -> CGFloat {
        let scale = max(1.0, currentStatusImageScale)
        return (value * scale).rounded() / scale
    }

    private func statusPixelAlignedPoint(_ point: NSPoint) -> NSPoint {
        NSPoint(x: statusPixelAligned(point.x), y: statusPixelAligned(point.y))
    }

    private func statusPixelAlignedRect(_ rect: NSRect) -> NSRect {
        let minX = statusPixelAligned(rect.minX)
        let minY = statusPixelAligned(rect.minY)
        let maxX = statusPixelAligned(rect.maxX)
        let maxY = statusPixelAligned(rect.maxY)
        let minimum = 1.0 / max(1.0, currentStatusImageScale)
        return NSRect(
            x: minX,
            y: minY,
            width: max(minimum, maxX - minX),
            height: max(minimum, maxY - minY)
        )
    }

    private func drawStatusItemView(in rect: NSRect) {
        currentStatusImageScale = max(
            1.0,
            min(3.0, statusItemView.window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2.0)
        )
        let palette = gaugePalette()
        let status = statusItemStatus
        let liveWarning = isLiveWarningStatus(status)
        if liveWarning {
            drawLiveWarningGauge(
                fiveHourLeft: status?.fiveHourLeft,
                sevenDayLeft: status?.sevenDayLeft,
                fiveHourReset: status?.fiveHourReset,
                sevenDayReset: status?.sevenDayReset,
                palette: palette
            )
        } else if let status, status.ok, !isUnavailableStatus(status) {
            drawPlanBGauge(
                fiveHourLeft: status.fiveHourLeft,
                sevenDayLeft: status.sevenDayLeft,
                fiveHourReset: status.fiveHourReset,
                sevenDayReset: status.sevenDayReset,
                palette: palette
            )
        } else if status?.ok == true {
            drawUnavailableGauge(palette: palette)
        } else {
            drawUnavailableGauge(palette: palette)
        }
        _ = rect
    }

    private func morandiMenuBarSage() -> NSColor {
        isDarkMenuBar()
            ? NSColor(calibratedRed: 0.55, green: 0.64, blue: 0.56, alpha: 0.96)
            : NSColor(calibratedRed: 0.45, green: 0.56, blue: 0.48, alpha: 0.96)
    }

    private func morandiMenuBarMist() -> NSColor {
        isDarkMenuBar()
            ? NSColor(calibratedRed: 0.55, green: 0.64, blue: 0.67, alpha: 0.96)
            : NSColor(calibratedRed: 0.39, green: 0.52, blue: 0.57, alpha: 0.96)
    }

    private func morandiMenuBarClay() -> NSColor {
        isDarkMenuBar()
            ? NSColor(calibratedRed: 0.69, green: 0.54, blue: 0.50, alpha: 0.96)
            : NSColor(calibratedRed: 0.63, green: 0.42, blue: 0.39, alpha: 0.96)
    }

    private func morandiMenuBarTaupe() -> NSColor {
        isDarkMenuBar()
            ? NSColor(calibratedRed: 0.64, green: 0.59, blue: 0.53, alpha: 0.96)
            : NSColor(calibratedRed: 0.52, green: 0.48, blue: 0.42, alpha: 0.96)
    }

    private func isUnavailableStatus(fiveHourLeft: Int?, sevenDayLeft: Int?, source: String?) -> Bool {
        fiveHourLeft == nil && sevenDayLeft == nil && source == nil
    }

    private func drawUnavailableGauge(palette: GaugePalette) {
        drawMenuBarUsagePercentBars(fiveHourLeft: nil, sevenDayLeft: nil, palette: palette)
        drawMenuBarRefreshCountdown(fiveHourReset: nil, sevenDayReset: nil, palette: palette)
    }

    private func drawLiveWarningGauge(fiveHourLeft: Int?, sevenDayLeft: Int?, fiveHourReset: Double?, sevenDayReset: Double?, palette: GaugePalette) {
        drawMenuBarUsagePercentBars(fiveHourLeft: fiveHourLeft, sevenDayLeft: sevenDayLeft, palette: palette)
        if fiveHourReset != nil || sevenDayReset != nil {
            drawMenuBarRefreshCountdown(fiveHourReset: fiveHourReset, sevenDayReset: sevenDayReset, palette: palette)
        } else {
            drawMenuBarLiveUnavailableHint(palette: palette)
        }
    }

    private func drawMenuBarLiveUnavailableHint(palette: GaugePalette) {
        let mutedColor = systemMonitorMenuBarMutedTextColor()
        drawMenuBarCountdownText(
            text: "--",
            rect: NSRect(x: menuBarRefreshCountdownRect.minX, y: 10.0, width: menuBarRefreshCountdownRect.width, height: 9.0),
            palette: palette,
            color: mutedColor
        )
        drawMenuBarCountdownText(
            text: "--",
            rect: NSRect(x: menuBarRefreshCountdownRect.minX, y: 1.0, width: menuBarRefreshCountdownRect.width, height: 9.0),
            palette: palette,
            color: mutedColor
        )
    }

    private func drawPlanBGauge(fiveHourLeft: Int?, sevenDayLeft: Int?, fiveHourReset: Double?, sevenDayReset: Double?, palette: GaugePalette) {
        drawMenuBarUsagePercentBars(fiveHourLeft: fiveHourLeft, sevenDayLeft: sevenDayLeft, palette: palette)
        drawMenuBarRefreshCountdown(fiveHourReset: fiveHourReset, sevenDayReset: sevenDayReset, palette: palette)
    }

    private func drawMenuBarUsagePercentBars(fiveHourLeft: Int?, sevenDayLeft: Int?, palette: GaugePalette) {
        drawMenuBarUsagePercentRow(window: "5h", quotaLeft: fiveHourLeft, y: 13.0, palette: palette)
        drawMenuBarUsagePercentRow(window: "7d", quotaLeft: sevenDayLeft, y: 4.0, palette: palette)
        let fiveHourRailRect = statusPixelAlignedRect(NSRect(
            x: menuBarHorizontalRailRect.minX,
            y: menuBarHorizontalRailRect.maxY - quotaRailSize.height - 1.0,
            width: quotaRailSize.width,
            height: quotaRailSize.height
        ))
        let sevenDayRailRect = statusPixelAlignedRect(NSRect(
            x: menuBarHorizontalRailRect.minX,
            y: menuBarHorizontalRailRect.minY + 1.0,
            width: quotaRailSize.width,
            height: quotaRailSize.height
        ))
        drawMenuBarHorizontalQuotaBar(value: fiveHourLeft, rect: fiveHourRailRect, palette: palette, fillColor: systemMonitorMenuBarBlue())
        drawMenuBarHorizontalQuotaBar(value: sevenDayLeft, rect: sevenDayRailRect, palette: palette, fillColor: systemMonitorMenuBarBlue())
    }

    private func drawMenuBarUsagePercentRow(window: String, quotaLeft: Int?, y: CGFloat, palette: GaugePalette) {
        let value = quotaLeft
        let windowAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 8.0, weight: .semibold),
            .foregroundColor: systemMonitorMenuBarTextColor(),
        ]
        (window as NSString).draw(
            at: statusPixelAlignedPoint(NSPoint(x: menuBarUsagePercentRect.minX, y: y - 3.0)),
            withAttributes: windowAttrs
        )

        let percentText = compactMenuBarPercentText(value)
        let valueAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 7.2, weight: .medium),
            .foregroundColor: value == nil
                ? systemMonitorMenuBarMutedTextColor()
                : systemMonitorMenuBarTextColor().withAlphaComponent(0.92),
        ]
        (percentText as NSString).draw(
            at: statusPixelAlignedPoint(NSPoint(x: menuBarUsagePercentRect.minX + 18, y: y - 3.0)),
            withAttributes: valueAttrs
        )
    }

    private func compactMenuBarPercentText(_ value: Int?) -> String {
        guard let value else {
            return "--"
        }
        return "\(max(0, min(100, value)))%"
    }

    private func drawMenuBarHorizontalQuotaBar(value: Int?, rect: NSRect, palette: GaugePalette, fillColor: NSColor) {
        let cornerRadius = min(0.9, rect.height / 4.0)
        let trackRect = statusPixelAlignedRect(rect)
        let track = NSBezierPath(roundedRect: trackRect, xRadius: cornerRadius, yRadius: cornerRadius)
        systemMonitorMenuBarMeterTrackColor().setFill()
        track.fill()
        let fillInset: CGFloat = 1.0
        let innerTrackRect = statusPixelAlignedRect(trackRect.insetBy(dx: fillInset, dy: fillInset))

        guard let value else {
            return
        }

        let fraction = clampedFraction(value)
        guard fraction > 0, innerTrackRect.width > 0, innerTrackRect.height > 0 else {
            return
        }

        let minimumVisibleFillWidth: CGFloat = 2.4
        let fillWidth = min(innerTrackRect.width, max(minimumVisibleFillWidth, innerTrackRect.width * fraction))
        let fillRect = statusPixelAlignedRect(
            NSRect(
                x: innerTrackRect.minX,
                y: innerTrackRect.minY,
                width: fillWidth,
                height: innerTrackRect.height
            )
        )
        NSGraphicsContext.saveGraphicsState()
        track.addClip()
        fillColor.setFill()
        fillRect.fill()
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawMenuBarRefreshCountdown(fiveHourReset: Double?, sevenDayReset: Double?, palette: GaugePalette) {
        let fiveHourText = fiveHourResetCountdown(fiveHourReset)
        let sevenDayText = sevenDayResetCountdown(sevenDayReset)
        drawMenuBarCountdownText(text: fiveHourText, rect: NSRect(x: menuBarRefreshCountdownRect.minX, y: 10.0, width: menuBarRefreshCountdownRect.width, height: 9.0), palette: palette)
        drawMenuBarCountdownText(text: sevenDayText, rect: NSRect(x: menuBarRefreshCountdownRect.minX, y: 1.0, width: menuBarRefreshCountdownRect.width, height: 9.0), palette: palette)
    }

    private func drawMenuBarCountdownText(text resetText: String, rect: NSRect, palette: GaugePalette, color: NSColor? = nil) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 7.2, weight: .medium),
            .foregroundColor: color ?? systemMonitorMenuBarTextColor().withAlphaComponent(0.88),
        ]
        (resetText as NSString).draw(
            at: statusPixelAlignedPoint(NSPoint(x: rect.minX + 1.0, y: rect.minY + 1.0)),
            withAttributes: attrs
        )
    }

    private func systemMonitorMenuBarTextColor() -> NSColor {
        isDarkMenuBar()
            ? NSColor(calibratedWhite: 0.97, alpha: 0.96)
            : NSColor(calibratedWhite: 0.07, alpha: 0.95)
    }

    private func systemMonitorMenuBarMutedTextColor() -> NSColor {
        isDarkMenuBar()
            ? NSColor(calibratedWhite: 0.98, alpha: 0.48)
            : NSColor(calibratedWhite: 0.08, alpha: 0.48)
    }

    private func systemMonitorMenuBarWarningColor() -> NSColor {
        NSColor(calibratedRed: 0.50, green: 0.25, blue: 0.21, alpha: 0.90)
    }

    private func systemMonitorMenuBarBlue() -> NSColor {
        // Sampled from the adjacent iStat Menus CPU fill block (#8696B9).
        NSColor(deviceRed: 134.0 / 255.0, green: 150.0 / 255.0, blue: 185.0 / 255.0, alpha: 1.0)
    }

    private func systemMonitorMenuBarMeterTrackColor() -> NSColor {
        // Sampled from the adjacent iStat Menus CPU meter well around the blue fill.
        NSColor(deviceWhite: 0.08, alpha: 0.95)
    }

    private func systemMonitorMenuBarMeterOutlineColor() -> NSColor {
        NSColor(calibratedWhite: 0.02, alpha: 0.86)
    }

    private func drawQuotaRail(value: Int?, rect: NSRect, palette: GaugePalette) {
        drawSegmentedQuotaRail(value: value, rect: rect, palette: palette)
    }

    private func drawSegmentedQuotaRail(value: Int?, rect: NSRect, palette: GaugePalette) {
        drawSignalSegmentedRail(value: value, rect: rect, palette: palette, fillColor: menuBarQuotaColor(value, palette: palette))
    }

    private func drawSignalSegmentedRail(value: Int?, rect: NSRect, palette: GaugePalette, fillColor: NSColor) {
        let gap: CGFloat = 1
        let segmentWidth = max(1, (rect.width - gap * CGFloat(signalRailSegments - 1)) / CGFloat(signalRailSegments))
        let filledSegments = Int(ceil(clampedFraction(value) * CGFloat(signalRailSegments)))
        for index in 0..<signalRailSegments {
            let x = rect.minX + CGFloat(index) * (segmentWidth + gap)
            let segmentRect = NSRect(x: x, y: rect.minY, width: segmentWidth, height: rect.height)
            let segment = NSBezierPath(roundedRect: segmentRect, xRadius: 1.3, yRadius: 1.3)
            if index < filledSegments {
                fillColor.setFill()
            } else {
                palette.track.withAlphaComponent(0.72).setFill()
            }
            segment.fill()
        }
    }

    private func menuBarQuotaColor(_ value: Int?, palette: GaugePalette) -> NSColor {
        guard let value else {
            return palette.mutedText
        }
        switch max(0, min(100, value)) {
        case 0..<20:
            return morandiMenuBarClay()
        case 20..<55:
            return morandiMenuBarTaupe()
        case 55..<78:
            return morandiMenuBarMist()
        default:
            return morandiMenuBarSage()
        }
    }

    private func drawGaugeRail(value: Int?, rect: NSRect, palette: GaugePalette, fillColor: NSColor) {
        let track = NSBezierPath(roundedRect: rect, xRadius: 1.5, yRadius: 1.5)
        palette.track.setFill()
        track.fill()

        let fillWidth = rect.width * clampedFraction(value)
        if fillWidth > 0 {
            let fillRect = NSRect(x: rect.minX, y: rect.minY, width: fillWidth, height: rect.height)
            let fill = NSBezierPath(roundedRect: fillRect, xRadius: 1.5, yRadius: 1.5)
            fillColor.setFill()
            fill.fill()
        }
    }

    private func gaugePalette() -> GaugePalette {
        let theme = currentSignalConsoleTheme()
        return isDarkMenuBar() ? theme.menuDarkPalette : theme.menuLightPalette
    }

    private func isDarkMenuBar() -> Bool {
        let appearance = statusItemView.window?.effectiveAppearance ?? statusItemView.effectiveAppearance
        let match = appearance.bestMatch(from: [.darkAqua, .aqua])
        return match == .darkAqua
    }

    private func bucketedGaugeColor(_ value: Int?) -> NSColor {
        if currentSignalConsoleThemeKey() == monoGraphiteThemeKey {
            guard let value else {
                return monoAccent(isDarkMenuBar() ? 0.74 : 0.34, alpha: 0.50)
            }
            let normalized = CGFloat(max(0, min(100, value))) / 100
            let white = 0.34 + normalized * 0.52
            return monoAccent(white, alpha: 0.96)
        }
        guard let value else {
            return NSColor(calibratedWhite: isDarkMenuBar() ? 0.75 : 0.35, alpha: 0.5)
        }
        switch max(0, min(100, value)) {
        case 0..<10:
            return NSColor(calibratedRed: 0.79, green: 0.20, blue: 0.38, alpha: 0.96)
        case 10..<20:
            return NSColor(calibratedRed: 0.87, green: 0.25, blue: 0.37, alpha: 0.96)
        case 20..<30:
            return NSColor(calibratedRed: 0.93, green: 0.35, blue: 0.31, alpha: 0.96)
        case 30..<40:
            return NSColor(calibratedRed: 0.95, green: 0.47, blue: 0.27, alpha: 0.96)
        case 40..<50:
            return NSColor(calibratedRed: 0.95, green: 0.60, blue: 0.24, alpha: 0.96)
        case 50..<60:
            return NSColor(calibratedRed: 0.89, green: 0.68, blue: 0.28, alpha: 0.96)
        case 60..<70:
            return NSColor(calibratedRed: 0.79, green: 0.76, blue: 0.35, alpha: 0.96)
        case 70..<80:
            return NSColor(calibratedRed: 0.62, green: 0.83, blue: 0.42, alpha: 0.96)
        case 80..<90:
            return NSColor(calibratedRed: 0.41, green: 0.81, blue: 0.50, alpha: 0.96)
        default:
            return NSColor(calibratedRed: 0.14, green: 0.79, blue: 0.60, alpha: 0.96)
        }
    }

    private func quotaColor(_ value: Int?) -> NSColor {
        bucketedGaugeColor(value)
    }

    private func resetLaneColor(_ value: Int?) -> NSColor {
        if currentSignalConsoleThemeKey() == monoGraphiteThemeKey {
            guard let value else {
                return monoAccent(isDarkMenuBar() ? 0.74 : 0.34, alpha: 0.50)
            }
            let normalized = CGFloat(max(0, min(100, value))) / 100
            let white = 0.44 + normalized * 0.42
            return monoAccent(white, alpha: 0.92)
        }
        guard let value else {
            return NSColor(calibratedWhite: isDarkMenuBar() ? 0.75 : 0.35, alpha: 0.5)
        }
        switch max(0, min(100, value)) {
        case 0..<10:
            return NSColor(calibratedRed: 0.84, green: 0.23, blue: 0.25, alpha: 0.92)
        case 10..<20:
            return NSColor(calibratedRed: 0.89, green: 0.29, blue: 0.20, alpha: 0.92)
        case 20..<30:
            return NSColor(calibratedRed: 0.92, green: 0.37, blue: 0.18, alpha: 0.92)
        case 30..<40:
            return NSColor(calibratedRed: 0.95, green: 0.45, blue: 0.18, alpha: 0.92)
        case 40..<50:
            return NSColor(calibratedRed: 0.96, green: 0.54, blue: 0.18, alpha: 0.92)
        case 50..<60:
            return NSColor(calibratedRed: 0.97, green: 0.63, blue: 0.21, alpha: 0.92)
        case 60..<70:
            return NSColor(calibratedRed: 0.97, green: 0.71, blue: 0.24, alpha: 0.92)
        case 70..<80:
            return NSColor(calibratedRed: 0.98, green: 0.77, blue: 0.27, alpha: 0.92)
        case 80..<90:
            return NSColor(calibratedRed: 0.98, green: 0.82, blue: 0.31, alpha: 0.92)
        default:
            return NSColor(calibratedRed: 1.00, green: 0.84, blue: 0.35, alpha: 0.92)
        }
    }

    private func fiveHourResetCountdown(_ epoch: Double?) -> String {
        compactResetCountdown(epoch, includeMinutes: true, includeDays: false)
    }

    private func sevenDayResetCountdown(_ epoch: Double?) -> String {
        compactResetCountdown(epoch, includeMinutes: false, includeDays: true)
    }

    private func compactResetCountdown(_ epoch: Double?, includeMinutes: Bool, includeDays: Bool) -> String {
        guard let epoch else {
            return "--"
        }
        let remaining = Date(timeIntervalSince1970: epoch).timeIntervalSinceNow
        if remaining <= 0 {
            return "now"
        }
        let minutes = max(1, Int(ceil(remaining / 60)))
        if includeMinutes && minutes < 60 {
            return "\(minutes)m"
        }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if includeMinutes, remainingMinutes > 0 {
            return "\(hours)h\(remainingMinutes)m"
        }
        let roundedHours = Int(ceil(Double(minutes) / 60.0))
        if includeDays, minutes >= 24 * 60 {
            let days = roundedHours / 24
            let remainingHours = roundedHours % 24
            if days > 0 {
                return "\(days)d\(remainingHours)h"
            }
        }
        return "\(roundedHours)h"
    }

    private func clampedFraction(_ value: Int?) -> CGFloat {
        guard let value else {
            return 0
        }
        return CGFloat(max(0, min(100, value))) / 100
    }

    private func filledCellCount(_ value: Int?) -> Int {
        guard let value else {
            return 0
        }
        return max(0, min(10, Int((Double(value) / 10.0).rounded())))
    }

    private func nextRefreshInterval(for status: ServiceStatus?) -> TimeInterval {
        guard let status else {
            return normalRefreshInterval
        }
        guard status.ok && !isNonLiveSource(status.source) else {
            return recoveryRefreshInterval
        }
        guard !isUnavailableStatus(status) else {
            return recoveryRefreshInterval
        }
        if let fixed = fixedRefreshInterval() {
            return fixed
        }
        let lowestQuota = [status.fiveHourLeft, status.sevenDayLeft].compactMap { $0 }.min() ?? 100
        if lowestQuota < 10 {
            return criticalRefreshInterval
        }
        if lowestQuota < 25 {
            return watchRefreshInterval
        }
        return normalRefreshInterval
    }

    private func nextRefreshCountdownText(now: Date) -> String {
        if isRefreshing {
            return "now"
        }
        guard let nextRefreshAt else {
            return "--"
        }
        let remaining = max(0, Int(ceil(nextRefreshAt.timeIntervalSince(now))))
        if remaining <= 0 {
            return "now"
        }
        if remaining < 60 {
            return String(format: "0:%02d", remaining)
        }
        let minutes = remaining / 60
        let seconds = remaining % 60
        if minutes < 100 {
            return String(format: "%d:%02d", minutes, seconds)
        }
        return "\(Int(ceil(Double(remaining) / 60.0)))m"
    }

    private func scheduleNextRefresh(after interval: TimeInterval) {
        timer?.invalidate()
        nextRefreshAt = Date().addingTimeInterval(interval)
        let nextTimer = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            self?.refresh()
        }
        applyTimerTolerance(nextTimer, interval: interval)
        timer = nextTimer
        RunLoop.main.add(nextTimer, forMode: .common)
    }

    private func appendLog(_ value: String) {
        let entry = "[\(Date())] \(value)"
        runtimeLogQueue.async { [weak self] in
            guard let self else {
                return
            }
            self.runtimeLogMessages.append(entry)
            let overflow = self.runtimeLogMessages.count - self.maxRuntimeLogMessages
            if overflow > 0 {
                self.runtimeLogMessages.removeFirst(overflow)
            }
        }
    }

    private func addDisabled(_ title: String, monospaced: Bool = false) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        if monospaced {
            item.attributedTitle = NSAttributedString(
                string: title,
                attributes: [
                    .font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular),
                    .foregroundColor: NSColor.secondaryLabelColor,
                ]
            )
        }
        menu.addItem(item)
    }

    private func addAction(_ title: String, action: Selector) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
    }

    private func percent(_ value: Int?) -> String {
        guard let value else {
            return "--"
        }
        return "\(value)%"
    }

    private func barString(_ value: Int?) -> String {
        let filled = filledCellCount(value)
        return String(repeating: "█", count: filled) + String(repeating: "░", count: 10 - filled)
    }

    private func planTitle(_ status: ServiceStatus) -> String {
        guard let plan = status.plan, !plan.isEmpty, plan != "?" else {
            return "Codex"
        }
        if plan.lowercased() == "pro" {
            return "Codex Pro"
        }
        return "Codex \(plan.replacingOccurrences(of: "_", with: " ").capitalized)"
    }

    private func refreshLabel(_ status: ServiceStatus) -> String {
        _ = status
        return liveRefreshMenuLabel
    }

    private func statusTooltipTitle(_ snapshot: UsageSnapshot) -> String {
        snapshot.title
    }

    private func isNonLiveSource(_ source: String?) -> Bool {
        guard let source else {
            return false
        }
        return source != "live"
    }

    private func clipped(_ text: String, limit: Int) -> String {
        let compact = text.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard compact.count > limit else {
            return compact
        }
        let end = compact.index(compact.startIndex, offsetBy: limit)
        return String(compact[..<end]) + "..."
    }

    private func isoDate(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return fractional.date(from: value) ?? plain.date(from: value)
    }

    private func relativeAgeText(_ value: String?, now: Date = Date()) -> String {
        guard let value, let date = isoDate(value) else {
            return "unknown"
        }
        let seconds = max(0, Int(now.timeIntervalSince(date)))
        if seconds < 60 {
            return "now"
        }
        let minutes = seconds / 60
        if minutes < 60 {
            return "\(minutes)m ago"
        }
        let hours = minutes / 60
        if hours < 48 {
            return "\(hours)h ago"
        }
        let days = max(2, hours / 24)
        return "\(days)d ago"
    }

    private func shortTime(_ value: String) -> String {
        let date = isoDate(value)
        guard let date else {
            return value
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func resetCountdown(_ epoch: Double?) -> String {
        guard let epoch else {
            return "--"
        }
        let remaining = Date(timeIntervalSince1970: epoch).timeIntervalSinceNow
        if remaining <= 0 {
            return "now"
        }
        let minutes = max(1, Int(ceil(remaining / 60)))
        if minutes < 60 {
            return "in \(minutes)m"
        }
        if minutes < 24 * 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return remainingMinutes > 0 ? "in \(hours)h \(remainingMinutes)m" : "in \(hours)h"
        }
        let days = minutes / (24 * 60)
        let remainingHours = (minutes % (24 * 60)) / 60
        return remainingHours > 0 ? "in \(days)d \(remainingHours)h" : "in \(days)d"
    }

    private func infoString(_ key: String, fallback: String) -> String {
        (Bundle.main.object(forInfoDictionaryKey: key) as? String) ?? fallback
    }

    private func resolveUsagePath() -> String {
        let configured = infoString("CodexGaugeUsagePath", fallback: "codex_status.py")
        if configured.hasPrefix("/") {
            return configured
        }
        return URL(fileURLWithPath: resourcesDir, isDirectory: true)
            .appendingPathComponent(configured)
            .path
    }

    private func safeDiagnosticsText() -> String {
        let status = snapshot?.codex
        let source = status?.source ?? "unavailable"
        let helperState = FileManager.default.isReadableFile(atPath: usagePath) ? "exists" : "missing"
        let launchState = isLaunchAgentConfigured() ? "configured" : "missing"
        let notificationState = notificationsEnabled() ? "enabled" : "disabled"
        let lastRefresh = status?.dataTime ?? snapshot?.updatedAt ?? "none"
        let error = clipped(status?.error ?? lastError ?? "none", limit: 180)
        return [
            "Codex Gauge Diagnostics",
            "App version: \(appVersion)",
            "Helper path: bundled codex_status.py \(helperState)",
            "Usage storage: none; launch at login uses a LaunchAgent",
            "Current data source: \(source)",
            "Last refresh time: \(lastRefresh)",
            "Last error summary: \(error)",
            "LaunchAgent state: \(launchState)",
            "Notifications permission: \(notificationState)",
            "Refresh mode: \(currentRefreshMode())",
            "Updater state: \(lastUpdateSummary ?? "manual check only")",
            "Excludes: browser cookies, ~/.codex/auth.json, session files, histories, caches, reports, disk logs, prompts, responses",
        ].joined(separator: "\n")
    }

    private func openURL(_ value: String) {
        guard let url = URL(string: value) else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func installLaunchAgentForCurrentApp() -> Bool {
        let manager = FileManager.default
        let agentDir = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
        let appPath = Bundle.main.bundlePath
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
          <key>Label</key>
          <string>\(xmlEscaped(launchAgentLabel))</string>
          <key>ProgramArguments</key>
          <array>
            <string>/usr/bin/open</string>
            <string>-na</string>
            <string>\(xmlEscaped(appPath))</string>
          </array>
          <key>RunAtLoad</key>
          <true/>
        </dict>
        </plist>
        """
        do {
            try manager.createDirectory(at: agentDir, withIntermediateDirectories: true, attributes: nil)
            try plist.write(toFile: launchAgentPlistPath, atomically: true, encoding: .utf8)
            appendLog("launch agent plist installed path=\(launchAgentPlistPath)")
            return true
        } catch {
            appendLog("launch agent install failed error=\(error.localizedDescription)")
            return false
        }
    }

    private func removeLaunchAgentPlist() {
        try? FileManager.default.removeItem(atPath: launchAgentPlistPath)
        appendLog("launch agent plist removed path=\(launchAgentPlistPath)")
    }

    private func isLaunchAgentConfigured() -> Bool {
        FileManager.default.fileExists(atPath: launchAgentPlistPath)
    }

    private func currentAppBinaryPath() -> String {
        let bundlePath = Bundle.main.bundlePath
        if bundlePath.hasSuffix(".app") {
            return URL(fileURLWithPath: bundlePath)
                .appendingPathComponent("Contents/MacOS/CodexGauge")
                .path
        }
        return CommandLine.arguments.first ?? bundlePath
    }

    private func launchctlDomain() -> String {
        "gui/\(getuid())"
    }

    private func runLaunchctl(arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            appendLog("launchctl failed args=\(arguments.joined(separator: " ")) error=\(error.localizedDescription)")
            return false
        }
    }

    private func xmlEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private func unloadLaunchAgent() {
        _ = runLaunchctl(arguments: ["bootout", "\(launchctlDomain())/\(launchAgentLabel)"])
    }

}

if let renderIndex = CommandLine.arguments.firstIndex(of: "--render-signal-console-fixtures") {
    let outputDirectory = CommandLine.arguments.indices.contains(renderIndex + 1)
        ? CommandLine.arguments[renderIndex + 1]
        : renderedSignalConsoleFixtureDirectory
    do {
        try renderSignalConsoleFixtures(outputDirectory: outputDirectory)
        exit(0)
    } catch {
        fputs("Codex Gauge fixture render failed: \(error.localizedDescription)\n", stderr)
        exit(1)
    }
}

let app = NSApplication.shared
private let delegate = CodexGaugeApp()
app.delegate = delegate
app.run()
