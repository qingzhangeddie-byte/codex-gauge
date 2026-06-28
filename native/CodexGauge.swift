import Cocoa
import Darwin
import Foundation
import IOKit.ps
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

private struct SSDTemperatureStatus: Decodable {
    let ok: Bool
    let temperatureC: Int?
    let source: String?
    let error: String?
}

private struct HistorySample: Codable {
    let time: String
    let source: String
    let fiveHourLeft: Int?
    let sevenDayLeft: Int?
}

private struct TemperatureSample: Codable {
    let time: String
    let temperatureC: Int?
    let ok: Bool
    let timestamp: Double?

    init(time: String, temperatureC: Int?, ok: Bool, timestamp: Double? = nil) {
        self.time = time
        self.temperatureC = temperatureC
        self.ok = ok
        self.timestamp = timestamp
    }
}

private struct SystemMetricSample: Codable {
    let time: String
    let cpuPercent: Int?
    let ramPercent: Int?
    let ok: Bool
    let timestamp: Double?

    init(time: String, cpuPercent: Int?, ramPercent: Int?, ok: Bool, timestamp: Double? = nil) {
        self.time = time
        self.cpuPercent = cpuPercent
        self.ramPercent = ramPercent
        self.ok = ok
        self.timestamp = timestamp
    }
}

private struct BatteryStatus: Equatable {
    let percent: Int?
    let isPluggedIn: Bool?
    let isCharging: Bool?
    let hasBattery: Bool
    let powerSaverActive: Bool
    let source: String
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

private func temperatureHistorySummaryText(_ samples: [TemperatureSample]) -> String {
    let valid = samples.filter { $0.ok && $0.temperatureC != nil }
    if valid.isEmpty {
        return "SSD temp unavailable"
    }
    if valid.count == 1 {
        return "collecting"
    }
    return "last 10m"
}

private func systemMetricPercentText(_ value: Int?) -> String {
    guard let value else {
        return "--"
    }
    return "\(max(0, min(100, value)))%"
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

private struct TrendContext {
    let sampleCount: Int
    let liveSampleCount: Int
    let firstTime: String?
    let lastTime: String?
    let latestSource: String?
    let summaryText: String
}

private struct UsageReportSummary {
    let windowLabel: String
    let sampleCount: Int
    let liveSampleCount: Int
    let nonLiveSampleCount: Int
    let firstFiveHourLeft: Int?
    let latestFiveHourLeft: Int?
    let firstSevenDayLeft: Int?
    let latestSevenDayLeft: Int?
    let largestFiveHourDrop: Int?
    let largestSevenDayDrop: Int?
    let sourceCounts: [String: Int]
    let generatedAt: Date
}

private struct InlineUsageReportSummary {
    let fiveHourMovement: String
    let sevenDayMovement: String
    let todaySummary: String
}

private struct SignalConsoleLayout {
    let bounds: NSRect
    private let margin: CGFloat = 20
    private let gutter: CGFloat = 12
    private let innerInset: CGFloat = 16

    func splitHorizontally(_ rect: NSRect, columns: Int, gap: CGFloat) -> [NSRect] {
        guard columns > 0 else {
            return []
        }
        let totalGap = gap * CGFloat(columns - 1)
        let itemWidth = (rect.width - totalGap) / CGFloat(columns)
        return (0..<columns).map { index in
            NSRect(
                x: rect.minX + CGFloat(index) * (itemWidth + gap),
                y: rect.minY,
                width: itemWidth,
                height: rect.height
            )
        }
    }

    var panelRect: NSRect {
        bounds.insetBy(dx: 1, dy: 1)
    }

    var headerTitleRect: NSRect {
        NSRect(x: margin, y: 18, width: 300, height: 24)
    }

    var headerSignalPillRect: NSRect {
        NSRect(x: 344, y: 16, width: 70, height: 28)
    }

    var headerSourcePillRect: NSRect {
        NSRect(x: 422, y: 16, width: 118, height: 28)
    }

    var statusStripRect: NSRect {
        NSRect(x: margin, y: 54, width: bounds.width - margin * 2, height: 42)
    }

    func statusStripDetailRect(unavailable: Bool) -> NSRect {
        let rect = statusStripRect
        return NSRect(x: rect.minX + 124, y: rect.minY + 9, width: unavailable ? 176 : 268, height: 18)
    }

    var closedSignalStateRect: NSRect {
        let rect = statusStripRect
        return NSRect(x: rect.maxX - 210, y: rect.minY + 7, width: 96, height: 28)
    }

    var nextRefreshPillRect: NSRect {
        let rect = statusStripRect
        return NSRect(x: rect.maxX - 104, y: rect.minY + 7, width: 86, height: 28)
    }

    var heroCardRect: NSRect {
        NSRect(x: margin, y: 108, width: bounds.width - margin * 2, height: 152)
    }

    var fiveHourQuotaRowRect: NSRect {
        NSRect(x: margin + 14, y: 124, width: bounds.width - 68, height: 58)
    }

    var sevenDayQuotaRowRect: NSRect {
        NSRect(x: margin + 14, y: 190, width: bounds.width - 68, height: 58)
    }

    var trendCardRect: NSRect {
        NSRect(x: margin, y: 274, width: 248, height: 122)
    }

    var reportCardRect: NSRect {
        let trend = trendCardRect
        return NSRect(x: trend.maxX + gutter, y: trend.minY, width: bounds.width - margin - trend.maxX - gutter, height: trend.height)
    }

    var reportTodayTextRect: NSRect {
        let card = reportCardRect
        return NSRect(x: card.minX + innerInset, y: card.minY + 34, width: 212, height: 12)
    }

    var reportMetricRects: [NSRect] {
        let card = reportCardRect
        return splitHorizontally(
            NSRect(x: card.minX + innerInset, y: card.minY + 52, width: card.width - innerInset * 2, height: 32),
            columns: 2,
            gap: 10
        )
    }

    var copyReportButtonRect: NSRect {
        let card = reportCardRect
        return NSRect(x: card.minX + 18, y: card.maxY - 32, width: 108, height: 30)
    }

    var clearDataButtonRect: NSRect {
        let card = reportCardRect
        return NSRect(x: card.minX + 136, y: card.maxY - 32, width: 106, height: 30)
    }

    var healthRibbonRect: NSRect {
        NSRect(x: margin, y: 410, width: bounds.width - margin * 2, height: 66)
    }

    var healthStatusGridRect: NSRect {
        let rect = healthRibbonRect
        return NSRect(x: rect.minX + 118, y: rect.minY + 14, width: 300, height: 30)
    }

    var runCheckButtonRect: NSRect {
        let rect = healthRibbonRect
        return NSRect(x: rect.maxX - 90, y: rect.minY + 30, width: 82, height: 30)
    }

    var bottomCommandButtonRects: [NSRect] {
        [
            NSRect(x: margin, y: 496, width: 122, height: 40),
            NSRect(x: margin + 130, y: 496, width: 122, height: 40),
            NSRect(x: margin + 260, y: 496, width: 122, height: 40),
            NSRect(x: margin + 390, y: 496, width: 130, height: 40),
        ]
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
    let fiveHourResetProgress: Int?
    let sevenDayResetProgress: Int?
    let fiveHourHistory: [Int]
    let sevenDayHistory: [Int]
    let fiveHourTrendText: String
    let sevenDayTrendText: String
    let trendContextText: String
    let temperatureHistory: [TemperatureSample]
    let currentTemperatureText: String
    let temperatureHistoryText: String
    let systemMetricHistory: [SystemMetricSample]
    let cpuUsageText: String
    let ramUsageText: String
    let batteryStatusText: String
    let batteryPercent: Int?
    let powerSaverText: String
    let refreshCadenceText: String
    let hardwareSignalsVisible: Bool
    let reportFiveHourMovement: String
    let reportSevenDayMovement: String
    let reportTodaySummary: String
    let healthSummaryText: String
    let doctorChecks: [DoctorCheck]
    let lastRefreshText: String
    let liveAgeText: String
    let nextRefreshText: String
    let source: String?
    let isUnavailable: Bool
    let isRefreshing: Bool
}

private final class SignalConsolePanelView: NSView {
    private let model: SignalConsoleModel
    private let theme: SignalConsoleTheme
    private let temperatureStatusTextWidth: CGFloat = 112
    private weak var target: AnyObject?
    private let runCheckAction: Selector
    private let generateReportAction: Selector
    private let copyDiagnosticsAction: Selector
    private let clearDataAction: Selector
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
        runCheckAction: Selector,
        generateReportAction: Selector,
        copyDiagnosticsAction: Selector,
        clearDataAction: Selector,
        openCodexAction: Selector,
        refreshAction: Selector,
        preferencesAction: Selector,
        quitAction: Selector
    ) {
        self.model = model
        self.theme = theme
        self.target = target
        self.runCheckAction = runCheckAction
        self.generateReportAction = generateReportAction
        self.copyDiagnosticsAction = copyDiagnosticsAction
        self.clearDataAction = clearDataAction
        self.openCodexAction = openCodexAction
        self.refreshAction = refreshAction
        self.preferencesAction = preferencesAction
        self.quitAction = quitAction
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        addSignalConsoleButtons()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        drawSignalConsolePanel()
    }

    private func addSignalConsoleButtons() {
        let layout = SignalConsoleLayout(bounds: bounds)
        let commandRects = layout.bottomCommandButtonRects
        addButton(title: "Copy summary", frame: layout.copyReportButtonRect, action: generateReportAction, style: .primary)
        addButton(title: "Clear legacy", frame: layout.clearDataButtonRect, action: clearDataAction, style: .secondary)
        addButton(title: "Run Check", frame: layout.runCheckButtonRect, action: runCheckAction, style: .secondary)
        addButton(title: "Open Codex", frame: commandRects[0], action: openCodexAction, style: .command)
        addButton(title: "Refresh Now", frame: commandRects[1], action: refreshAction, style: .command)
        addButton(title: "Preferences", frame: commandRects[2], action: preferencesAction, style: .command)
        addButton(title: "Quit", frame: commandRects[3], action: quitAction, style: .command)
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
        button.layer?.cornerRadius = style == .command ? 12 : 10
        button.layer?.backgroundColor = buttonBackground(style).cgColor
        button.attributedTitle = NSAttributedString(
            string: title,
            attributes: textAttributes(
                size: 13,
                weight: style == .primary ? .semibold : .medium,
                color: buttonTextColor(style)
            )
        )
        addSubview(button)
    }

    private func buttonBackground(_ style: SignalButtonStyle) -> NSColor {
        switch style {
        case .primary:
            return mintAccent
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
        drawStatusStrip()
        drawSignalHeroCard()
        drawTrendSection()
        drawReportSection()
        drawHealthRibbon()
        drawDivider(y: 486)
    }

    private func drawPanelBackground() {
        let layout = SignalConsoleLayout(bounds: bounds)
        let rect = layout.panelRect
        let background = NSBezierPath(roundedRect: rect, xRadius: 18, yRadius: 18)
        NSGradient(colors: [
            panelStrongBackground,
            panelBackground,
        ])?.draw(in: background, angle: 90)
        panelBorder.setStroke()
        background.lineWidth = 1
        background.stroke()
        drawPanelAccentRail()
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
        let next = layout.headerSignalPillRect
        let source = layout.headerSourcePillRect
        drawText("Codex Gauge  •  Signal Console", x: title.minX, y: title.minY, width: title.width, height: title.height, size: 15, weight: .semibold, color: textPrimary)
        drawPill(text: headerSignalText(), rect: next, color: headerSignalColor().withAlphaComponent(0.12), dotColor: headerSignalColor())
        drawPill(text: model.sourcePill, rect: source, color: theme.secondaryButtonBackground)
    }

    private func drawStatusStrip() {
        let layout = SignalConsoleLayout(bounds: bounds)
        let rect = layout.statusStripRect
        let stateColor = sourceColor(source: model.source, unavailable: model.isUnavailable)
        drawRoundedRect(rect, radius: 13, fill: stateColor.withAlphaComponent(0.08), stroke: panelBorder.withAlphaComponent(0.42))
        drawCircle(center: NSPoint(x: rect.minX + 18, y: rect.midY), radius: 4, color: stateColor, stroke: nil)
        drawText("Live signal", x: rect.minX + 30, y: rect.minY + 9, width: 86, height: 18, size: 13, weight: .bold, color: stateColor)
        let detail = layout.statusStripDetailRect(unavailable: model.isUnavailable)
        drawText(statusStripDetail(), x: detail.minX, y: detail.minY, width: detail.width, height: detail.height, size: 12, weight: .regular, color: textSecondary)
        if model.isUnavailable {
            drawClosedSignalState(in: layout.closedSignalStateRect)
        }
        let next = layout.nextRefreshPillRect
        drawRoundedRect(next, radius: 9, fill: theme.commandButtonBackground, stroke: panelBorder.withAlphaComponent(0.26))
        drawText("next", x: next.minX + 10, y: next.minY + 6, width: 30, height: 14, size: 10, weight: .regular, color: textMuted)
        drawText(model.nextRefreshText, x: next.minX + 46, y: next.minY + 6, width: 42, height: 14, size: 10, weight: .semibold, color: textPrimary, mono: true)
    }

    private func drawClosedSignalState(in rect: NSRect) {
        drawRoundedRect(rect, radius: rect.height / 2, fill: amberSoft, stroke: panelBorder.withAlphaComponent(0.26))
        drawCircle(center: NSPoint(x: rect.minX + 14, y: rect.midY), radius: 3.5, color: amberAccent, stroke: nil)
        drawText("No live quota yet", x: rect.minX + 24, y: rect.minY + 7, width: rect.width - 32, height: 14, size: 9, weight: .medium, color: textPrimary)
    }

    private func drawSignalHeroCard() {
        let layout = SignalConsoleLayout(bounds: bounds)
        let card = layout.heroCardRect
        drawRoundedGradient(
            card,
            radius: 16,
            gradient: NSGradient(colors: [
                panelStrongBackground,
                panelSoftBackground,
            ]),
            stroke: panelBorder
        )
        drawQuotaWindowRow(
            window: "5h",
            label: "5-hour quota left",
            value: model.fiveHourLeft,
            resetText: model.fiveHourResetText,
            resetProgress: model.fiveHourResetProgress,
            rect: layout.fiveHourQuotaRowRect
        )
        drawQuotaWindowRow(
            window: "7d",
            label: "7-day quota left",
            value: model.sevenDayLeft,
            resetText: model.sevenDayResetText,
            resetProgress: model.sevenDayResetProgress,
            rect: layout.sevenDayQuotaRowRect
        )
    }

    private func drawQuotaWindowRow(window: String, label: String, value: Int?, resetText: String, resetProgress: Int?, rect: NSRect) {
        drawRoundedRect(rect, radius: 13, fill: theme.commandButtonBackground, stroke: panelBorder.withAlphaComponent(0.48))
        drawText(window, x: rect.minX + 14, y: rect.minY + 13, width: 38, height: 22, size: 19, weight: .bold, color: textPrimary, mono: true)
        drawText("window", x: rect.minX + 14, y: rect.minY + 35, width: 48, height: 14, size: 8, weight: .bold, color: textSecondary)
        drawText(label, x: rect.minX + 70, y: rect.minY + 12, width: 160, height: 16, size: 11, weight: .medium, color: textSecondary)
        drawText(percentText(value), x: rect.minX + 236, y: rect.minY + 9, width: 54, height: 22, size: 17, weight: .bold, color: value == nil ? textMuted : quotaColor(value), mono: true)
        drawQuotaRail(value: value, rect: NSRect(x: rect.minX + 70, y: rect.minY + 36, width: 196, height: 10))
        drawText("reset", x: rect.minX + 288, y: rect.minY + 12, width: 34, height: 16, size: 10, weight: .medium, color: textSecondary)
        drawText(resetText, x: rect.maxX - 76, y: rect.minY + 12, width: 60, height: 16, size: 10, weight: .semibold, color: resetTextColor(resetText), mono: true)
        drawResetCountdownLane(value: resetProgress, rect: NSRect(x: rect.minX + 288, y: rect.minY + 36, width: 146, height: 9))
    }

    private func drawTrendSection() {
        let layout = SignalConsoleLayout(bounds: bounds)
        let card = layout.trendCardRect
        drawRoundedRect(card, radius: 15, fill: panelSoftBackground, stroke: panelBorder.withAlphaComponent(0.50))
        drawText("Movement", x: card.minX + 16, y: card.minY + 14, width: 86, height: 18, size: 12, weight: .bold, color: textPrimary)
        drawText("last 24h", x: card.minX + 104, y: card.minY + 16, width: 44, height: 14, size: 8.6, weight: .regular, color: textMuted)
        drawText("Quota movement", x: card.minX + 16, y: card.minY + 33, width: 78, height: 12, size: 8.2, weight: .bold, color: textMuted)
        drawTrendContext()
        drawTrendRow(label: "5h", text: model.fiveHourTrendText, values: model.fiveHourHistory, y: card.minY + 52)
        drawTrendRow(label: "7d", text: model.sevenDayTrendText, values: model.sevenDayHistory, y: card.minY + 73)
        if hardwareSignalsVisible() {
            drawSystemMetricMovementRows(in: card)
            drawTemperatureMovementRow(in: card)
            drawBatteryStatusRow(in: card)
        } else {
            drawBatteryModeStatusRow(in: card)
        }
    }

    private func hardwareSignalsVisible() -> Bool {
        model.hardwareSignalsVisible
    }

    private func drawTrendContext() {
        let layout = SignalConsoleLayout(bounds: bounds)
        let card = layout.trendCardRect
        drawText(model.trendContextText, x: card.minX + 96, y: card.minY + 33, width: card.width - 176, height: 12, size: 7.2, weight: .regular, color: textMuted)
    }

    private func drawTrendRow(label: String, text: String, values: [Int], y: CGFloat) {
        let layout = SignalConsoleLayout(bounds: bounds)
        let card = layout.trendCardRect
        let signalText = "\(label) \(trendSignalText(values: values, fallback: text))"
        let labelX = card.minX + 16
        let sparklineRect = NSRect(x: card.minX + 84, y: y - 4, width: 46, height: 18)
        drawText(signalText, x: labelX, y: y - 2, width: 52, height: 16, size: 9.2, weight: .bold, color: trendSignalColor(values: values), mono: true)
        drawTrendSparkline(values: values, rect: sparklineRect)
        drawTrendDeltaText(values: values, y: y)
    }

    private func drawTrendDeltaText(values: [Int], y: CGFloat) {
        let layout = SignalConsoleLayout(bounds: bounds)
        let card = layout.trendCardRect
        let text = trendDeltaText(values)
        drawText(
            text,
            x: card.minX + 136,
            y: y,
            width: 36,
            height: 16,
            size: text.count > 6 ? 7.8 : 9.5,
            weight: .semibold,
            color: trendDeltaTextColor(values: values),
            mono: true
        )
    }

    private func drawSystemMetricMovementRows(in card: NSRect) {
        let cpuValues = model.systemMetricHistory.compactMap { $0.cpuPercent }
        let ramValues = model.systemMetricHistory.compactMap { $0.ramPercent }
        let cpuColor = systemMetricLineColor(label: "CPU")
        let ramColor = systemMetricLineColor(label: "RAM")
        drawSystemMetricMovementRow(label: "CPU", valueText: model.cpuUsageText, values: cpuValues, color: cpuColor, rect: NSRect(x: card.maxX - 66, y: card.minY + 52, width: 50, height: 17))
        drawSystemMetricMovementRow(label: "RAM", valueText: model.ramUsageText, values: ramValues, color: ramColor, rect: NSRect(x: card.maxX - 66, y: card.minY + 73, width: 50, height: 17))
    }

    private func drawSystemMetricMovementRow(label: String, valueText: String, values: [Int], color: NSColor, rect: NSRect) {
        drawText(label, x: rect.minX, y: rect.minY, width: 22, height: 10, size: 7.0, weight: .bold, color: color)
        drawText(valueText, x: rect.maxX - 26, y: rect.minY, width: 26, height: 10, size: 7.0, weight: .bold, color: valueText == "--" ? textMuted : textPrimary, mono: true)
        drawSystemMetricSparkline(values: values, rect: NSRect(x: rect.minX, y: rect.minY + 10, width: rect.width, height: 6), color: color)
    }

    private func drawSystemMetricSparkline(values: [Int], rect: NSRect, color: NSColor) {
        let baseline = NSBezierPath()
        baseline.move(to: NSPoint(x: rect.minX, y: rect.midY))
        baseline.line(to: NSPoint(x: rect.maxX, y: rect.midY))
        baseline.lineWidth = 0.8
        baseline.setLineDash([2, 3], count: 2, phase: 0)
        textMuted.withAlphaComponent(0.26).setStroke()
        baseline.stroke()

        guard values.count >= 2 else {
            return
        }
        let shown = Array(values.suffix(28))
        let path = NSBezierPath()
        for (index, value) in shown.enumerated() {
            let x = rect.minX + rect.width * CGFloat(index) / CGFloat(max(1, shown.count - 1))
            let y = rect.maxY - rect.height * clampedSystemMetricFraction(value)
            let point = NSPoint(x: x, y: y)
            if index == 0 {
                path.move(to: point)
            } else {
                path.line(to: point)
            }
        }
        path.lineWidth = 1.15
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        color.withAlphaComponent(0.86).setStroke()
        path.stroke()
    }

    private func clampedSystemMetricFraction(_ value: Int) -> CGFloat {
        CGFloat(max(0, min(100, value))) / 100.0
    }

    private func systemMetricLineColor(label: String) -> NSColor {
        if theme.key == monoGraphiteThemeKey {
            return textSecondary
        }
        return label == "CPU" ? theme.blueAccent : theme.mintAccent
    }

    private func drawTemperatureMovementRow(in card: NSRect) {
        let row = NSRect(x: card.minX + 16, y: card.minY + 92, width: card.width - 32, height: 24)
        let curveRect = NSRect(x: row.minX + 86, y: row.minY + 4, width: row.width - 134, height: 19)
        let color = temperatureCurveColor(samples: model.temperatureHistory)
        drawText("SSD temp", x: row.minX, y: row.minY + 1, width: 58, height: 12, size: 8.6, weight: .bold, color: color)
        drawText(model.temperatureHistoryText, x: row.minX, y: row.minY + 14, width: temperatureStatusTextWidth, height: 10, size: 7.5, weight: .regular, color: textMuted)
        drawText(model.currentTemperatureText, x: row.maxX - 43, y: row.minY + 3, width: 43, height: 14, size: 9.2, weight: .bold, color: color, mono: true)
        if model.temperatureHistoryText == "SSD temp unavailable" || model.temperatureHistoryText == "collecting" {
            drawTemperatureUnavailableCurve(rect: curveRect)
        } else {
            drawTemperatureCurve(samples: model.temperatureHistory, rect: curveRect)
        }
        drawText("10m", x: curveRect.minX, y: row.minY + 16, width: 20, height: 8, size: 5.8, weight: .regular, color: textMuted)
        drawText("now", x: curveRect.maxX - 18, y: row.minY + 16, width: 20, height: 8, size: 5.8, weight: .regular, color: textMuted)
    }

    private func drawBatteryStatusRow(in card: NSRect) {
        let chip = NSRect(x: card.maxX - 96, y: card.minY + 13, width: 80, height: 20)
        let color = model.powerSaverText.contains("active") ? amberAccent : textSecondary
        drawRoundedRect(chip, radius: 10, fill: color.withAlphaComponent(0.10), stroke: color.withAlphaComponent(0.30))
        drawSignalConsoleBatteryIcon(percent: model.batteryPercent, rect: NSRect(x: chip.minX + 7, y: chip.minY + 2, width: 26, height: 16), color: color)
        drawText(compactSignalConsoleBatteryText(), x: chip.minX + 38, y: chip.minY + 4, width: 34, height: 12, size: 8.2, weight: .semibold, color: textPrimary, mono: true)
        drawText(model.refreshCadenceText, x: card.maxX - 72, y: card.minY + 33, width: 56, height: 12, size: 7.2, weight: .medium, color: textMuted, mono: true)
        if model.powerSaverText.contains("active") {
            drawText("Saver on", x: card.minX + 160, y: card.minY + 33, width: 36, height: 12, size: 7.0, weight: .bold, color: color)
        }
    }

    private func drawBatteryModeStatusRow(in card: NSRect) {
        let row = NSRect(x: card.minX + 16, y: card.minY + 90, width: card.width - 32, height: 26)
        let color = amberAccent
        drawRoundedGradient(
            row,
            radius: 12,
            gradient: NSGradient(colors: [
                amberAccent.withAlphaComponent(0.20),
                theme.commandButtonBackground,
            ]),
            stroke: amberAccent.withAlphaComponent(0.34)
        )
        drawSignalConsoleBatteryIcon(percent: model.batteryPercent, rect: NSRect(x: row.minX + 8, y: row.minY + 4, width: 34, height: 18), color: color)
        drawText("Battery mode", x: row.minX + 50, y: row.minY + 4, width: 84, height: 12, size: 8.7, weight: .bold, color: color)
        drawText(model.powerSaverText, x: row.minX + 50, y: row.minY + 15, width: 92, height: 10, size: 7.0, weight: .medium, color: textPrimary)
        drawText(model.batteryStatusText, x: row.maxX - 70, y: row.minY + 4, width: 62, height: 12, size: 8.4, weight: .bold, color: textPrimary, mono: true)
        drawText(model.refreshCadenceText, x: row.maxX - 70, y: row.minY + 15, width: 62, height: 10, size: 7.0, weight: .medium, color: textMuted, mono: true)
    }

    private func compactSignalConsoleBatteryText() -> String {
        if let percent = model.batteryPercent {
            return "\(percent)%"
        }
        let prefix = "Battery "
        if model.batteryStatusText.hasPrefix(prefix) {
            return String(model.batteryStatusText.dropFirst(prefix.count))
        }
        return model.batteryStatusText.count > 5 ? "--" : model.batteryStatusText
    }

    private func drawSignalConsoleBatteryIcon(percent: Int?, rect: NSRect, color: NSColor) {
        let shellRect = rect.insetBy(dx: 1.4, dy: 4.2)
        drawRoundedRect(shellRect, radius: 4.5, fill: panelBackground.withAlphaComponent(0.34), stroke: color.withAlphaComponent(0.66))
        drawRoundedRect(
            NSRect(x: shellRect.maxX - 0.4, y: shellRect.midY - 4.2, width: 3.8, height: 8.4),
            radius: 1.7,
            fill: color.withAlphaComponent(0.66),
            stroke: nil
        )
        let fillRect = shellRect.insetBy(dx: 3.4, dy: 3.5)
        let fillWidth = max(2.0, fillRect.width * clamped(percent))
        drawRoundedRect(
            NSRect(x: fillRect.minX, y: fillRect.minY, width: fillWidth, height: fillRect.height),
            radius: 2.2,
            fill: color.withAlphaComponent(0.86),
            stroke: nil
        )
    }

    private func drawTemperatureCurve(samples: [TemperatureSample], rect: NSRect) {
        let points = smoothedTemperaturePoints(samples: samples, rect: rect)
        guard points.count >= 2 else {
            drawTemperatureUnavailableCurve(rect: rect)
            return
        }
        let color = temperatureCurveColor(samples: samples)
        drawTemperatureGraphGrid(rect: rect)
        let line = NSBezierPath()
        line.move(to: points[0])
        for index in 1..<points.count {
            let previous = points[index - 1]
            let point = points[index]
            let controlX = (previous.x + point.x) / 2
            line.curve(
                to: point,
                controlPoint1: NSPoint(x: controlX, y: previous.y),
                controlPoint2: NSPoint(x: controlX, y: point.y)
            )
        }
        let fill = line.copy() as! NSBezierPath
        fill.line(to: NSPoint(x: points.last?.x ?? rect.maxX, y: rect.maxY))
        fill.line(to: NSPoint(x: points.first?.x ?? rect.minX, y: rect.maxY))
        fill.close()
        color.withAlphaComponent(0.12).setFill()
        fill.fill()
        line.lineWidth = 1.7
        line.lineJoinStyle = .round
        line.lineCapStyle = .round
        color.withAlphaComponent(0.92).setStroke()
        line.stroke()
        drawTemperatureEndpoint(points.last ?? points[0], color: color)
    }

    private func drawTemperatureGraphGrid(rect: NSRect) {
        let baseline = NSBezierPath()
        baseline.move(to: NSPoint(x: rect.minX, y: rect.midY))
        baseline.line(to: NSPoint(x: rect.maxX, y: rect.midY))
        baseline.lineWidth = 0.8
        baseline.setLineDash([2, 3], count: 2, phase: 0)
        textMuted.withAlphaComponent(0.30).setStroke()
        baseline.stroke()
    }

    private func drawTemperatureEndpoint(_ point: NSPoint, color: NSColor) {
        let dot = NSBezierPath(ovalIn: NSRect(x: point.x - 2, y: point.y - 2, width: 4, height: 4))
        color.withAlphaComponent(0.95).setFill()
        dot.fill()
        NSColor.white.withAlphaComponent(0.60).setStroke()
        dot.lineWidth = 0.7
        dot.stroke()
    }

    private func drawTemperatureUnavailableCurve(rect: NSRect) {
        let baseline = NSBezierPath()
        baseline.move(to: NSPoint(x: rect.minX, y: rect.midY))
        baseline.curve(
            to: NSPoint(x: rect.maxX, y: rect.midY),
            controlPoint1: NSPoint(x: rect.minX + rect.width * 0.33, y: rect.midY - 2),
            controlPoint2: NSPoint(x: rect.minX + rect.width * 0.66, y: rect.midY + 2)
        )
        baseline.lineWidth = 1.2
        baseline.lineCapStyle = .round
        baseline.setLineDash([3, 4], count: 2, phase: 0)
        textMuted.withAlphaComponent(0.48).setStroke()
        baseline.stroke()
    }

    private func smoothedTemperaturePoints(samples: [TemperatureSample], rect: NSRect) -> [NSPoint] {
        let values = samples.compactMap { sample -> Int? in
            guard sample.ok, let temperature = sample.temperatureC else {
                return nil
            }
            return temperature
        }
        guard values.count >= 2 else {
            return []
        }
        let shown = values
        let minimum = CGFloat(shown.min() ?? 0)
        let maximum = CGFloat(shown.max() ?? 1)
        let range = max(4, maximum - minimum)
        return shown.enumerated().map { index, value in
            let previous = shown[max(0, index - 1)]
            let next = shown[min(shown.count - 1, index + 1)]
            let smoothed = CGFloat(previous + value + next) / 3
            let x = rect.minX + rect.width * CGFloat(index) / CGFloat(max(1, shown.count - 1))
            let normalized = (smoothed - minimum) / range
            let y = rect.maxY - 3 - (rect.height - 6) * max(0, min(1, normalized))
            return NSPoint(x: x, y: y)
        }
    }

    private func temperatureCurveColor(samples: [TemperatureSample]) -> NSColor {
        guard let latest = samples.reversed().first(where: { $0.ok && $0.temperatureC != nil }),
              let temperature = latest.temperatureC else {
            return textMuted
        }
        switch temperature {
        case 70...:
            return coralAccent
        case 55..<70:
            return amberAccent
        default:
            return mintAccent
        }
    }

    private func drawReportSection() {
        let layout = SignalConsoleLayout(bounds: bounds)
        let card = layout.reportCardRect
        let metricRects = layout.reportMetricRects
        let source = layout.reportTodayTextRect
        drawRoundedRect(card, radius: 15, fill: panelSoftBackground, stroke: panelBorder.withAlphaComponent(0.50))
        drawText("Usage Report", x: card.minX + 16, y: card.minY + 14, width: 108, height: 18, size: 12, weight: .bold, color: textPrimary)
        drawText("local only", x: card.maxX - 62, y: card.minY + 14, width: 46, height: 18, size: 10, weight: .regular, color: textMuted)
        drawText(model.reportTodaySummary, x: source.minX, y: source.minY, width: source.width, height: source.height, size: 8.8, weight: .regular, color: textMuted)
        drawReportMetric(label: "5h move", value: model.reportFiveHourMovement, rect: metricRects[0])
        drawReportMetric(label: "7d move", value: model.reportSevenDayMovement, rect: metricRects[1])
    }

    private func drawReportMetric(label: String, value: String, rect: NSRect) {
        drawRoundedRect(rect, radius: 10, fill: theme.commandButtonBackground, stroke: panelBorder.withAlphaComponent(0.22))
        drawText(label, x: rect.minX + 10, y: rect.minY + 6, width: rect.width - 20, height: 11, size: 8.5, weight: .medium, color: textMuted)
        drawText(value, x: rect.minX + 10, y: rect.minY + 18, width: rect.width - 20, height: 13, size: 10.5, weight: .bold, color: reportMetricColor(value), mono: true)
    }

    private func reportMetricColor(_ value: String) -> NSColor {
        if value.hasPrefix("-") {
            return coralAccent
        }
        if value.hasPrefix("+") {
            return mintAccent
        }
        return textSecondary
    }

    private func drawHealthRibbon() {
        let layout = SignalConsoleLayout(bounds: bounds)
        let rect = layout.healthRibbonRect
        drawRoundedRect(rect, radius: 15, fill: panelSoftBackground, stroke: panelBorder.withAlphaComponent(0.50))
        drawText("Health", x: rect.minX + 16, y: rect.minY + 17, width: 66, height: 18, size: 12, weight: .bold, color: textPrimary)
        drawText(model.healthSummaryText, x: rect.minX + 16, y: rect.minY + 36, width: 94, height: 16, size: 10, weight: .regular, color: textMuted)
        drawHealthStatusGrid(in: layout.healthStatusGridRect)
    }

    private func drawHealthStatusGrid(in rect: NSRect) {
        let checks = Array(model.doctorChecks.prefix(6))
        for (index, check) in checks.enumerated() {
            let itemRect = NSRect(x: rect.minX + CGFloat(index) * 50, y: rect.minY, width: 45, height: rect.height)
            drawRoundedRect(itemRect, radius: 9, fill: theme.commandButtonBackground, stroke: panelBorder.withAlphaComponent(0.20))
            drawCircle(center: NSPoint(x: itemRect.minX + 12, y: itemRect.midY), radius: 3.4, color: doctorColor(check.state), stroke: nil)
            drawText(healthShortLabel(check.title), x: itemRect.minX + 21, y: itemRect.minY + 8, width: 22, height: 14, size: 8.0, weight: .regular, color: textSecondary)
        }
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
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 28, y: y))
        path.line(to: NSPoint(x: bounds.width - 28, y: y))
        path.lineWidth = 1
        panelBorder.setStroke()
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
        value < 25
            ? NSGradient(colors: [coralAccent, theme.quotaLowEnd])
            : NSGradient(colors: [mintAccent, theme.quotaHighEnd])
    }

    private var resetLaneGradient: NSGradient? {
        NSGradient(colors: [coralAccent, theme.resetMidAccent, amberAccent])
    }

    private func drawResetCountdownLane(value: Int?, rect: NSRect) {
        drawRoundedGradient(
            rect,
            radius: rect.height / 2,
            gradient: resetLaneGradient,
            stroke: nil
        )
        guard let value else {
            drawResetMoodFace(value: 0, center: NSPoint(x: rect.minX + 10, y: rect.midY), radius: 11, fill: textMuted)
            return
        }
        let x = rect.minX + (rect.width - 18) * clamped(value) + 9
        drawResetMoodFace(value: value, center: NSPoint(x: x, y: rect.midY), radius: 11, fill: resetColor(value))
    }

    private func drawResetMoodFace(value: Int, center: NSPoint, radius: CGFloat, fill: NSColor) {
        drawCircle(center: center, radius: radius, color: fill, stroke: NSColor.black.withAlphaComponent(0.18))
        let eyeY = center.y - 3
        drawCircle(center: NSPoint(x: center.x - 4, y: eyeY), radius: 1.4, color: NSColor.black.withAlphaComponent(0.58), stroke: nil)
        drawCircle(center: NSPoint(x: center.x + 4, y: eyeY), radius: 1.4, color: NSColor.black.withAlphaComponent(0.58), stroke: nil)
        let mouth = NSBezierPath()
        if value < 35 {
            mouth.move(to: NSPoint(x: center.x - 4, y: center.y + 5))
            mouth.curve(
                to: NSPoint(x: center.x + 4, y: center.y + 5),
                controlPoint1: NSPoint(x: center.x - 2, y: center.y + 2),
                controlPoint2: NSPoint(x: center.x + 2, y: center.y + 2)
            )
        } else {
            mouth.move(to: NSPoint(x: center.x - 4, y: center.y + 4))
            mouth.curve(
                to: NSPoint(x: center.x + 4, y: center.y + 4),
                controlPoint1: NSPoint(x: center.x - 2, y: center.y + 7),
                controlPoint2: NSPoint(x: center.x + 2, y: center.y + 7)
            )
        }
        mouth.lineWidth = 1.4
        NSColor.black.withAlphaComponent(0.58).setStroke()
        mouth.stroke()
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
        if model.isUnavailable {
            return "Closed"
        }
        switch model.source {
        case "last_live":
            return "Cache"
        case "local_snapshot":
            return "Snapshot"
        default:
            return "Live"
        }
    }

    private func headerSignalColor() -> NSColor {
        sourceColor(source: model.source, unavailable: model.isUnavailable)
    }

    private func statusStripDetail() -> String {
        if model.isUnavailable {
            return "Open Codex for live quota"
        }
        if model.isRefreshing {
            return "Refreshing quota now."
        }
        switch model.source {
        case "last_live":
            return "Last live \(model.liveAgeText) · retrying"
        case "local_snapshot":
            return "Snapshot \(model.liveAgeText) · open Codex"
        default:
            return "Live \(model.liveAgeText) · refreshes every 5 min"
        }
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

    private func drawMoodLane(value: Int?, rect: NSRect) {
        drawRoundedRect(rect, radius: rect.height / 2, fill: theme.trackFill, stroke: nil)
        guard let value else {
            drawCircle(center: NSPoint(x: rect.minX + 10, y: rect.midY), radius: 6, color: textMuted, stroke: nil)
            return
        }
        let fraction = clamped(value)
        let color = resetColor(value)
        let markerX = rect.minX + (rect.width - 12) * fraction + 6
        drawRoundedRect(NSRect(x: rect.minX, y: rect.minY, width: max(6, markerX - rect.minX), height: rect.height), radius: rect.height / 2, fill: color.withAlphaComponent(0.46), stroke: nil)
        drawCircle(center: NSPoint(x: markerX, y: rect.midY), radius: 6, color: color, stroke: nil)
        drawText(value < 35 ? "·" : "⌣", x: markerX - 4, y: rect.midY - 9, width: 8, height: 12, size: 10, weight: .bold, color: NSColor.black.withAlphaComponent(0.62))
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
        mono: Bool = false
    ) {
        (text as NSString).draw(
            in: NSRect(x: x, y: y, width: width, height: height),
            withAttributes: textAttributes(size: size, weight: weight, color: color, mono: mono)
        )
    }

    private func textAttributes(size: CGFloat, weight: NSFont.Weight, color: NSColor, mono: Bool = false) -> [NSAttributedString.Key: Any] {
        [
            .font: mono ? NSFont.monospacedDigitSystemFont(ofSize: size, weight: weight) : NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: color,
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
        case 0..<20:
            return coralAccent
        case 20..<45:
            return NSColor(calibratedRed: 1.00, green: 0.58, blue: 0.38, alpha: 0.96)
        case 45..<75:
            return amberAccent
        default:
            return mintAccent
        }
    }

    private func resetColor(_ value: Int) -> NSColor {
        switch max(0, min(100, value)) {
        case 0..<25:
            return coralAccent
        case 25..<55:
            return NSColor(calibratedRed: 1.00, green: 0.58, blue: 0.38, alpha: 0.96)
        case 55..<80:
            return NSColor(calibratedRed: 1.00, green: 0.68, blue: 0.35, alpha: 0.96)
        default:
            return amberAccent
        }
    }

    private func sourceColor(source: String?, unavailable: Bool) -> NSColor {
        if unavailable {
            return amberAccent
        }
        switch source {
        case "last_live":
            return amberAccent
        case "local_snapshot":
            return blueAccent
        default:
            return mintAccent
        }
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
        case "Codex app found":
            return "Codex"
        case "Helper works":
            return "Helper"
        case "Live data available":
            return "Live"
        case "Session storage":
            return "Store"
        case "Notifications permission":
            return "Alerts"
        case "SSD temp":
            return "SSD"
        case "Battery":
            return "Batt"
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
        frame: NSRect(origin: .zero, size: NSSize(width: 560, height: 560)),
        model: model,
        theme: theme,
        target: target,
        runCheckAction: #selector(SignalConsolePreviewTarget.noop(_:)),
        generateReportAction: #selector(SignalConsolePreviewTarget.noop(_:)),
        copyDiagnosticsAction: #selector(SignalConsolePreviewTarget.noop(_:)),
        clearDataAction: #selector(SignalConsolePreviewTarget.noop(_:)),
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
        ("porcelain-lab", porcelainLabTheme()),
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
            fiveHourResetText: "4h",
            sevenDayResetText: "5d22h",
            fiveHourResetProgress: 18,
            sevenDayResetProgress: 52,
            source: "live",
            unavailable: false,
            reportFive: "-8%",
            reportSeven: "-3%",
            todaySummary: "Today 12 · 5h -8% · 7d -3%"
        )),
        ("codex-closed", signalConsolePreviewModel(
            title: "Codex closed",
            detail: "Open Codex",
            statusTitle: "Open Codex desktop once to enable live usage",
            statusDetail: "After Codex is open, Codex Gauge refreshes hands-free from the menu bar.",
            fiveHourLeft: nil,
            sevenDayLeft: nil,
            fiveHourResetText: "--",
            sevenDayResetText: "--",
            fiveHourResetProgress: nil,
            sevenDayResetProgress: nil,
            source: nil,
            unavailable: true,
            reportFive: "collecting",
            reportSeven: "collecting",
            todaySummary: "Today collecting · need 2 samples"
        )),
        ("last-live", signalConsolePreviewModel(
            title: "Last live",
            detail: "Cached",
            statusTitle: "Non-live fallback disabled in app",
            statusDetail: "Zero persistence keeps no cached fallback",
            fiveHourLeft: 58,
            sevenDayLeft: 63,
            fiveHourResetText: "2h",
            sevenDayResetText: "4d8h",
            fiveHourResetProgress: 62,
            sevenDayResetProgress: 39,
            source: "last_live",
            unavailable: false,
            reportFive: "-21%",
            reportSeven: "-6%",
            todaySummary: "Today 10 · 5h -21% · 7d -6%"
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
            fiveHourResetProgress: 86,
            sevenDayResetProgress: 70,
            source: "live",
            unavailable: false,
            reportFive: "-81%",
            reportSeven: "-18%",
            todaySummary: "Today 18 · 5h -81% · 7d -18%"
        )),
        ("plugged-in-full", signalConsolePreviewModel(
            title: "Live",
            detail: "Charging",
            statusTitle: "Live data is current",
            statusDetail: "Read from local Codex app-server",
            fiveHourLeft: 82,
            sevenDayLeft: 76,
            fiveHourResetText: "4h",
            sevenDayResetText: "5d22h",
            fiveHourResetProgress: 18,
            sevenDayResetProgress: 52,
            source: "live",
            unavailable: false,
            reportFive: "-8%",
            reportSeven: "-3%",
            todaySummary: "Today 12 · 5h -8% · 7d -3%",
            batteryPercent: 92,
            batteryStatusText: "Battery 92%",
            powerSaverText: "Power Saver off",
            refreshCadenceText: "Refresh 5m",
            hardwareSignalsVisible: true
        )),
        ("battery-mode", signalConsolePreviewModel(
            title: "Live",
            detail: "Battery",
            statusTitle: "Live data is current",
            statusDetail: "Battery mode keeps only usage and battery signals visible.",
            fiveHourLeft: 80,
            sevenDayLeft: 79,
            fiveHourResetText: "4h",
            sevenDayResetText: "5d21h",
            fiveHourResetProgress: 22,
            sevenDayResetProgress: 54,
            source: "live",
            unavailable: false,
            reportFive: "-10%",
            reportSeven: "-4%",
            todaySummary: "Today 12 · 5h -10% · 7d -4%",
            batteryPercent: 11,
            batteryStatusText: "Battery 11%",
            powerSaverText: "Power Saver active",
            refreshCadenceText: "Refresh 60m",
            hardwareSignalsVisible: false
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
    fiveHourResetProgress: Int?,
    sevenDayResetProgress: Int?,
    source: String?,
    unavailable: Bool,
    reportFive: String,
    reportSeven: String,
    todaySummary: String,
    batteryPercent: Int? = nil,
    batteryStatusText: String? = nil,
    powerSaverText: String? = nil,
    refreshCadenceText: String? = nil,
    hardwareSignalsVisible: Bool? = nil
) -> SignalConsoleModel {
    let temperatureHistory = previewTemperatureSamples(unavailable: unavailable)
    let systemMetricHistory = previewSystemMetricSamples(unavailable: unavailable)
    let doctorChecks = [
        DoctorCheck(title: "Codex process", state: unavailable ? "yellow" : "green", detail: unavailable ? "Closed" : "Open"),
        DoctorCheck(title: "Menu bar source", state: "green", detail: "OK"),
        DoctorCheck(title: "Session storage", state: "green", detail: "Zero persistence"),
        DoctorCheck(title: "Last fetch", state: unavailable ? "grey" : "green", detail: unavailable ? "--" : "OK"),
        DoctorCheck(title: "SSD temp", state: unavailable ? "grey" : "green", detail: unavailable ? "Unavailable" : "42°C · Normal"),
    ]
    return SignalConsoleModel(
        planName: unavailable ? "Codex Gauge" : "Codex Pro",
        sourcePill: "Source: Menu Bar",
        stateTitle: title,
        stateDetail: detail,
        statusTitle: statusTitle,
        statusDetail: statusDetail,
        fiveHourLeft: fiveHourLeft,
        sevenDayLeft: sevenDayLeft,
        fiveHourResetText: fiveHourResetText,
        sevenDayResetText: sevenDayResetText,
        fiveHourResetProgress: fiveHourResetProgress,
        sevenDayResetProgress: sevenDayResetProgress,
        fiveHourHistory: unavailable ? [] : [96, 88, 77, 69, fiveHourLeft ?? 0],
        sevenDayHistory: unavailable ? [] : [91, 84, 78, 72, sevenDayLeft ?? 0],
        fiveHourTrendText: unavailable ? "collecting" : reportFive,
        sevenDayTrendText: unavailable ? "collecting" : reportSeven,
        trendContextText: unavailable ? "Open Codex to start collecting live samples" : "Based on 12 live samples from 09:12 to 21:12",
        temperatureHistory: temperatureHistory,
        currentTemperatureText: unavailable ? "--" : "42°C",
        temperatureHistoryText: temperatureHistorySummaryText(temperatureHistory),
        systemMetricHistory: systemMetricHistory,
        cpuUsageText: systemMetricPercentText(systemMetricHistory.last?.cpuPercent),
        ramUsageText: systemMetricPercentText(systemMetricHistory.last?.ramPercent),
        batteryStatusText: batteryStatusText ?? (unavailable ? "Battery --" : "Battery 74%"),
        batteryPercent: batteryPercent ?? (unavailable ? nil : 74),
        powerSaverText: powerSaverText ?? (unavailable ? "Power Saver unknown" : "Power Saver off"),
        refreshCadenceText: refreshCadenceText ?? (unavailable ? "Refresh --" : "Refresh 5m"),
        hardwareSignalsVisible: hardwareSignalsVisible ?? !unavailable,
        reportFiveHourMovement: reportFive,
        reportSevenDayMovement: reportSeven,
        reportTodaySummary: todaySummary,
        healthSummaryText: healthSummaryText(doctorChecks),
        doctorChecks: doctorChecks,
        lastRefreshText: unavailable ? "none" : "21:12",
        liveAgeText: unavailable ? "unknown" : "2m ago",
        nextRefreshText: unavailable ? "1:00" : "4:58",
        source: source,
        isUnavailable: unavailable,
        isRefreshing: false
    )
}

private func previewSystemMetricSamples(unavailable: Bool = false) -> [SystemMetricSample] {
    if unavailable {
        return [
            SystemMetricSample(time: "2026-06-16T21:12:00Z", cpuPercent: nil, ramPercent: nil, ok: false),
        ]
    }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    let end = Date(timeIntervalSince1970: 1_781_600_000)
    let cpuValues = [18, 22, 20, 28, 31, 26, 24, 33, 29, 25, 21, 19]
    let ramValues = [58, 59, 61, 60, 62, 64, 63, 65, 64, 62, 61, 60]
    return cpuValues.enumerated().map { index, cpu in
        let offset = Double(index - cpuValues.count + 1) * 50
        return SystemMetricSample(
            time: formatter.string(from: end.addingTimeInterval(offset)),
            cpuPercent: cpu,
            ramPercent: ramValues[index],
            ok: true
        )
    }
}

private func previewTemperatureSamples(unavailable: Bool = false) -> [TemperatureSample] {
    if unavailable {
        return [
            TemperatureSample(time: "2026-06-16T21:12:00Z", temperatureC: nil, ok: false),
        ]
    }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    let end = Date(timeIntervalSince1970: 1_781_600_000)
    let values = [41, 42, 42, 43, 42, 44, 43, 45, 44, 44, 43, 42]
    return values.enumerated().map { index, value in
        let offset = Double(index - values.count + 1) * 50
        return TemperatureSample(time: formatter.string(from: end.addingTimeInterval(offset)), temperatureC: value, ok: true)
    }
}

private final class CodexGaugeApp: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let temperatureQueue = DispatchQueue(label: "app.codexgauge.temperature", qos: .utility)
    private let systemMetricsQueue = DispatchQueue(label: "app.codexgauge.system-metrics", qos: .utility)
    private let runtimeLogQueue = DispatchQueue(label: "app.codexgauge.runtime-log", qos: .utility)
    private let menu = NSMenu()
    private var signalPopover: NSPopover?
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
    private var showSSDTemperatureCheckbox: NSButton?
    private var snapshot: UsageSnapshot?
    private var ssdTemperature: SSDTemperatureStatus?
    private var lastValidSSDTemperature: SSDTemperatureStatus?
    private var lastValidSSDTemperatureAt: Date?
    private var temperatureFailureBackoffUntil: Date?
    private var temperatureTimer: Timer?
    private var systemMetricsTimer: Timer?
    private var batteryStatus: BatteryStatus?
    private var batteryTimer: Timer?
    private var batteryRunLoopSource: CFRunLoopSource?
    private var temperatureReadInFlight = false
    private var temperatureSamples: [TemperatureSample] = []
    private var systemMetricSamples: [SystemMetricSample] = []
    private var lastCPUTicks: [UInt64]?
    private var lastError: String?
    private var isRefreshing = false
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
    private var automaticUpdateCheckPendingForPower = false
    private var automaticUpdateDismissedTagName: String?
    private var runtimeLogMessages: [String] = []
    private var sessionSignalConsoleThemeKey = porcelainLabThemeKey
    private var sessionRefreshMode = "adaptive"
    private var sessionNotificationsEnabled = false
    private var sessionShowSSDTemperatureInMenuBar = true
    private let powerPolicy = CodexGaugePowerPolicy()
    private let persistentStorageEnabled = false
    private let moodAnimationFrameLimit = 8
    private let maxHistorySamples = 720
    private let historyRetentionWindow: TimeInterval = 48 * 60 * 60
    private let temperatureSampleInterval: TimeInterval = 1
    private let temperatureFailureBackoffInterval: TimeInterval = 5 * 60
    private let temperatureGraphWindow: TimeInterval = 10 * 60
    private let temperatureHistoryRetentionWindow: TimeInterval = 24 * 60 * 60
    private let maxTemperatureSamples = 24 * 60 * 60
    private let systemMetricSampleInterval: TimeInterval = 5
    private let batteryVisibleSampleInterval: TimeInterval = 60
    private let batteryIdleSampleInterval: TimeInterval = 5 * 60
    private let systemMetricGraphWindow: TimeInterval = 10 * 60
    private let systemMetricRetentionWindow: TimeInterval = 24 * 60 * 60
    private let maxSystemMetricSamples = 24 * 60 * 60 / 5
    private let ssdTemperatureReadTimeout: TimeInterval = 0.8
    private let ssdTemperatureDisplayGraceInterval: TimeInterval = 10 * 60
    private let statusItemWidth: CGFloat = 236
    private let statusImageSize = NSSize(width: 230, height: 22)
    private let menuBarTemperatureChipRect = NSRect(x: 82, y: 4.9, width: 27, height: 12.2)
    private let menuBarSystemMetricStripRect = NSRect(x: 168, y: 1.8, width: 34, height: 18.4)
    private let menuBarBatteryModeInfoRect = NSRect(x: 168, y: 4.9, width: 34, height: 12.2)
    private let menuBarBatteryRect = NSRect(x: 204, y: 4.2, width: 24, height: 13.8)
    private let signalPopoverSize = NSSize(width: 560, height: 560)
    private let quotaRailWidth: CGFloat = 28
    private let resetRailWidth: CGFloat = 18
    private let signalRailSegments = 10
    private let codexCliBundlePath = "/Applications/Codex.app/Contents/Resources/codex"
    private let normalQuotaColor = NSColor(calibratedRed: 0.58, green: 1.00, blue: 0.89, alpha: 0.95)
    private let warningQuotaColor = NSColor(calibratedRed: 1.00, green: 0.74, blue: 0.34, alpha: 0.96)
    private let criticalQuotaColor = NSColor(calibratedRed: 1.00, green: 0.34, blue: 0.40, alpha: 0.96)
    private let fiveHourMenuLabel = "5-hour left"
    private let sevenDayMenuLabel = "7-day left"
    private let liveRefreshMenuLabel = "Live · refreshed"
    private let snapshotRefreshMenuLabel = "Snapshot · refreshed"
    private let lastLiveRefreshMenuLabel = "Last live ·"
    private let fiveHourResetMenuLabel = "5h resets"
    private let sevenDayResetMenuLabel = "7d resets"
    private let runtimeLogFileName = "CodexGauge-runtime.log"
    private let historyFileName = "CodexGauge-history.json"
    private let temperatureHistoryFileName = "CodexGauge-temperature-history.json"
    private let systemMetricsHistoryFileName = "CodexGauge-system-metrics-history.json"
    private let lastLiveCacheFileName = "last-live-status.json"
    private let legacyUsageReportFileName = "CodexGauge-usage-report.md"
    private let launchAgentLabel = "app.codexgauge.menubar"
    private let launchAgentPlistName = "app.codexgauge.menubar.plist"
    private let latestReleaseAPIURL = "https://api.github.com/repos/qingzhangeddie-byte/codex-gauge/releases/latest"
    private let refreshModeKey = "refreshMode"
    private let notificationsEnabledKey = "notificationsEnabled"
    private let launchAtLoginKey = "launchAtLogin"
    private let showSSDTemperatureInMenuBarKey = "showSSDTemperatureInMenuBar"
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
    private lazy var supportDir = applicationSupportDirectory()
    private lazy var pythonPath = infoString("CodexGaugePythonPath", fallback: "/usr/bin/python3")
    private lazy var appVersion = infoString("CFBundleShortVersionString", fallback: "0.9.1")
    private lazy var releaseURL = infoString("CodexGaugeReleaseURL", fallback: "https://github.com/qingzhangeddie-byte/codex-gauge/releases")
    private lazy var expectedUpdateSigningTeamID = infoString("CodexGaugeUpdateTeamID", fallback: "").trimmingCharacters(in: .whitespacesAndNewlines)
    private lazy var usagePath = resolveUsagePath()
    private lazy var ssdTemperaturePath = URL(fileURLWithPath: resourcesDir, isDirectory: true)
        .appendingPathComponent("ssd_temperature")
        .path
    private lazy var logPath = "\(supportDir)/\(runtimeLogFileName)"
    private lazy var historyPath = "\(supportDir)/\(historyFileName)"
    private lazy var temperatureHistoryPath = "\(supportDir)/\(temperatureHistoryFileName)"
    private lazy var systemMetricsHistoryPath = "\(supportDir)/\(systemMetricsHistoryFileName)"
    private lazy var launchAgentPlistPath = NSHomeDirectory() + "/Library/LaunchAgents/" + launchAgentPlistName

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        registerDefaultPreferences()
        _ = sampleBattery()
        startBatterySampler()
        removePersistentAppStorage()
        ProcessInfo.processInfo.disableAutomaticTermination("Codex Gauge menu bar status item")
        ProcessInfo.processInfo.disableSuddenTermination()
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.automaticTerminationDisabled, .suddenTerminationDisabled],
            reason: "Codex Gauge menu bar status item"
        )
        if let button = statusItem.button {
            button.title = ""
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleNone
            button.toolTip = "Codex quota"
            button.setAccessibilityLabel("Codex Gauge")
            button.target = self
            button.action = #selector(toggleSignalConsole(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        setStatusImage(title: "Codex quota")
        rebuildMenu()
        configureHardwareSamplersForPowerState()
        refresh()
        scheduleAutomaticUpdateCheck()
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        temperatureTimer?.invalidate()
        systemMetricsTimer?.invalidate()
        batteryTimer?.invalidate()
        automaticUpdateTimer?.invalidate()
        if let batteryRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), batteryRunLoopSource, .commonModes)
        }
        animationTimer?.invalidate()
        popoverCountdownTimer?.invalidate()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        allowTermination ? .terminateNow : .terminateCancel
    }

    @objc private func toggleSignalConsole(_ sender: Any?) {
        if let signalPopover, signalPopover.isShown {
            signalPopover.performClose(sender)
            stopPopoverCountdownTimer()
            stopVisibleTemperatureSampler()
            startBatterySampler()
            return
        }
        showSignalConsolePopover()
    }

    private func showSignalConsolePopover() {
        guard let button = statusItem.button else {
            return
        }
        let popover = signalPopover ?? NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.appearance = NSAppearance(named: currentSignalConsoleTheme().appearance)
        popover.contentSize = signalPopoverSize
        popover.contentViewController = makeSignalConsoleViewController()
        signalPopover = popover
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        startPopoverCountdownTimer()
        startVisibleTemperatureSamplerIfNeeded()
        startBatterySampler()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func refreshSignalPopoverIfNeeded() {
        guard let signalPopover, signalPopover.isShown else {
            return
        }
        signalPopover.contentViewController = makeSignalConsoleViewController()
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
                self.stopVisibleTemperatureSampler()
                self.startBatterySampler()
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
            runCheckAction: #selector(openSetupDoctor),
            generateReportAction: #selector(generateUsageReport),
            copyDiagnosticsAction: #selector(copyDiagnostics),
            clearDataAction: #selector(clearLocalData),
            openCodexAction: #selector(openCodexApp),
            refreshAction: #selector(refreshNow),
            preferencesAction: #selector(openPreferences),
            quitAction: #selector(quit)
        )
        panel.autoresizingMask = [.width, .height]
        visual.addSubview(panel)
        controller.view = visual
        controller.preferredContentSize = signalPopoverSize
        return controller
    }

    private func signalConsoleModel() -> SignalConsoleModel {
        let samples = readHistorySamples()
        let doctorChecks = runSetupDoctorChecks()
        let now = Date()
        let lastDaySamples = historySamples(since: now.addingTimeInterval(-24 * 60 * 60), from: samples)

        if let snapshot {
            let status = snapshot.codex
            let unavailable = isUnavailableStatus(status)
            let title = signalStateTitle(status)
            let statusAgeText = relativeAgeText(status.dataTime ?? snapshot.updatedAt, now: now)
            let fiveHourSamples = currentFiveHourWindowSamples(from: samples, resetEpoch: status.fiveHourReset, now: now)
            let sevenDaySamples = lastDaySamples
            let fiveHourHistory = quotaHistoryValues(fiveHourSamples, \.fiveHourLeft)
            let sevenDayHistory = quotaHistoryValues(sevenDaySamples, \.sevenDayLeft)
            let inlineReport = inlineUsageReportSummary(samples: lastDaySamples, status: status)
            let retainedTemperatureHistory = temperatureGraphSamples(temperatureSamples)
            let retainedSystemMetricHistory = systemMetricGraphSamples(systemMetricSamples)
            return SignalConsoleModel(
                planName: status.ok ? planTitle(status) : "Codex Gauge",
                sourcePill: "Source: Menu Bar",
                stateTitle: title.title,
                stateDetail: title.detail,
                statusTitle: sourceStatusTitle(status),
                statusDetail: sourceStatusDetail(status),
                fiveHourLeft: unavailable ? nil : status.fiveHourLeft,
                sevenDayLeft: unavailable ? nil : status.sevenDayLeft,
                fiveHourResetText: unavailable ? "--" : fiveHourResetCountdown(status.fiveHourReset),
                sevenDayResetText: unavailable ? "--" : sevenDayResetCountdown(status.sevenDayReset),
                fiveHourResetProgress: unavailable ? nil : resetProgressPercent(epoch: status.fiveHourReset, windowHours: 5),
                sevenDayResetProgress: unavailable ? nil : resetProgressPercent(epoch: status.sevenDayReset, windowHours: 24 * 7),
                fiveHourHistory: fiveHourHistory,
                sevenDayHistory: sevenDayHistory,
                fiveHourTrendText: trendText(values: fiveHourHistory, suffix: "this window"),
                sevenDayTrendText: trendText(values: sevenDayHistory, suffix: "in 24h"),
                trendContextText: trendContextText(samples: lastDaySamples, latestSource: status.source),
                temperatureHistory: retainedTemperatureHistory,
                currentTemperatureText: currentTemperatureText(status: ssdTemperatureForDisplay(), samples: retainedTemperatureHistory),
                temperatureHistoryText: temperatureHistorySummaryText(retainedTemperatureHistory),
                systemMetricHistory: retainedSystemMetricHistory,
                cpuUsageText: systemMetricPercentText(retainedSystemMetricHistory.last?.cpuPercent),
                ramUsageText: systemMetricPercentText(retainedSystemMetricHistory.last?.ramPercent),
                batteryStatusText: batteryStatusText(status: batteryStatus),
                batteryPercent: batteryStatus?.percent,
                powerSaverText: powerSaverStatusText(),
                refreshCadenceText: refreshCadenceStatusText(),
                hardwareSignalsVisible: hardwareSignalsVisible(),
                reportFiveHourMovement: inlineReport.fiveHourMovement,
                reportSevenDayMovement: inlineReport.sevenDayMovement,
                reportTodaySummary: inlineReport.todaySummary,
                healthSummaryText: healthSummaryText(doctorChecks),
                doctorChecks: doctorChecks,
                lastRefreshText: shortTime(status.dataTime ?? snapshot.updatedAt),
                liveAgeText: statusAgeText,
                nextRefreshText: nextRefreshCountdownText(now: now),
                source: status.source,
                isUnavailable: unavailable,
                isRefreshing: isRefreshing
            )
        }

        let detail = lastError == nil
            ? "After Codex is open, Codex Gauge refreshes hands-free from the menu bar."
            : clipped(lastError ?? "", limit: 96)
        let fiveHourSamples = currentFiveHourWindowSamples(from: samples, resetEpoch: nil, now: now)
        let sevenDaySamples = lastDaySamples
        let fiveHourHistory = quotaHistoryValues(fiveHourSamples, \.fiveHourLeft)
        let sevenDayHistory = quotaHistoryValues(sevenDaySamples, \.sevenDayLeft)
        let inlineReport = inlineUsageReportSummary(samples: lastDaySamples, status: nil)
        let retainedTemperatureHistory = temperatureGraphSamples(temperatureSamples)
        let retainedSystemMetricHistory = systemMetricGraphSamples(systemMetricSamples)
        return SignalConsoleModel(
            planName: "Codex Gauge",
            sourcePill: "Source: Menu Bar",
            stateTitle: "Codex closed",
            stateDetail: "Open Codex",
            statusTitle: "Open Codex desktop once to enable live usage",
            statusDetail: detail,
            fiveHourLeft: nil,
            sevenDayLeft: nil,
            fiveHourResetText: "--",
            sevenDayResetText: "--",
            fiveHourResetProgress: nil,
            sevenDayResetProgress: nil,
            fiveHourHistory: fiveHourHistory,
            sevenDayHistory: sevenDayHistory,
            fiveHourTrendText: trendText(values: fiveHourHistory, suffix: "this window"),
            sevenDayTrendText: trendText(values: sevenDayHistory, suffix: "in 24h"),
            trendContextText: trendContextText(samples: lastDaySamples, latestSource: nil),
            temperatureHistory: retainedTemperatureHistory,
            currentTemperatureText: currentTemperatureText(status: ssdTemperatureForDisplay(), samples: retainedTemperatureHistory),
            temperatureHistoryText: temperatureHistorySummaryText(retainedTemperatureHistory),
            systemMetricHistory: retainedSystemMetricHistory,
            cpuUsageText: systemMetricPercentText(retainedSystemMetricHistory.last?.cpuPercent),
            ramUsageText: systemMetricPercentText(retainedSystemMetricHistory.last?.ramPercent),
            batteryStatusText: batteryStatusText(status: batteryStatus),
            batteryPercent: batteryStatus?.percent,
            powerSaverText: powerSaverStatusText(),
            refreshCadenceText: refreshCadenceStatusText(),
            hardwareSignalsVisible: hardwareSignalsVisible(),
            reportFiveHourMovement: inlineReport.fiveHourMovement,
            reportSevenDayMovement: inlineReport.sevenDayMovement,
            reportTodaySummary: inlineReport.todaySummary,
            healthSummaryText: healthSummaryText(doctorChecks),
            doctorChecks: doctorChecks,
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
            return ("Codex closed", "Open Codex")
        }
        switch status.source {
        case "last_live":
            return ("Last live", "Cached")
        case "local_snapshot":
            return ("Snapshot", "Recent local")
        case "live", nil:
            return ("Live", "Current")
        default:
            return ("Snapshot", "Recent local")
        }
    }

    private func trendText(values: [Int], suffix: String) -> String {
        guard values.count >= 2, let first = values.first, let last = values.last else {
            return "No data"
        }
        let delta = last - first
        if abs(delta) < 2 {
            return "Stable \(suffix)"
        }
        let sign = delta > 0 ? "+" : ""
        return "\(sign)\(delta)% \(suffix)"
    }

    private func trendContextText(samples: [HistorySample], latestSource: String?) -> String {
        let usable = samples.filter { sample in
            historyDate(sample) != nil && (sample.fiveHourLeft != nil || sample.sevenDayLeft != nil)
        }
        guard usable.count >= 2, let first = usable.first, let latest = usable.last else {
            return "Collecting enough samples for a useful trend"
        }
        if let latestSource, latestSource != "live" {
            return "Trend uses local history; latest source is \(sourceDisplayName(latestSource))"
        }
        let prefix = "Based on"
        let liveCount = usable.filter { $0.source == "live" }.count
        let sampleKind = liveCount == usable.count ? "live samples" : "samples"
        return "\(prefix) \(usable.count) \(sampleKind) from \(shortTime(first.time)) to \(shortTime(latest.time))"
    }

    private func currentTemperatureText(status: SSDTemperatureStatus?, samples: [TemperatureSample], now: Date = Date()) -> String {
        if let status, status.ok, let temperature = status.temperatureC {
            return "\(temperature)°C"
        }
        if let latest = samples.reversed().first(where: { $0.ok && $0.temperatureC != nil }),
           let latestTimestamp = temperatureSampleTimestamp(latest),
           now.timeIntervalSince1970 - latestTimestamp <= ssdTemperatureDisplayGraceInterval,
           let temperature = latest.temperatureC {
            return "\(temperature)°C"
        }
        return "--"
    }

    private func updateLastValidSSDTemperature(_ status: SSDTemperatureStatus?, at date: Date = Date()) {
        guard let status, status.ok, status.temperatureC != nil else {
            return
        }
        lastValidSSDTemperature = status
        lastValidSSDTemperatureAt = date
    }

    private func ssdTemperatureForDisplay(now: Date = Date()) -> SSDTemperatureStatus? {
        guard let lastValidSSDTemperature, let lastValidSSDTemperatureAt else {
            return nil
        }
        guard now.timeIntervalSince(lastValidSSDTemperatureAt) <= ssdTemperatureDisplayGraceInterval else {
            return nil
        }
        return lastValidSSDTemperature
    }

    @objc private func refreshNow() {
        timer?.invalidate()
        nextRefreshAt = nil
        refresh()
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
        guard !powerSaverActive() else {
            automaticUpdateCheckPendingForPower = true
            return
        }
        guard !isCheckingForUpdates, !isInstallingUpdate else {
            automaticUpdateCheckDidRun = true
            automaticUpdateCheckPendingForPower = false
            return
        }
        automaticUpdateCheckDidRun = true
        automaticUpdateCheckPendingForPower = false
        performUpdateCheck(mode: .automatic)
    }

    private func resumeAutomaticUpdateCheckAfterPowerReturns() {
        guard automaticUpdateCheckPendingForPower else {
            return
        }
        guard !powerSaverActive() else {
            return
        }
        performAutomaticUpdateCheckIfAllowed()
    }

    @objc private func checkForUpdates() {
        automaticUpdateTimer?.invalidate()
        automaticUpdateTimer = nil
        automaticUpdateCheckDidRun = true
        automaticUpdateCheckPendingForPower = false
        performUpdateCheck(mode: .manual)
    }

    private func performUpdateCheck(mode: UpdateCheckMode) {
        guard !isCheckingForUpdates, !isInstallingUpdate else {
            if mode == .manual {
                showReportAlert(title: "Update already in progress", detail: lastUpdateSummary ?? "Codex Gauge is already checking or installing an update.")
            }
            return
        }
        if mode == .automatic {
            guard !powerSaverActive() else {
                automaticUpdateCheckPendingForPower = true
                return
            }
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
        if mode == .automatic, automaticUpdateDismissedTagName == release.tagName {
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
        alert.messageText = "Codex Gauge \(release.tagName) is available"
        alert.informativeText = releaseInfoText(release: release, asset: asset, latestVersion: latestVersion)
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Download & Install")
        alert.addButton(withTitle: "Release Page")
        alert.addButton(withTitle: "Not Now")
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            downloadAndInstallUpdate(release: release, asset: asset, latestVersion: latestVersion)
        case .alertSecondButtonReturn:
            if mode == .automatic {
                automaticUpdateDismissedTagName = release.tagName
            }
            openURL(release.htmlURL)
        default:
            if mode == .automatic {
                automaticUpdateDismissedTagName = release.tagName
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
        let binary = appURL.appendingPathComponent("Contents/MacOS/CodexGauge-bin")
        let helper = appURL.appendingPathComponent("Contents/Resources/codex_status.py")
        let temperatureHelper = appURL.appendingPathComponent("Contents/Resources/ssd_temperature")
        guard FileManager.default.isExecutableFile(atPath: binary.path),
              FileManager.default.isReadableFile(atPath: helper.path),
              FileManager.default.isExecutableFile(atPath: temperatureHelper.path) else {
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
        AGENT_PLIST="$HOME/Library/LaunchAgents/app.codexgauge.menubar.plist"
        UPDATE_TARGET="$TARGET_APP.update"
        while /bin/kill -0 "$CURRENT_PID" >/dev/null 2>&1; do
          /bin/sleep 0.2
        done
        /bin/rm -f "$AGENT_PLIST" >/dev/null 2>&1 || true
        /bin/rm -rf "$UPDATE_TARGET"
        /usr/bin/ditto --norsrc --noextattr "$SOURCE_APP" "$UPDATE_TARGET"
        /usr/bin/codesign --verify --deep --strict "$UPDATE_TARGET"
        /bin/rm -rf "$TARGET_APP"
        /bin/mv "$UPDATE_TARGET" "$TARGET_APP"
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

    @objc private func generateUsageReport() {
        if !persistentStorageEnabled {
            guard let status = snapshot?.codex, status.ok else {
                showReportAlert(title: "Live summary unavailable", detail: "Zero persistence mode keeps no stored quota history. Open Codex and refresh for a current live summary.")
                return
            }
            let report = liveUsageSummaryText(status)
            NSPasteboard.general.clearContents()
            guard NSPasteboard.general.setString(report, forType: .string) else {
                showReportAlert(title: "Live summary not copied", detail: "The pasteboard did not accept the current summary.")
                return
            }
            showReportAlert(title: "Live summary copied", detail: "Copied the current live-only summary. No history or report file was saved.")
            appendLog("live summary copied to clipboard")
            return
        }
        let samples = historySamples(since: Date().addingTimeInterval(-24 * 60 * 60), from: readHistorySamples())
        guard let report = usageReportText(samples: samples, status: snapshot?.codex) else {
            showReportAlert(title: "Not enough history yet", detail: "Codex Gauge needs at least two local samples before it can summarize quota movement.")
            return
        }
        NSPasteboard.general.clearContents()
        guard NSPasteboard.general.setString(report, forType: .string) else {
            showReportAlert(title: "Usage report not copied", detail: "The pasteboard did not accept the generated report.")
            return
        }
        showReportAlert(title: "Usage report copied", detail: "Copied to clipboard. No report file was saved.")
        appendLog("usage report copied to clipboard")
    }

    private func showReportAlert(title: String, detail: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = detail
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func clearLocalData() {
        let alert = NSAlert()
        alert.messageText = "Clear legacy data?"
        alert.informativeText = "Codex Gauge runs in Zero persistence mode. This removes old history, last-live cache, report, log, and LaunchAgent files from earlier builds. It does not touch Codex, browser cookies, Keychain, or auth files."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear Legacy Data")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }
        performClearLocalData()
    }

    private func performClearLocalData() {
        let manager = FileManager.default
        var removed = 0
        for path in localDataPathsForClearing() {
            guard manager.fileExists(atPath: path) else {
                continue
            }
            do {
                try FileManager.default.removeItem(atPath: path)
                removed += 1
            } catch {
                showReportAlert(title: "Some data was not cleared", detail: clipped(error.localizedDescription, limit: 180))
                return
            }
        }
        previousFiveHourLeft = nil
        temperatureSamples = []
        systemMetricSamples = []
        clearSystemMetricHistoryAsync()
        clearTemperatureHistoryAsync()
        liveUnavailableSince = nil
        didNotifyLiveUnavailable = false
        resetHighlightUntil = nil
        do {
            if try removeLegacySupportDirectory() {
                removed += 1
            }
        } catch {
            showReportAlert(title: "Some data was not cleared", detail: clipped(error.localizedDescription, limit: 180))
            return
        }
        refreshSignalPopoverIfNeeded()
        rebuildMenu()
        if let snapshot {
            setStatusImage(title: statusTooltipTitle(snapshot), status: snapshot.codex)
        } else {
            setStatusImage(title: "Codex quota")
        }
        showReportAlert(title: "Legacy data cleared", detail: removed == 0 ? "No legacy history, cache, report, log, or LaunchAgent files were present." : "Cleared \(removed) legacy Codex Gauge file(s).")
    }

    private func removePersistentAppStorage() {
        let manager = FileManager.default
        for path in localDataPathsForClearing() {
            guard manager.fileExists(atPath: path) else {
                continue
            }
            try? manager.removeItem(atPath: path)
        }
        removeLaunchAgentPlist()
        unloadLaunchAgent()
        _ = try? removeLegacySupportDirectory()
    }

    private func removeLegacySupportDirectory() throws -> Bool {
        let manager = FileManager.default
        guard manager.fileExists(atPath: supportDir) else {
            return false
        }
        try manager.removeItem(atPath: supportDir)
        return true
    }

    private func clearTemperatureHistoryAsync() {
        temperatureQueue.async { [weak self] in
            guard let self else {
                return
            }
            try? FileManager.default.removeItem(atPath: self.temperatureHistoryPath)
        }
    }

    private func clearSystemMetricHistoryAsync() {
        systemMetricsQueue.async { [weak self] in
            guard let self else {
                return
            }
            try? FileManager.default.removeItem(atPath: self.systemMetricsHistoryPath)
        }
    }

    private func localDataPathsForClearing() -> [String] {
        [
            historyPath,
            temperatureHistoryPath,
            systemMetricsHistoryPath,
            logPath,
            "\(logPath).1",
            "\(supportDir)/\(lastLiveCacheFileName)",
            "\(supportDir)/\(legacyUsageReportFileName)",
            "\(supportDir)/launchd.out.log",
            "\(supportDir)/launchd.err.log",
        ]
    }

    @objc private func openCodexApp() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/Codex.app"))
    }

    @objc private func openSupportFolder() {
        showReportAlert(title: "Zero persistence", detail: "Codex Gauge does not keep a support folder. Clear legacy removes old app files if earlier builds created them.")
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

    @objc private func showSSDTemperaturePreferenceChanged(_ sender: Any?) {
        guard let checkbox = sender as? NSButton else {
            return
        }
        sessionShowSSDTemperatureInMenuBar = checkbox.state == .on
        if let snapshot {
            setStatusImage(title: statusTooltipTitle(snapshot), status: snapshot.codex)
        } else {
            setStatusImage(title: "Codex quota")
        }
    }

    @objc private func launchAtLoginPreferenceChanged(_ sender: Any?) {
        guard let checkbox = sender as? NSButton else {
            return
        }
        checkbox.state = .off
        removeLaunchAgentPlist()
        unloadLaunchAgent()
    }

    private func refresh() {
        guard !isRefreshing else {
            return
        }
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
                    self?.finishRefresh(status: proc.terminationStatus, output: output, errorOutput: errorOutput)
                }
            }
        }

        do {
            try process.run()
        } catch {
            finishRefresh(status: -1, output: "", errorOutput: error.localizedDescription)
            return
        }

        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 45) {
            if process.isRunning {
                process.terminate()
            }
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
        sessionSignalConsoleThemeKey = porcelainLabThemeKey
        sessionRefreshMode = adaptiveRefreshMode
        sessionNotificationsEnabled = false
        sessionShowSSDTemperatureInMenuBar = true
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
        content.addSubview(utilityLabel("Open Codex once, then Codex Gauge keeps your 5-hour and 7-day quota visible from the menu bar.", frame: NSRect(x: 28, y: 248, width: 400, height: 34), size: 12, weight: .regular, color: theme.textSecondary))

        addUtilityStatusRow(to: content, y: 192, title: "Live source", detail: "Uses the local Codex app-server", state: "green")
        addUtilityStatusRow(to: content, y: 148, title: "Menu bar", detail: "Refreshes hands-free after setup", state: "green")
        addUtilityStatusRow(to: content, y: 104, title: "Privacy", detail: "No browser cookies or auth-file reads", state: "green")

        let openCodex = NSButton(title: "Open Codex", target: self, action: #selector(openCodexApp))
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
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 380),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Codex Gauge Preferences"
        window.appearance = NSAppearance(named: theme.appearance)
        window.isReleasedWhenClosed = false

        let content = makeThemedUtilityContentView(size: NSSize(width: 420, height: 380))
        window.contentView = content

        content.addSubview(utilityLabel("Codex Gauge", frame: NSRect(x: 24, y: 334, width: 220, height: 24), size: 16, weight: .semibold, color: theme.textPrimary))

        content.addSubview(utilityLabel("Theme", frame: NSRect(x: 24, y: 292, width: 96, height: 22), size: 13, weight: .medium, color: theme.textSecondary))

        let themeSelect = NSPopUpButton(frame: NSRect(x: 132, y: 290, width: 180, height: 26), pullsDown: false)
        themeSelect.addItems(withTitles: ["Porcelain Lab", "Signal Dark", "Mono Graphite"])
        themeSelect.item(withTitle: "Porcelain Lab")?.representedObject = porcelainLabThemeKey
        themeSelect.item(withTitle: "Signal Dark")?.representedObject = signalDarkThemeKey
        themeSelect.item(withTitle: "Mono Graphite")?.representedObject = monoGraphiteThemeKey
        themeSelect.target = self
        themeSelect.action = #selector(themePreferenceChanged)
        content.addSubview(themeSelect)
        themePopup = themeSelect

        content.addSubview(utilityLabel("Refresh", frame: NSRect(x: 24, y: 252, width: 96, height: 22), size: 13, weight: .medium, color: theme.textSecondary))

        let popup = NSPopUpButton(frame: NSRect(x: 132, y: 250, width: 180, height: 26), pullsDown: false)
        popup.addItems(withTitles: ["Adaptive", "5 minutes", "10 minutes"])
        popup.item(withTitle: "Adaptive")?.representedObject = adaptiveRefreshMode
        popup.item(withTitle: "5 minutes")?.representedObject = fiveMinuteRefreshMode
        popup.item(withTitle: "10 minutes")?.representedObject = tenMinuteRefreshMode
        popup.target = self
        popup.action = #selector(refreshPreferenceChanged)
        content.addSubview(popup)
        refreshPopup = popup

        content.addSubview(utilityLabel("Menu bar", frame: NSRect(x: 24, y: 208, width: 110, height: 22), size: 13, weight: .medium, color: theme.textSecondary))

        let showSSD = NSButton(checkboxWithTitle: "Show SSD temperature in menu bar", target: self, action: #selector(showSSDTemperaturePreferenceChanged))
        showSSD.frame = NSRect(x: 132, y: 206, width: 250, height: 24)
        showSSD.contentTintColor = theme.textSecondary
        content.addSubview(showSSD)
        showSSDTemperatureCheckbox = showSSD

        content.addSubview(utilityLabel("Notifications", frame: NSRect(x: 24, y: 168, width: 110, height: 22), size: 13, weight: .medium, color: theme.textSecondary))

        let notifications = NSButton(checkboxWithTitle: "Quota notifications", target: self, action: #selector(notificationsPreferenceChanged))
        notifications.frame = NSRect(x: 132, y: 166, width: 220, height: 24)
        notifications.contentTintColor = theme.textSecondary
        content.addSubview(notifications)
        notificationsCheckbox = notifications

        content.addSubview(utilityLabel("Startup", frame: NSRect(x: 24, y: 128, width: 110, height: 22), size: 13, weight: .medium, color: theme.textSecondary))

        let login = NSButton(checkboxWithTitle: "Launch at login disabled", target: self, action: #selector(launchAtLoginPreferenceChanged))
        login.frame = NSRect(x: 132, y: 126, width: 220, height: 24)
        login.contentTintColor = theme.textSecondary
        login.isEnabled = false
        content.addSubview(login)
        launchAtLoginCheckbox = login

        content.addSubview(utilityLabel("Diagnostics", frame: NSRect(x: 24, y: 82, width: 110, height: 22), size: 13, weight: .medium, color: theme.textSecondary))

        let testRefresh = NSButton(title: "Test Refresh", target: self, action: #selector(refreshNow))
        testRefresh.frame = NSRect(x: 132, y: 78, width: 92, height: 28)
        styleUtilityButton(testRefresh)
        content.addSubview(testRefresh)

        let setupDoctor = NSButton(title: "Setup Doctor", target: self, action: #selector(openSetupDoctor))
        setupDoctor.frame = NSRect(x: 230, y: 78, width: 108, height: 28)
        styleUtilityButton(setupDoctor)
        content.addSubview(setupDoctor)

        let diagnostics = NSButton(title: "Copy Diagnostics", target: self, action: #selector(copyDiagnostics))
        diagnostics.frame = NSRect(x: 132, y: 46, width: 136, height: 28)
        styleUtilityButton(diagnostics)
        content.addSubview(diagnostics)

        content.addSubview(utilityLabel("Zero persistence: no saved preferences, histories, caches, reports, or logs.", frame: NSRect(x: 24, y: 18, width: 372, height: 18), size: 11, weight: .regular, color: theme.textMuted))

        return window
    }

    private func syncPreferencesControls() {
        let mode = currentRefreshMode()
        refreshPopup?.selectItem(withTitle: refreshTitle(for: mode))
        themePopup?.selectItem(withTitle: currentSignalConsoleTheme().name)
        notificationsCheckbox?.state = notificationsEnabled() ? .on : .off
        showSSDTemperatureCheckbox?.state = showSSDTemperatureInMenuBar() ? .on : .off
        launchAtLoginCheckbox?.state = .off
    }

    private func refreshTitle(for mode: String) -> String {
        switch mode {
        case fiveMinuteRefreshMode:
            return "5 minutes"
        case tenMinuteRefreshMode:
            return "10 minutes"
        default:
            return "Adaptive"
        }
    }

    private func currentSignalConsoleTheme() -> SignalConsoleTheme {
        switch currentSignalConsoleThemeKey() {
        case porcelainLabThemeKey:
            return porcelainLabTheme()
        case signalDarkThemeKey:
            return signalDarkTheme()
        case monoGraphiteThemeKey:
            return monoGraphiteTheme()
        default:
            return porcelainLabTheme()
        }
    }

    private func currentSignalConsoleThemeKey() -> String {
        let key = sessionSignalConsoleThemeKey
        switch key {
        case porcelainLabThemeKey, paperConsoleThemeKey, signalDarkThemeKey, monoGraphiteThemeKey:
            return key
        default:
            return porcelainLabThemeKey
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
            return powerPolicy.normalRefreshInterval
        case tenMinuteRefreshMode:
            return 10 * 60
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
            "PATH": "/Applications/Codex.app/Contents/Resources:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin",
            "PYTHONUNBUFFERED": "1",
            "SHELL": "/bin/zsh",
            "TMPDIR": NSTemporaryDirectory(),
            "USER": userName,
            "CODEX_GAUGE_PYTHON_PATH": pythonPath,
            "CODEX_GAUGE_STATUS_HELPER": usagePath,
            "CODEX_GAUGE_SUPPORT_DIR": NSTemporaryDirectory(),
            "CODEX_GAUGE_NO_STORAGE": "1",
        ]
        if FileManager.default.isExecutableFile(atPath: codexCliBundlePath) {
            helperEnv["CODEX_GAUGE_CODEX_CLI_PATH"] = codexCliBundlePath
        }
        return helperEnv
    }

    private func readSSDTemperature() -> SSDTemperatureStatus? {
        guard FileManager.default.isExecutableFile(atPath: ssdTemperaturePath) else {
            return nil
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ssdTemperaturePath)
        process.currentDirectoryURL = FileManager.default.temporaryDirectory
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            appendLog("ssd temperature helper failed=\(error.localizedDescription)")
            return SSDTemperatureStatus(ok: false, temperatureC: nil, source: "IOReport", error: "SSD sensor unavailable")
        }

        let deadline = Date().addingTimeInterval(ssdTemperatureReadTimeout)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.02)
        }
        if process.isRunning {
            process.terminate()
            process.waitUntilExit()
            appendLog("ssd temperature helper timed out")
            return SSDTemperatureStatus(ok: false, temperatureC: nil, source: "IOReport", error: "SSD sensor timed out")
        }

        let output = stdout.fileHandleForReading.readDataToEndOfFile()
        let errorOutput = stderr.fileHandleForReading.readDataToEndOfFile()
        guard process.terminationStatus == 0 else {
            let errorText = String(data: errorOutput, encoding: .utf8) ?? "SSD sensor unavailable"
            return SSDTemperatureStatus(ok: false, temperatureC: nil, source: "IOReport", error: clipped(errorText, limit: 120))
        }

        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(SSDTemperatureStatus.self, from: output)
        } catch {
            appendLog("ssd temperature parse failed=\(error.localizedDescription)")
            return SSDTemperatureStatus(ok: false, temperatureC: nil, source: "IOReport", error: "SSD sensor unavailable")
        }
    }

    private func configureHardwareSamplersForPowerState() {
        if hardwareBackgroundSamplingAllowed() {
            startSystemMetricsSampler()
            stopTemperatureSampler()
            return
        }
        stopTemperatureSampler()
        stopSystemMetricsSampler()
    }

    private func hardwareBackgroundSamplingAllowed() -> Bool {
        return hardwareSignalsVisible()
    }

    private func startVisibleTemperatureSamplerIfNeeded() {
        stopVisibleTemperatureSampler()
        guard hardwareSignalsVisible() else {
            return
        }
        startTemperatureSampler()
    }

    private func sampleHardwareAfterRefreshIfAllowed() {
        guard hardwareSignalsVisible() else {
            return
        }
        sampleTemperature()
    }

    private func stopVisibleTemperatureSampler() {
        stopTemperatureSampler()
    }

    private func stopTemperatureSampler() {
        temperatureTimer?.invalidate()
        temperatureTimer = nil
    }

    private func stopSystemMetricsSampler() {
        systemMetricsTimer?.invalidate()
        systemMetricsTimer = nil
    }

    private func startTemperatureSampler() {
        temperatureTimer?.invalidate()
        _ = ssdTemperaturePath
        _ = supportDir
        _ = logPath
        sampleTemperature()
        let nextTimer = Timer(timeInterval: temperatureSampleInterval, repeats: true) { [weak self] _ in
            self?.sampleTemperature()
        }
        applyTimerTolerance(nextTimer, interval: temperatureSampleInterval)
        temperatureTimer = nextTimer
        RunLoop.main.add(nextTimer, forMode: .common)
    }

    private func startSystemMetricsSampler() {
        systemMetricsTimer?.invalidate()
        sampleSystemMetrics()
        let nextTimer = Timer(timeInterval: systemMetricSampleInterval, repeats: true) { [weak self] _ in
            self?.sampleSystemMetrics()
        }
        applyTimerTolerance(nextTimer, interval: systemMetricSampleInterval)
        systemMetricsTimer = nextTimer
        RunLoop.main.add(nextTimer, forMode: .common)
    }

    private func startBatterySampler() {
        batteryTimer?.invalidate()
        let interval = batterySampleIntervalForCurrentUI()
        let nextTimer = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            self?.refreshBatteryStatus()
            self?.startBatterySampler()
        }
        applyTimerTolerance(nextTimer, interval: interval)
        batteryTimer = nextTimer
        RunLoop.main.add(nextTimer, forMode: .common)
        startPowerSourceNotifications()
    }

    private func batterySampleIntervalForCurrentUI() -> TimeInterval {
        signalPopover?.isShown == true ? batteryVisibleSampleInterval : batteryIdleSampleInterval
    }

    private func startPowerSourceNotifications() {
        guard batteryRunLoopSource == nil else {
            return
        }
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        guard let source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else {
                return
            }
            let app = Unmanaged<CodexGaugeApp>.fromOpaque(context).takeUnretainedValue()
            DispatchQueue.main.async {
                app.handlePowerSourceChanged()
            }
        }, context)?.takeRetainedValue() else {
            appendLog("battery power source notification unavailable")
            return
        }
        batteryRunLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    }

    private func handlePowerSourceChanged() {
        guard sampleBattery() else {
            return
        }
        scheduleNextRefresh(after: nextRefreshInterval(for: snapshot?.codex))
        configureHardwareSamplersForPowerState()
        if signalPopover?.isShown == true {
            startVisibleTemperatureSamplerIfNeeded()
        }
        startBatterySampler()
        updateBatteryStatusUI()
        resumeAutomaticUpdateCheckAfterPowerReturns()
    }

    private func refreshBatteryStatus() {
        guard sampleBattery() else {
            return
        }
        updateBatteryStatusUI()
        resumeAutomaticUpdateCheckAfterPowerReturns()
    }

    private func updateBatteryStatusUI() {
        rebuildMenu()
        if let snapshot {
            setStatusImage(title: statusTooltipTitle(snapshot), status: snapshot.codex)
        } else {
            setStatusImage(title: "Codex quota")
        }
        refreshSignalPopoverIfNeeded()
    }

    private func sampleBattery() -> Bool {
        let previousBatteryStatus = batteryStatus
        batteryStatus = readBatteryStatus()
        return previousBatteryStatus != batteryStatus
    }

    private func readBatteryStatus() -> BatteryStatus {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            return BatteryStatus(percent: nil, isPluggedIn: nil, isCharging: nil, hasBattery: false, powerSaverActive: false, source: "IOPS", error: "Power source info unavailable")
        }
        guard let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef], !sources.isEmpty else {
            return BatteryStatus(percent: nil, isPluggedIn: true, isCharging: nil, hasBattery: false, powerSaverActive: false, source: "IOPS", error: nil)
        }

        for source in sources {
            guard
                let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                let type = description[kIOPSTypeKey as String] as? String,
                type == kIOPSInternalBatteryType
            else {
                continue
            }

            let current = description[kIOPSCurrentCapacityKey as String] as? Int
            let maximum = description[kIOPSMaxCapacityKey as String] as? Int
            let state = description[kIOPSPowerSourceStateKey as String] as? String
            let isCharging = description[kIOPSIsChargingKey as String] as? Bool
            let percent = batteryPercent(current: current, maximum: maximum)
            let pluggedIn = state == kIOPSACPowerValue ? true : (state == kIOPSBatteryPowerValue ? false : nil)
            let active = pluggedIn == false
            return BatteryStatus(percent: percent, isPluggedIn: pluggedIn, isCharging: isCharging, hasBattery: true, powerSaverActive: active, source: "IOPS", error: nil)
        }

        return BatteryStatus(percent: nil, isPluggedIn: true, isCharging: nil, hasBattery: false, powerSaverActive: false, source: "IOPS", error: nil)
    }

    private func batteryPercent(current: Int?, maximum: Int?) -> Int? {
        guard let current, let maximum, maximum > 0 else {
            return nil
        }
        let value = Int(round(Double(current) * 100.0 / Double(maximum)))
        return max(0, min(100, value))
    }

    private func batteryStatusText(status: BatteryStatus?) -> String {
        guard let status, status.hasBattery else {
            return "Battery --"
        }
        guard let percent = status.percent else {
            return "Battery --"
        }
        return "Battery \(percent)%"
    }

    private func powerSaverStatusText() -> String {
        powerSaverActive() ? "Power Saver active" : "Power Saver off"
    }

    private func refreshCadenceStatusText() -> String {
        let interval = nextRefreshInterval(for: snapshot?.codex)
        let minutes = Int(round(interval / 60.0))
        return "Refresh \(minutes)m"
    }

    private func batteryDisplayText(_ status: BatteryStatus?) -> String {
        guard let status, status.hasBattery, let percent = status.percent else {
            return "--"
        }
        return "\(percent)%"
    }

    private func sampleSystemMetrics() {
        systemMetricsQueue.async { [weak self] in
            guard let self else {
                return
            }
            let metrics = self.readSystemMetrics()
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }
                self.appendSystemMetricSample(cpuPercent: metrics.cpuPercent, ramPercent: metrics.ramPercent)
                if let snapshot = self.snapshot {
                    self.setStatusImage(title: self.statusTooltipTitle(snapshot), status: snapshot.codex)
                } else {
                    self.setStatusImage(title: "Codex quota")
                }
                self.refreshSignalPopoverIfNeeded()
            }
        }
    }

    private func readSystemMetrics() -> (cpuPercent: Int?, ramPercent: Int?) {
        (readCPUUsagePercent(), readRAMUsagePercent())
    }

    private func readCPUUsagePercent() -> Int? {
        var cpuInfo: processor_info_array_t?
        var numCpuInfo = mach_msg_type_number_t(0)
        var numCPUs = natural_t(0)
        let result = host_processor_info(
            mach_host_self(),
            processor_flavor_t(PROCESSOR_CPU_LOAD_INFO),
            &numCPUs,
            &cpuInfo,
            &numCpuInfo
        )
        guard result == KERN_SUCCESS, let cpuInfo else {
            return nil
        }
        defer {
            let byteCount = vm_size_t(Int(numCpuInfo) * MemoryLayout<integer_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: cpuInfo)), byteCount)
        }

        let stateCount = Int(CPU_STATE_MAX)
        let idleIndex = Int(CPU_STATE_IDLE)
        let totalCount = Int(numCPUs) * stateCount
        guard totalCount > 0 else {
            return nil
        }

        var ticks: [UInt64] = []
        ticks.reserveCapacity(totalCount)
        for index in 0..<totalCount {
            let value = Int64(cpuInfo[index])
            ticks.append(UInt64(max(Int64(0), value)))
        }
        defer {
            lastCPUTicks = ticks
        }

        guard let previous = lastCPUTicks, previous.count == ticks.count else {
            let total = ticks.reduce(UInt64(0), +)
            let idle = stride(from: idleIndex, to: ticks.count, by: stateCount).reduce(UInt64(0)) { partial, index in
                partial + ticks[index]
            }
            guard total > 0 else {
                return nil
            }
            return percentage(used: total - idle, total: total)
        }

        var totalDelta = UInt64(0)
        var idleDelta = UInt64(0)
        for index in ticks.indices {
            let delta = ticks[index] >= previous[index] ? ticks[index] - previous[index] : 0
            totalDelta += delta
            if index % stateCount == idleIndex {
                idleDelta += delta
            }
        }
        guard totalDelta > 0 else {
            return nil
        }
        return percentage(used: totalDelta - idleDelta, total: totalDelta)
    }

    private func readRAMUsagePercent() -> Int? {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, rebound, &count)
            }
        }
        guard result == KERN_SUCCESS else {
            return nil
        }

        let active = UInt64(stats.active_count)
        let inactive = UInt64(stats.inactive_count)
        let wired = UInt64(stats.wire_count)
        let free = UInt64(stats.free_count)
        let speculative = UInt64(stats.speculative_count)
        let compressed = UInt64(stats.compressor_page_count)
        let total = active + inactive + wired + free + speculative + compressed
        let used = active + wired + compressed
        guard total > 0 else {
            return nil
        }
        return percentage(used: used, total: total)
    }

    private func percentage(used: UInt64, total: UInt64) -> Int? {
        guard total > 0 else {
            return nil
        }
        let value = Int(round(Double(used) * 100.0 / Double(total)))
        return max(0, min(100, value))
    }

    private func sampleTemperature() {
        guard temperatureReadAllowed() else {
            return
        }
        guard !temperatureReadInFlight else {
            return
        }
        temperatureReadInFlight = true
        temperatureQueue.async { [weak self] in
            guard let self else {
                return
            }
            let status = self.readSSDTemperature()
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }
                self.temperatureReadInFlight = false
                self.recordTemperatureReadResult(status)
                self.ssdTemperature = status
                self.updateLastValidSSDTemperature(status)
                self.appendTemperatureSample(status)
                if let snapshot = self.snapshot {
                    self.setStatusImage(title: self.statusTooltipTitle(snapshot), status: snapshot.codex)
                } else {
                    self.setStatusImage(title: "Codex quota")
                }
            }
        }
    }

    private func temperatureReadAllowed(now: Date = Date()) -> Bool {
        guard let temperatureFailureBackoffUntil else {
            return true
        }
        return now >= temperatureFailureBackoffUntil
    }

    private func recordTemperatureReadResult(_ status: SSDTemperatureStatus?, at date: Date = Date()) {
        guard status?.ok == true else {
            temperatureFailureBackoffUntil = date.addingTimeInterval(temperatureFailureBackoffInterval)
            return
        }
        temperatureFailureBackoffUntil = nil
    }

    private func finishRefresh(status: Int32, output: String, errorOutput: String) {
        isRefreshing = false
        sampleHardwareAfterRefreshIfAllowed()
        appendLog("refresh finished status=\(status) stdout=\(clipped(output, limit: 600)) stderr=\(clipped(errorOutput, limit: 600))")
        if status == 0 {
            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let data = Data(output.utf8)
                let decoded = try decoder.decode(UsageSnapshot.self, from: data)
                snapshot = decoded
                lastError = nil
                handleNotificationTransitions(decoded.codex)
                setStatusImage(title: statusTooltipTitle(decoded), status: decoded.codex)
                startMoodAnimation(for: decoded.codex)
                appendLog("title=\(decoded.title) ok=\(decoded.codex.ok) source=\(decoded.codex.source ?? "") error=\(decoded.codex.error ?? "")")
            } catch {
                snapshot = nil
                lastError = "Could not parse status JSON: \(error.localizedDescription)"
                stopMoodAnimation()
                setStatusImage(title: "Open Codex to refresh live usage")
                appendLog("parse error=\(error.localizedDescription)")
            }
        } else {
            snapshot = nil
            stopMoodAnimation()
            let detail = errorOutput.isEmpty ? output : errorOutput
            lastError = detail.isEmpty ? "Status command exited with code \(status)" : clipped(detail, limit: 160)
            setStatusImage(title: "Open Codex to refresh live usage")
        }
        scheduleNextRefresh(after: nextRefreshInterval(for: snapshot?.codex))
        rebuildMenu()
    }

    private func notificationsEnabled() -> Bool {
        sessionNotificationsEnabled
    }

    private func showSSDTemperatureInMenuBar() -> Bool {
        sessionShowSSDTemperatureInMenuBar
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
                    body: "Codex Gauge is showing cached or snapshot data until live usage returns."
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

        let refresh = NSButton(title: "Run Check", target: self, action: #selector(openSetupDoctor))
        refresh.frame = NSRect(x: 24, y: 20, width: 94, height: 28)
        styleUtilityButton(refresh)
        content.addSubview(refresh)

        let diagnostics = NSButton(title: "Copy Diagnostics", target: self, action: #selector(copyDiagnostics))
        diagnostics.frame = NSRect(x: 124, y: 20, width: 136, height: 28)
        styleUtilityButton(diagnostics, primary: true)
        content.addSubview(diagnostics)

        return window
    }

    private func runSetupDoctorChecks() -> [DoctorCheck] {
        let codexFound = FileManager.default.fileExists(atPath: "/Applications/Codex.app")
        let helperWorks = FileManager.default.isReadableFile(atPath: usagePath)
        let liveAvailable = snapshot?.codex.ok == true && snapshot?.codex.source == "live"
        let launchAgentRunning = isLaunchAgentConfigured()
        let notificationsAllowed = notificationsEnabled()
        let ssdTemperature = self.ssdTemperature
        return [
            DoctorCheck(
                title: "Codex app found",
                state: codexFound ? "green" : "amber",
                detail: codexFound ? "Installed in Applications" : "Install or open Codex"
            ),
            DoctorCheck(
                title: "Helper works",
                state: helperWorks ? "green" : "red",
                detail: helperWorks ? "Bundled helper readable" : "Reinstall Codex Gauge"
            ),
            DoctorCheck(
                title: "Live data available",
                state: liveAvailable ? "green" : "amber",
                detail: liveAvailable ? "Live data is current" : "Open Codex, then Refresh Now"
            ),
            DoctorCheck(
                title: "Session storage",
                state: launchAgentRunning ? "amber" : "green",
                detail: launchAgentRunning ? "Removing old LaunchAgent" : "Zero persistence"
            ),
            DoctorCheck(
                title: "Notifications permission",
                state: notificationsAllowed ? "green" : "grey",
                detail: notificationsAllowed ? "Quota alerts enabled" : "Optional, off by default"
            ),
            ssdTemperatureDoctorCheck(ssdTemperature),
            batteryDoctorCheck(batteryStatus),
        ]
    }

    private func ssdTemperatureDoctorCheck(_ status: SSDTemperatureStatus?) -> DoctorCheck {
        guard let status, status.ok, let temperature = status.temperatureC else {
            return DoctorCheck(title: "SSD temp", state: "grey", detail: "SSD sensor unavailable")
        }
        let detail = ssdTemperatureStatusText(status)
        switch temperature {
        case 70...:
            return DoctorCheck(title: "SSD temp", state: "red", detail: detail)
        case 55..<70:
            return DoctorCheck(title: "SSD temp", state: "amber", detail: detail)
        default:
            return DoctorCheck(title: "SSD temp", state: "green", detail: detail)
        }
    }

    private func batteryDoctorCheck(_ status: BatteryStatus?) -> DoctorCheck {
        guard let status else {
            return DoctorCheck(title: "Battery", state: "grey", detail: "Battery state unavailable")
        }
        guard status.hasBattery else {
            return DoctorCheck(title: "Battery", state: "grey", detail: "No internal battery")
        }
        let detail = "\(batteryDisplayText(status)) · \(status.powerSaverActive ? "Power Saver active" : "plugged in")"
        if let percent = status.percent, percent < 15 {
            return DoctorCheck(title: "Battery", state: "red", detail: detail)
        }
        if status.powerSaverActive {
            return DoctorCheck(title: "Battery", state: "amber", detail: detail)
        }
        return DoctorCheck(title: "Battery", state: "green", detail: detail)
    }

    private func batteryDiagnosticsText() -> String {
        guard let batteryStatus else {
            return "unavailable"
        }
        guard batteryStatus.hasBattery else {
            return "no internal battery"
        }
        let power = batteryStatus.powerSaverActive ? "on battery" : "plugged in"
        return "\(batteryDisplayText(batteryStatus)), \(power)"
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
            addDisabled("Open Codex to refresh live usage")
            addDisabled(clipped(lastError, limit: 96))
        } else {
            addDisabled("Waiting for first refresh")
            addDisabled("Open Codex to refresh live usage")
        }

        menu.addItem(NSMenuItem.separator())
        addDisabled("Codex Gauge v" + appVersion)
        addDisabled("Storage: Zero persistence")
        if let lastUpdateSummary {
            addDisabled(lastUpdateSummary)
        }
        addAction("Check for Updates...", action: #selector(checkForUpdates))
        addAction("Release Page...", action: #selector(openReleases))
        addAction("Preferences...", action: #selector(openPreferences))
        menu.addItem(NSMenuItem.separator())
        addAction("Refresh Now", action: #selector(refreshNow))
        addAction("Open Codex", action: #selector(openCodexApp))
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
            return "Open Codex desktop once to enable live usage"
        }
        switch status.source {
        case "last_live":
            return "Non-live fallback disabled in app"
        case "local_snapshot":
            return "Snapshot fallback disabled in app"
        case "live", nil:
            return status.ok ? "Live data is current" : "Open Codex to refresh live usage"
        default:
            return "Fallback disabled in app"
        }
    }

    private func sourceStatusDetail(_ status: ServiceStatus) -> String {
        if isUnavailableStatus(status) {
            return "After Codex is open, Codex Gauge refreshes hands-free from the menu bar."
        }
        switch status.source {
        case "last_live":
            return "Zero persistence keeps no cached fallback in app mode"
        case "local_snapshot":
            return "Zero persistence keeps no local snapshot fallback in app mode"
        case "live", nil:
            return "Read from local Codex app-server"
        default:
            return "Fallback data is labeled so it is not mistaken for live usage"
        }
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
            if hardwareSignalsVisible() {
                addDisabled("SSD temperature \(ssdTemperatureStatusText(ssdTemperature))")
            }
            addDisabled("Battery \(batteryDisplayText(batteryStatus))")
            addDisabled(powerSaverStatusText())
            if !hardwareSignalsVisible() {
                addDisabled(refreshCadenceStatusText())
            }
            if let resetHighlightUntil, resetHighlightUntil > Date() {
                addDisabled("5h refreshed")
            }
            addDisabled(trendSummary())
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
        guard let button = statusItem.button else {
            return
        }
        button.title = ""
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleNone
        if let status, status.ok, !isUnavailableStatus(status) {
            button.image = makeStatusImage(
                fiveHourLeft: status.fiveHourLeft,
                sevenDayLeft: status.sevenDayLeft,
                fiveHourReset: status.fiveHourReset,
                sevenDayReset: status.sevenDayReset,
                source: status.source,
                ssdTemperature: ssdTemperatureForDisplay(),
                systemMetric: systemMetricSampleForDisplay(),
                batteryStatus: batteryStatus
            )
        } else if let status, status.ok {
            button.image = makeStatusImage(fiveHourLeft: nil, sevenDayLeft: nil, fiveHourReset: nil, sevenDayReset: nil, source: status.source, ssdTemperature: ssdTemperatureForDisplay(), systemMetric: systemMetricSampleForDisplay(), batteryStatus: batteryStatus)
        } else {
            button.image = makeStatusImage(fiveHourLeft: nil, sevenDayLeft: nil, fiveHourReset: nil, sevenDayReset: nil, source: nil, ssdTemperature: ssdTemperatureForDisplay(), systemMetric: systemMetricSampleForDisplay(), batteryStatus: batteryStatus)
        }
        button.toolTip = menuBarTooltipTitle(title: title, status: status)
        button.setAccessibilityLabel("Codex Gauge \(menuBarAccessibilitySummary(status))")
    }

    private func menuBarTooltipTitle(title: String, status: ServiceStatus?) -> String {
        var parts = [title]
        if let status, status.ok, !isUnavailableStatus(status) {
            parts.append("5h resets \(fiveHourResetCountdown(status.fiveHourReset))")
            parts.append("7d resets \(sevenDayResetCountdown(status.sevenDayReset))")
        }
        if hardwareSignalsVisible() {
            let temperature = ssdTemperatureDisplayText(ssdTemperatureForDisplay())
            if temperature != "--°" {
                parts.append("SSD \(temperature)")
            }
            if let metrics = systemMetricSampleForDisplay() {
                parts.append("CPU \(systemMetricPercentText(metrics.cpuPercent))")
                parts.append("RAM \(systemMetricPercentText(metrics.ramPercent))")
            }
        } else {
            parts.append(powerSaverStatusText())
            parts.append(refreshCadenceStatusText())
        }
        parts.append("Battery \(batteryDisplayText(batteryStatus))")
        return parts.joined(separator: " · ")
    }

    private func menuBarAccessibilitySummary(_ status: ServiceStatus?) -> String {
        let temperatureSummary = hardwareSignalsVisible() && showSSDTemperatureInMenuBar()
            ? ", SSD \(ssdTemperatureDisplayText(ssdTemperatureForDisplay()))"
            : ""
        let metrics = hardwareSignalsVisible() ? systemMetricSampleForDisplay() : nil
        let systemSummary = hardwareSignalsVisible()
            ? ", CPU \(systemMetricPercentText(metrics?.cpuPercent)), RAM \(systemMetricPercentText(metrics?.ramPercent))"
            : ", \(powerSaverStatusText()), \(refreshCadenceStatusText())"
        let batterySummary = ", Battery \(batteryDisplayText(batteryStatus))"
        guard let status, status.ok, !isUnavailableStatus(status) else {
            return hardwareSignalsVisible() && showSSDTemperatureInMenuBar()
                ? "SSD \(ssdTemperatureDisplayText(ssdTemperatureForDisplay()))\(systemSummary)\(batterySummary)"
                : "unavailable\(systemSummary)\(batterySummary)"
        }
        let fiveHour = status.fiveHourLeft.map { "\($0)%" } ?? "--"
        let sevenDay = status.sevenDayLeft.map { "\($0)%" } ?? "--"
        return "5h \(fiveHour), 7d \(sevenDay)\(temperatureSummary)\(systemSummary)\(batterySummary)"
    }

    private func statusImageScale() -> CGFloat {
        let buttonScale = statusItem.button?.window?.backingScaleFactor
        let screenScale = NSScreen.main?.backingScaleFactor
        return max(1.0, min(3.0, buttonScale ?? screenScale ?? 2.0))
    }

    private func makeStatusImage(fiveHourLeft: Int?, sevenDayLeft: Int?, fiveHourReset: Double?, sevenDayReset: Double?, source: String?, ssdTemperature: SSDTemperatureStatus?, systemMetric: SystemMetricSample?, batteryStatus: BatteryStatus?) -> NSImage {
        let scale = statusImageScale()
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: max(1, Int(ceil(statusImageSize.width * scale))),
            pixelsHigh: max(1, Int(ceil(statusImageSize.height * scale))),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            let image = NSImage(size: statusImageSize)
            image.isTemplate = false
            return image
        }

        bitmap.size = statusImageSize
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.shouldAntialias = true
        context.cgContext.scaleBy(x: scale, y: scale)

        let image = NSImage(size: statusImageSize)

        let palette = gaugePalette()
        let nonLiveMode = isNonLiveSource(source)
        palette.background.setFill()
        let frame = NSBezierPath(roundedRect: NSRect(origin: .zero, size: statusImageSize), xRadius: 4, yRadius: 4)
        frame.fill()
        (nonLiveMode ? palette.border.withAlphaComponent(0.34) : palette.border).setStroke()
        frame.lineWidth = 1
        frame.stroke()
        drawSignalSourceRail(source: source, palette: palette)
        drawSourceIndicator(source: source, palette: palette)
        drawStatusStateBadge(source: source, palette: palette)

        if isUnavailableStatus(fiveHourLeft: fiveHourLeft, sevenDayLeft: sevenDayLeft, source: source) {
            drawUnavailableGauge(palette: palette)
        } else {
            drawPlanBGauge(
                fiveHourLeft: fiveHourLeft,
                sevenDayLeft: sevenDayLeft,
                fiveHourReset: fiveHourReset,
                sevenDayReset: sevenDayReset,
                palette: palette
            )
        }
        if hardwareSignalsVisible() {
            if showSSDTemperatureInMenuBar() {
                drawMenuBarSSDTemperature(status: ssdTemperature, rect: menuBarTemperatureChipRect, palette: palette)
            }
            drawMenuBarSystemMetricStrip(sample: systemMetric, rect: menuBarSystemMetricStripRect, palette: palette)
        } else {
            drawMenuBarBatteryModeInfo(status: batteryStatus, rect: menuBarBatteryModeInfoRect, palette: palette)
        }
        drawMenuBarBattery(status: batteryStatus, rect: menuBarBatteryRect, palette: palette)

        NSGraphicsContext.restoreGraphicsState()
        image.addRepresentation(bitmap)
        image.isTemplate = false
        return image
    }

    private func drawSourceIndicator(source: String?, palette: GaugePalette) {
        guard let color = sourceIndicatorColor(source) else {
            return
        }
        let marker = NSBezierPath(
            roundedRect: NSRect(x: 2, y: 4, width: 2.5, height: statusImageSize.height - 8),
            xRadius: 1.25,
            yRadius: 1.25
        )
        color.setFill()
        marker.fill()
    }

    private func drawStatusStateBadge(source: String?, palette: GaugePalette) {
        guard isNonLiveSource(source) || source == nil else {
            return
        }
        let label = statusImageStateLabel(source: source)
        let color = sourceIndicatorColor(source) ?? unavailableSourceColor()
        let width: CGFloat = label == "Snapshot" ? 42 : 32
        let rect = NSRect(x: 7, y: 16.2, width: width, height: 5.8)
        let badge = NSBezierPath(roundedRect: rect, xRadius: 2.9, yRadius: 2.9)
        color.withAlphaComponent(0.18).setFill()
        badge.fill()
        color.withAlphaComponent(0.55).setStroke()
        badge.lineWidth = 0.7
        badge.stroke()
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 4.8, weight: .bold),
            .foregroundColor: palette.primaryText,
        ]
        (label as NSString).draw(at: NSPoint(x: rect.minX + 3.5, y: rect.minY + 0.4), withAttributes: attrs)
    }

    private func statusImageStateLabel(source: String?) -> String {
        switch source {
        case "last_live":
            return "Cache"
        case "local_snapshot":
            return "Snapshot"
        case nil:
            return "Open"
        default:
            return "Live"
        }
    }

    private func drawSignalSourceRail(source: String?, palette: GaugePalette) {
        let color = sourceIndicatorColor(source) ?? currentSignalConsoleTheme().mintAccent
        let alpha: CGFloat = isNonLiveSource(source) ? 0.36 : 0.58
        let rail = NSBezierPath(
            roundedRect: NSRect(x: 7, y: statusImageSize.height - 2.8, width: statusImageSize.width - 14, height: 1.2),
            xRadius: 0.6,
            yRadius: 0.6
        )
        color.withAlphaComponent(alpha).setFill()
        rail.fill()
    }

    private func sourceIndicatorColor(_ source: String?) -> NSColor? {
        let theme = currentSignalConsoleTheme()
        switch source {
        case "last_live":
            return theme.amberAccent
        case "local_snapshot":
            return theme.blueAccent.withAlphaComponent(0.72)
        case .some:
            return theme.textMuted.withAlphaComponent(0.70)
        case .none:
            return unavailableSourceColor()
        }
    }

    private func unavailableSourceColor() -> NSColor {
        currentSignalConsoleTheme().amberAccent.withAlphaComponent(0.90)
    }

    private func isUnavailableStatus(fiveHourLeft: Int?, sevenDayLeft: Int?, source: String?) -> Bool {
        fiveHourLeft == nil && sevenDayLeft == nil && source == nil
    }

    private func drawUnavailableGauge(palette: GaugePalette) {
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 7.4, weight: .bold),
            .foregroundColor: palette.primaryText,
        ]
        ("5h" as NSString).draw(at: NSPoint(x: 4, y: 10.5), withAttributes: labelAttrs)
        ("7d" as NSString).draw(at: NSPoint(x: 4, y: 2.0), withAttributes: labelAttrs)

        drawGaugeRail(value: nil, rect: NSRect(x: 24, y: 13, width: quotaRailWidth, height: 3), palette: palette, fillColor: palette.mutedText)
        drawGaugeRail(value: nil, rect: NSRect(x: 24, y: 4, width: quotaRailWidth, height: 3), palette: palette, fillColor: palette.mutedText)

        let dashAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 7.4, weight: .semibold),
            .foregroundColor: palette.mutedText,
        ]
        ("--" as NSString).draw(at: NSPoint(x: 55, y: 9.9), withAttributes: dashAttrs)
        ("--" as NSString).draw(at: NSPoint(x: 55, y: 1.0), withAttributes: dashAttrs)

        let actionAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 7.0, weight: .semibold),
            .foregroundColor: unavailableSourceColor(),
        ]
        ("Open Codex" as NSString).draw(at: NSPoint(x: 116, y: 6.4), withAttributes: actionAttrs)
    }

    private func drawPlanBGauge(fiveHourLeft: Int?, sevenDayLeft: Int?, fiveHourReset: Double?, sevenDayReset: Double?, palette: GaugePalette) {
        drawPlanBRow(window: "5h", quotaLeft: fiveHourLeft, resetEpoch: fiveHourReset, windowHours: 5, y: 13, palette: palette)
        drawPlanBRow(window: "7d", quotaLeft: sevenDayLeft, resetEpoch: sevenDayReset, windowHours: 24 * 7, y: 4, palette: palette)
    }

    private func drawPlanBRow(window: String, quotaLeft: Int?, resetEpoch: Double?, windowHours: Double, y: CGFloat, palette: GaugePalette) {
        let windowAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 7.2, weight: .bold),
            .foregroundColor: palette.primaryText,
        ]
        (window as NSString).draw(at: NSPoint(x: 4, y: y - 2.5), withAttributes: windowAttrs)

        drawQuotaRail(value: quotaLeft, rect: NSRect(x: 24, y: y, width: quotaRailWidth, height: 3), palette: palette)

        let percentText = quotaLeft.map { "\($0)%" } ?? "--"
        let valueAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 6.7, weight: .semibold),
            .foregroundColor: quotaLeft == nil ? palette.mutedText : palette.primaryText,
        ]
        (percentText as NSString).draw(at: NSPoint(x: 55, y: y - 3.1), withAttributes: valueAttrs)

        let resetProgress = resetProgressPercent(epoch: resetEpoch, windowHours: windowHours)
        drawResetMoodLane(value: resetProgress, rect: NSRect(x: 116, y: y, width: resetRailWidth + 6, height: 3), palette: palette)

        let resetText = window == "5h" ? fiveHourResetCountdown(resetEpoch) : sevenDayResetCountdown(resetEpoch)
        let resetAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 5.7, weight: .semibold),
            .foregroundColor: resetEpoch == nil ? palette.mutedText : palette.secondaryText,
        ]
        (resetText as NSString).draw(at: NSPoint(x: 143, y: y - 2.9), withAttributes: resetAttrs)
    }

    private func drawMenuBarSSDTemperature(status: SSDTemperatureStatus?, rect: NSRect, palette: GaugePalette) {
        let color = ssdTemperatureColor(status)
        let path = NSBezierPath(roundedRect: rect, xRadius: 4.0, yRadius: 4.0)
        color.withAlphaComponent(ssdTemperatureFillAlpha(status)).setFill()
        path.fill()
        color.withAlphaComponent(0.64).setStroke()
        path.lineWidth = 0.55
        path.stroke()

        let text = ssdTemperatureDisplayText(status)
        let fontSize: CGFloat = text.count > 3 ? 6.6 : 7.2
        let textColor = status?.ok == true
            ? NSColor.black.withAlphaComponent(0.82)
            : palette.mutedText
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: textColor,
        ]
        (text as NSString).draw(at: NSPoint(x: rect.minX + 2.9, y: rect.minY + 2.45), withAttributes: attrs)
    }

    private func drawMenuBarBattery(status: BatteryStatus?, rect: NSRect, palette: GaugePalette) {
        guard status?.hasBattery == true else {
            return
        }
        let color = batteryMenuBarColor(status, palette: palette)
        let shell = NSBezierPath(roundedRect: rect.insetBy(dx: 0.6, dy: 1.2), xRadius: 3.0, yRadius: 3.0)
        color.withAlphaComponent(status?.isPluggedIn == true ? 0.22 : 0.36).setFill()
        shell.fill()
        color.withAlphaComponent(0.72).setStroke()
        shell.lineWidth = 0.7
        shell.stroke()
        drawMenuBarBatteryTerminal(rect: rect, color: color)
        drawMenuBarBatteryFill(status: status, rect: rect.insetBy(dx: 3.1, dy: 3.7), color: color)
    }

    private func drawMenuBarBatteryModeInfo(status: BatteryStatus?, rect: NSRect, palette: GaugePalette) {
        guard status?.hasBattery == true else {
            return
        }
        let color = batteryMenuBarColor(status, palette: palette)
        let chip = NSBezierPath(roundedRect: rect, xRadius: 4.0, yRadius: 4.0)
        color.withAlphaComponent(isDarkMenuBar() ? 0.24 : 0.18).setFill()
        chip.fill()
        color.withAlphaComponent(0.58).setStroke()
        chip.lineWidth = 0.55
        chip.stroke()

        let text = batteryDisplayText(status)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: text.count > 3 ? 6.3 : 6.9, weight: .bold),
            .foregroundColor: palette.primaryText,
        ]
        (text as NSString).draw(at: NSPoint(x: rect.minX + 4.2, y: rect.minY + 2.5), withAttributes: attrs)
    }

    private func drawMenuBarBatteryTerminal(rect: NSRect, color: NSColor) {
        let terminal = NSBezierPath(roundedRect: NSRect(x: rect.maxX - 1.1, y: rect.midY - 2.8, width: 2.6, height: 5.6), xRadius: 1.1, yRadius: 1.1)
        color.withAlphaComponent(0.72).setFill()
        terminal.fill()
    }

    private func drawMenuBarBatteryFill(status: BatteryStatus?, rect: NSRect, color: NSColor) {
        guard let percent = status?.percent else {
            return
        }
        let fillWidth = max(1.0, rect.width * CGFloat(max(0, min(100, percent))) / 100.0)
        let fill = NSBezierPath(roundedRect: NSRect(x: rect.minX, y: rect.minY, width: fillWidth, height: rect.height), xRadius: 1.8, yRadius: 1.8)
        color.withAlphaComponent(0.88).setFill()
        fill.fill()
    }

    private func batteryMenuBarColor(_ status: BatteryStatus?, palette: GaugePalette) -> NSColor {
        guard let status, status.hasBattery else {
            return palette.mutedText
        }
        guard let percent = status.percent else {
            return palette.mutedText
        }
        if percent < 15 {
            return criticalQuotaColor
        }
        if percent < 30 {
            return warningQuotaColor
        }
        return status.powerSaverActive ? warningQuotaColor : normalQuotaColor
    }

    private func drawMenuBarSystemMetricStrip(sample: SystemMetricSample?, rect: NSRect, palette: GaugePalette) {
        let background = NSBezierPath(roundedRect: rect, xRadius: 3.2, yRadius: 3.2)
        palette.track.withAlphaComponent(isDarkMenuBar() ? 0.48 : 0.30).setFill()
        background.fill()
        palette.border.withAlphaComponent(0.18).setStroke()
        background.lineWidth = 0.45
        background.stroke()

        let cpuText = systemMetricMenuBarText(prefix: "C", value: sample?.cpuPercent)
        let ramText = systemMetricMenuBarText(prefix: "R", value: sample?.ramPercent)
        drawMenuBarSystemMetricAccent(rect: NSRect(x: rect.minX + 4, y: rect.minY + 12.2, width: 2.3, height: 4.2), color: systemMetricMenuBarColor(label: "CPU", value: sample?.cpuPercent, palette: palette))
        drawMenuBarSystemMetricAccent(rect: NSRect(x: rect.minX + 4, y: rect.minY + 4.0, width: 2.3, height: 4.2), color: systemMetricMenuBarColor(label: "RAM", value: sample?.ramPercent, palette: palette))
        drawMenuBarSystemMetricText(cpuText, rect: NSRect(x: rect.minX + 8.2, y: rect.minY + 9.5, width: rect.width - 10, height: 8), color: palette.primaryText)
        drawMenuBarSystemMetricText(ramText, rect: NSRect(x: rect.minX + 8.2, y: rect.minY + 1.3, width: rect.width - 10, height: 8), color: palette.primaryText)
    }

    private func drawMenuBarSystemMetricAccent(rect: NSRect, color: NSColor) {
        let accent = NSBezierPath(roundedRect: rect, xRadius: 1.2, yRadius: 1.2)
        color.withAlphaComponent(0.92).setFill()
        accent.fill()
    }

    private func drawMenuBarSystemMetricText(_ text: String, rect: NSRect, color: NSColor) {
        let fontSize: CGFloat = 7.2
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: color,
        ]
        (text as NSString).draw(at: NSPoint(x: rect.minX, y: rect.minY), withAttributes: attrs)
    }

    private func systemMetricMenuBarText(prefix: String, value: Int?) -> String {
        guard let value else {
            return "\(prefix)--"
        }
        return "\(prefix)\(max(0, min(100, value)))%"
    }

    private func systemMetricMenuBarColor(label: String, value: Int?, palette: GaugePalette) -> NSColor {
        guard value != nil else {
            return palette.mutedText
        }
        if currentSignalConsoleThemeKey() == monoGraphiteThemeKey {
            return palette.primaryText.withAlphaComponent(0.82)
        }
        let theme = currentSignalConsoleTheme()
        return label == "CPU"
            ? theme.blueAccent.withAlphaComponent(isDarkMenuBar() ? 0.95 : 0.82)
            : theme.mintAccent.withAlphaComponent(isDarkMenuBar() ? 0.95 : 0.86)
    }

    private func ssdTemperatureDisplayText(_ status: SSDTemperatureStatus?) -> String {
        guard let status, status.ok, let temperature = status.temperatureC else {
            return "--°"
        }
        return "\(temperature)°"
    }

    private func ssdTemperatureStatusText(_ status: SSDTemperatureStatus?) -> String {
        guard let status, status.ok, let temperature = status.temperatureC else {
            return "unavailable"
        }
        return "\(temperature)°C · \(ssdTemperatureStatusLabel(status))"
    }

    private func ssdTemperatureStatusLabel(_ status: SSDTemperatureStatus?) -> String {
        guard let status, status.ok, let temperature = status.temperatureC else {
            return "Unavailable"
        }
        switch temperature {
        case 70...:
            return "Hot"
        case 55..<70:
            return "Warm"
        default:
            return "Normal"
        }
    }

    private func ssdTemperatureFillAlpha(_ status: SSDTemperatureStatus?) -> CGFloat {
        guard let status, status.ok, let temperature = status.temperatureC else {
            return 0.20
        }
        return temperature >= 70 ? 0.92 : 0.74
    }

    private func ssdTemperatureColor(_ status: SSDTemperatureStatus?) -> NSColor {
        guard let status, status.ok, let temperature = status.temperatureC else {
            return gaugePalette().mutedText
        }
        if currentSignalConsoleThemeKey() == monoGraphiteThemeKey {
            switch temperature {
            case 70...:
                return monoAccent(isDarkMenuBar() ? 0.58 : 0.30, alpha: 0.96)
            case 55..<70:
                return monoAccent(isDarkMenuBar() ? 0.74 : 0.42, alpha: 0.96)
            default:
                return monoAccent(isDarkMenuBar() ? 0.88 : 0.22, alpha: 0.96)
            }
        }
        let theme = currentSignalConsoleTheme()
        switch temperature {
        case 70...:
            return theme.coralAccent
        case 55..<70:
            return theme.amberAccent
        default:
            return theme.mintAccent
        }
    }

    private func drawQuotaRail(value: Int?, rect: NSRect, palette: GaugePalette) {
        drawSegmentedQuotaRail(value: value, rect: rect, palette: palette)
    }

    private func drawSegmentedQuotaRail(value: Int?, rect: NSRect, palette: GaugePalette) {
        drawSignalSegmentedRail(value: value, rect: rect, palette: palette, fillColor: quotaColor(value))
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

    private func drawResetMoodLane(value: Int?, rect: NSRect, palette: GaugePalette) {
        let midY = rect.midY
        let track = NSBezierPath()
        track.move(to: NSPoint(x: rect.minX, y: midY))
        track.line(to: NSPoint(x: rect.maxX, y: midY))
        track.lineCapStyle = .round
        track.lineWidth = rect.height
        palette.resetTrack.setStroke()
        track.stroke()

        guard let value else {
            return
        }

        let markerWidth: CGFloat = 7
        let fraction = clampedFraction(value)
        let markerX = rect.minX + (rect.width - markerWidth) * fraction
        let markerCenterX = markerX + markerWidth * 0.5
        let laneColor = resetLaneColor(value)
        let tail = NSBezierPath()
        tail.move(to: NSPoint(x: rect.minX, y: midY))
        tail.line(to: NSPoint(x: max(rect.minX, markerCenterX - 1), y: midY))
        tail.lineCapStyle = .round
        tail.lineWidth = rect.height
        laneColor.withAlphaComponent(0.68).setStroke()
        tail.stroke()

        let phase = animationTimer == nil ? 0 : sin(Double(moodPulseStep) * .pi / 4.0)
        let yOffset = CGFloat(max(0, phase)) * 0.45
        drawResetMoodFace(
            value: value,
            center: NSPoint(x: markerCenterX, y: midY + yOffset),
            radius: 3.45,
            fill: laneColor
        )
    }

    private func drawResetMoodFace(value: Int, center: NSPoint, radius: CGFloat, fill: NSColor) {
        let faceRect = NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        let face = NSBezierPath(ovalIn: faceRect)
        fill.setFill()
        face.fill()

        let ink = NSColor.black.withAlphaComponent(0.62)
        ink.setFill()
        for eyeX in [center.x - 1.15, center.x + 1.15] {
            NSBezierPath(ovalIn: NSRect(x: eyeX - 0.42, y: center.y + 0.72, width: 0.84, height: 0.84)).fill()
        }

        let mood = CGFloat(max(0, min(100, value))) / 100
        let curve = (mood * 2) - 1
        let mouthY = center.y - 0.9
        let controlY = mouthY - (curve * 1.25)
        let mouth = NSBezierPath()
        mouth.move(to: NSPoint(x: center.x - 1.65, y: mouthY))
        mouth.curve(
            to: NSPoint(x: center.x + 1.65, y: mouthY),
            controlPoint1: NSPoint(x: center.x - 0.55, y: controlY),
            controlPoint2: NSPoint(x: center.x + 0.55, y: controlY)
        )
        mouth.lineWidth = 0.62
        mouth.lineCapStyle = .round
        ink.setStroke()
        mouth.stroke()

        if value < 22 {
            let brow = NSBezierPath()
            brow.move(to: NSPoint(x: center.x - 1.85, y: center.y + 2.18))
            brow.line(to: NSPoint(x: center.x - 0.62, y: center.y + 1.72))
            brow.move(to: NSPoint(x: center.x + 0.62, y: center.y + 1.72))
            brow.line(to: NSPoint(x: center.x + 1.85, y: center.y + 2.18))
            brow.lineWidth = 0.56
            brow.lineCapStyle = .round
            ink.setStroke()
            brow.stroke()
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
        let match = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
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

    private func resetProgressPercent(epoch: Double?, windowHours: Double) -> Int? {
        guard let epoch else {
            return nil
        }
        let secondsRemaining = Date(timeIntervalSince1970: epoch).timeIntervalSinceNow
        if secondsRemaining <= 0 {
            return 100
        }
        let windowSeconds = max(1, windowHours * 3600)
        let progress = 100 - Int(round((secondsRemaining / windowSeconds) * 100))
        return max(0, min(100, progress))
    }

    private func fiveHourResetCountdown(_ epoch: Double?) -> String {
        compactResetCountdown(epoch, includeDays: false)
    }

    private func sevenDayResetCountdown(_ epoch: Double?) -> String {
        compactResetCountdown(epoch, includeDays: true)
    }

    private func compactResetCountdown(_ epoch: Double?, includeDays: Bool) -> String {
        guard let epoch else {
            return "--"
        }
        let remaining = Date(timeIntervalSince1970: epoch).timeIntervalSinceNow
        if remaining <= 0 {
            return "now"
        }
        let minutes = max(1, Int(ceil(remaining / 60)))
        if minutes < 60 {
            return "\(minutes)m"
        }
        let hours = Int(ceil(Double(minutes) / 60.0))
        if includeDays, minutes >= 24 * 60 {
            let days = hours / 24
            let remainingHours = hours % 24
            if days > 0 {
                return "\(days)d\(remainingHours)h"
            }
        }
        return "\(hours)h"
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

    private func powerSaverActive() -> Bool {
        batteryStatus?.powerSaverActive == true
    }

    private func hardwareSignalsVisible() -> Bool {
        powerPolicy.hardwareSignalsVisible(powerSaverActive: powerSaverActive())
    }

    private func batteryPowerSaverRefreshInterval() -> TimeInterval? {
        powerPolicy.batteryPowerSaverRefreshInterval(percent: batteryStatus?.percent)
    }

    private func powerSaverRefreshInterval(for status: ServiceStatus?) -> TimeInterval {
        powerPolicy.powerSaverRefreshInterval(
            statusOK: status?.ok == true,
            fiveHourLeft: status?.fiveHourLeft,
            sevenDayLeft: status?.sevenDayLeft,
            batteryPercent: batteryStatus?.percent
        )
    }

    private func nextRefreshInterval(for status: ServiceStatus?) -> TimeInterval {
        if powerSaverActive() {
            return powerSaverRefreshInterval(for: status)
        }
        return powerPolicy.nextRefreshInterval(
            powerSaverActive: false,
            fixedRefreshInterval: fixedRefreshInterval(),
            statusOK: status?.ok == true,
            fiveHourLeft: status?.fiveHourLeft,
            sevenDayLeft: status?.sevenDayLeft,
            batteryPercent: batteryStatus?.percent
        )
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

    private func readHistorySamples() -> [HistorySample] {
        []
    }

    private func appendSystemMetricSample(cpuPercent: Int?, ramPercent: Int?) {
        let now = Date()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let sample = SystemMetricSample(
            time: formatter.string(from: now),
            cpuPercent: cpuPercent,
            ramPercent: ramPercent,
            ok: cpuPercent != nil || ramPercent != nil,
            timestamp: now.timeIntervalSince1970
        )
        systemMetricSamples.append(sample)
        systemMetricSamples = retainedSystemMetricSamples(systemMetricSamples)
    }

    private func readSystemMetricSamples() -> [SystemMetricSample] {
        []
    }

    private func retainedSystemMetricSamples(_ samples: [SystemMetricSample], now: Date = Date()) -> [SystemMetricSample] {
        let cutoff = now.timeIntervalSince1970 - systemMetricRetentionWindow
        let recent = samples.filter { sample in
            guard let timestamp = systemMetricSampleTimestamp(sample) else {
                return false
            }
            return timestamp >= cutoff
        }
        return Array(recent.suffix(maxSystemMetricSamples))
    }

    private func systemMetricSampleTimestamp(_ sample: SystemMetricSample) -> Double? {
        if let timestamp = sample.timestamp {
            return timestamp
        }
        return isoDate(sample.time)?.timeIntervalSince1970
    }

    private func normalizedSystemMetricSample(_ sample: SystemMetricSample) -> SystemMetricSample {
        guard sample.timestamp == nil, let timestamp = systemMetricSampleTimestamp(sample) else {
            return sample
        }
        return SystemMetricSample(
            time: sample.time,
            cpuPercent: sample.cpuPercent,
            ramPercent: sample.ramPercent,
            ok: sample.ok,
            timestamp: timestamp
        )
    }

    private func normalizedSystemMetricSamples(_ samples: [SystemMetricSample]) -> [SystemMetricSample] {
        samples.map(normalizedSystemMetricSample)
    }

    private func systemMetricGraphSamples(_ samples: [SystemMetricSample], now: Date = Date()) -> [SystemMetricSample] {
        let cutoff = now.timeIntervalSince1970 - systemMetricGraphWindow
        return samples.filter { sample in
            guard let timestamp = systemMetricSampleTimestamp(sample) else {
                return false
            }
            return timestamp >= cutoff
        }
    }

    private func systemMetricSampleForDisplay(now: Date = Date()) -> SystemMetricSample? {
        systemMetricSamples.reversed().first { sample in
            guard sample.ok, let timestamp = systemMetricSampleTimestamp(sample) else {
                return false
            }
            return now.timeIntervalSince1970 - timestamp <= systemMetricGraphWindow
        }
    }

    private func appendTemperatureSample(_ status: SSDTemperatureStatus?) {
        let now = Date()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let sample = TemperatureSample(
            time: formatter.string(from: now),
            temperatureC: status?.ok == true ? status?.temperatureC : nil,
            ok: status?.ok == true && status?.temperatureC != nil,
            timestamp: now.timeIntervalSince1970
        )
        temperatureSamples.append(sample)
        temperatureSamples = retainedTemperatureSamples(temperatureSamples)
    }

    private func readTemperatureSamples() -> [TemperatureSample] {
        []
    }

    private func retainedTemperatureSamples(_ samples: [TemperatureSample], now: Date = Date()) -> [TemperatureSample] {
        let cutoff = now.timeIntervalSince1970 - temperatureHistoryRetentionWindow
        let recent = samples.filter { sample in
            guard let timestamp = temperatureSampleTimestamp(sample) else {
                return false
            }
            return timestamp >= cutoff
        }
        return Array(recent.suffix(maxTemperatureSamples))
    }

    private func temperatureSampleTimestamp(_ sample: TemperatureSample) -> Double? {
        if let timestamp = sample.timestamp {
            return timestamp
        }
        return isoDate(sample.time)?.timeIntervalSince1970
    }

    private func normalizedTemperatureSample(_ sample: TemperatureSample) -> TemperatureSample {
        guard sample.timestamp == nil, let timestamp = temperatureSampleTimestamp(sample) else {
            return sample
        }
        return TemperatureSample(
            time: sample.time,
            temperatureC: sample.temperatureC,
            ok: sample.ok,
            timestamp: timestamp
        )
    }

    private func normalizedTemperatureSamples(_ samples: [TemperatureSample]) -> [TemperatureSample] {
        samples.map(normalizedTemperatureSample)
    }

    private func temperatureGraphSamples(_ samples: [TemperatureSample], now: Date = Date()) -> [TemperatureSample] {
        let cutoff = now.timeIntervalSince1970 - temperatureGraphWindow
        return samples.filter { sample in
            guard let timestamp = temperatureSampleTimestamp(sample) else {
                return false
            }
            return timestamp >= cutoff
        }
    }

    private func retainedHistorySamples(_ samples: [HistorySample], now: Date = Date()) -> [HistorySample] {
        let cutoff = now.addingTimeInterval(-historyRetentionWindow)
        let recent = samples.filter { sample in
            guard let date = historyDate(sample) else {
                return false
            }
            return date >= cutoff
        }
        return Array(recent.suffix(maxHistorySamples))
    }

    private func historyDate(_ sample: HistorySample) -> Date? {
        isoDate(sample.time)
    }

    private func historySamples(since start: Date, from samples: [HistorySample]) -> [HistorySample] {
        samples.filter { sample in
            guard let date = historyDate(sample) else {
                return false
            }
            return date >= start
        }
    }

    private var localCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }

    private func todaySamples(from samples: [HistorySample], now: Date = Date()) -> [HistorySample] {
        let start = localCalendar.startOfDay(for: now)
        return historySamples(since: start, from: samples)
    }

    private func currentFiveHourWindowSamples(from samples: [HistorySample], resetEpoch: Double?, now: Date) -> [HistorySample] {
        let fallbackStart = now.addingTimeInterval(-5 * 60 * 60)
        guard let resetEpoch else {
            return historySamples(since: fallbackStart, from: samples)
        }
        let resetDate = Date(timeIntervalSince1970: resetEpoch)
        let start = resetDate.addingTimeInterval(-5 * 60 * 60)
        guard resetDate > now, start <= now else {
            return historySamples(since: fallbackStart, from: samples)
        }
        return samples.filter { sample in
            guard let date = historyDate(sample) else {
                return false
            }
            return date >= start && date <= now
        }
    }

    private func quotaHistoryValues(_ samples: [HistorySample], _ keyPath: KeyPath<HistorySample, Int?>) -> [Int] {
        samples.compactMap { $0[keyPath: keyPath] }
    }

    private func usageReportSummary(samples: [HistorySample], status: ServiceStatus?) -> UsageReportSummary? {
        let usable = samples.filter { sample in
            historyDate(sample) != nil && (sample.fiveHourLeft != nil || sample.sevenDayLeft != nil)
        }
        guard usable.count >= 2 else {
            return nil
        }
        let liveSampleCount = usable.filter { $0.source == "live" }.count
        return UsageReportSummary(
            windowLabel: "24h",
            sampleCount: usable.count,
            liveSampleCount: liveSampleCount,
            nonLiveSampleCount: usable.count - liveSampleCount,
            firstFiveHourLeft: firstValue(in: usable, \.fiveHourLeft),
            latestFiveHourLeft: latestValue(in: usable, \.fiveHourLeft),
            firstSevenDayLeft: firstValue(in: usable, \.sevenDayLeft),
            latestSevenDayLeft: latestValue(in: usable, \.sevenDayLeft),
            largestFiveHourDrop: largestDrop(in: quotaHistoryValues(usable, \.fiveHourLeft)),
            largestSevenDayDrop: largestDrop(in: quotaHistoryValues(usable, \.sevenDayLeft)),
            sourceCounts: sourceCounts(in: usable, status: status),
            generatedAt: Date()
        )
    }

    private func inlineUsageReportSummary(samples: [HistorySample], status: ServiceStatus?) -> InlineUsageReportSummary {
        guard let summary = usageReportSummary(samples: samples, status: status) else {
            return InlineUsageReportSummary(
                fiveHourMovement: "collecting",
                sevenDayMovement: "collecting",
                todaySummary: todayUsageSummary(samples: samples)
            )
        }
        return InlineUsageReportSummary(
            fiveHourMovement: inlineMovementText(first: summary.firstFiveHourLeft, latest: summary.latestFiveHourLeft),
            sevenDayMovement: inlineMovementText(first: summary.firstSevenDayLeft, latest: summary.latestSevenDayLeft),
            todaySummary: todayUsageSummary(samples: samples, now: summary.generatedAt)
        )
    }

    private func todayUsageSummary(samples: [HistorySample], now: Date = Date()) -> String {
        let usable = todaySamples(from: samples, now: now).filter { sample in
            historyDate(sample) != nil && (sample.fiveHourLeft != nil || sample.sevenDayLeft != nil)
        }
        guard usable.count >= 2 else {
            return "Today collecting · need 2 samples"
        }
        let five = inlineMovementText(first: firstValue(in: usable, \.fiveHourLeft), latest: latestValue(in: usable, \.fiveHourLeft))
        let seven = inlineMovementText(first: firstValue(in: usable, \.sevenDayLeft), latest: latestValue(in: usable, \.sevenDayLeft))
        return "Today \(usable.count) · 5h \(five) · 7d \(seven)"
    }

    private func inlineMovementText(first: Int?, latest: Int?) -> String {
        guard let first, let latest else {
            return "--"
        }
        let delta = latest - first
        if abs(delta) < 2 {
            return "steady"
        }
        return delta > 0 ? "+\(delta)%" : "\(delta)%"
    }

    private func usageReportText(samples: [HistorySample], status: ServiceStatus?) -> String? {
        guard let summary = usageReportSummary(samples: samples, status: status) else {
            return nil
        }
        return [
            "# Codex Gauge Usage Report",
            "",
            "Generated: \(reportDateString(summary.generatedAt))",
            "Window: \(summary.windowLabel)",
            "Current source: \(sourceDisplayName(status?.source))",
            "",
            "## Summary",
            reportHeadline(summary),
            sampleCoverageLine(summary),
            stalePeriodsLine(summary),
            "",
            "## Quota movement estimate",
            movementLine(label: "5-hour", first: summary.firstFiveHourLeft, latest: summary.latestFiveHourLeft, largestDrop: summary.largestFiveHourDrop),
            movementLine(label: "7-day", first: summary.firstSevenDayLeft, latest: summary.latestSevenDayLeft, largestDrop: summary.largestSevenDayDrop),
            "",
            "## Today",
            todayUsageSummary(samples: samples, now: summary.generatedAt),
            "",
            "## Source mix",
            sourceCountsText(summary.sourceCounts),
            "",
            "## Limitations",
            "This report estimates quota movement from local snapshots.",
            "It is not token accounting, billing, or spend.",
        ].joined(separator: "\n")
    }

    private func liveUsageSummaryText(_ status: ServiceStatus) -> String {
        [
            "# Codex Gauge Live Summary",
            "",
            "Generated: \(reportDateString(Date()))",
            "Storage mode: Zero persistence",
            "Current source: \(sourceDisplayName(status.source))",
            "",
            "## Current quota",
            "- 5-hour left: \(percent(status.fiveHourLeft))",
            "- 7-day left: \(percent(status.sevenDayLeft))",
            "- 5-hour reset: \(resetCountdown(status.fiveHourReset))",
            "- 7-day reset: \(resetCountdown(status.sevenDayReset))",
            "",
            "## Limitations",
            "This is a live-only snapshot. Codex Gauge keeps no saved quota history, report file, cache, or log.",
            "It is not token accounting, billing, or spend.",
        ].joined(separator: "\n")
    }

    private func reportHeadline(_ summary: UsageReportSummary) -> String {
        let five = compactMovementText(first: summary.firstFiveHourLeft, latest: summary.latestFiveHourLeft)
        let seven = compactMovementText(first: summary.firstSevenDayLeft, latest: summary.latestSevenDayLeft)
        return "Quota movement over \(summary.windowLabel): 5-hour \(five), 7-day \(seven)."
    }

    private func sampleCoverageLine(_ summary: UsageReportSummary) -> String {
        return "Observed samples: \(summary.sampleCount) total, \(summary.liveSampleCount) live, \(summary.nonLiveSampleCount) non-live."
    }

    private func stalePeriodsLine(_ summary: UsageReportSummary) -> String {
        if summary.nonLiveSampleCount == 0 {
            return "Stale/unavailable periods: none observed in this local window."
        }
        return "Stale/unavailable periods: \(summary.nonLiveSampleCount) non-live samples in this local window."
    }

    private func compactMovementText(first: Int?, latest: Int?) -> String {
        guard let first, let latest else {
            return "unavailable"
        }
        let delta = latest - first
        if abs(delta) < 2 {
            return "steady"
        }
        let sign = delta > 0 ? "+" : ""
        return "\(sign)\(delta)%"
    }

    private func compactSourceCountsText(_ counts: [String: Int]) -> String {
        if counts.isEmpty {
            return "none"
        }
        return counts.keys.sorted().map { key in
            "\(sourceDisplayName(key)) \(counts[key] ?? 0)"
        }.joined(separator: " / ")
    }

    private func firstValue(in samples: [HistorySample], _ keyPath: KeyPath<HistorySample, Int?>) -> Int? {
        samples.compactMap { $0[keyPath: keyPath] }.first
    }

    private func latestValue(in samples: [HistorySample], _ keyPath: KeyPath<HistorySample, Int?>) -> Int? {
        samples.compactMap { $0[keyPath: keyPath] }.last
    }

    private func largestDrop(in values: [Int]) -> Int? {
        guard values.count >= 2 else {
            return nil
        }
        let drops = zip(values, values.dropFirst()).map { previous, current in
            max(0, previous - current)
        }
        return drops.max()
    }

    private func movementLine(label: String, first: Int?, latest: Int?, largestDrop: Int?) -> String {
        guard let first, let latest else {
            return "- \(label): unavailable"
        }
        let delta = latest - first
        let sign = delta > 0 ? "+" : ""
        return "- \(label): \(first)% -> \(latest)% (\(sign)\(delta)%), largest observed drop \(largestDrop ?? 0)%"
    }

    private func sourceCounts(in samples: [HistorySample], status: ServiceStatus?) -> [String: Int] {
        var counts = Dictionary(grouping: samples, by: \.source).mapValues { $0.count }
        if let source = status?.source, counts[source] == nil {
            counts[source] = 0
        }
        return counts
    }

    private func sourceCountsText(_ counts: [String: Int]) -> String {
        if counts.isEmpty {
            return "- none"
        }
        return counts.keys.sorted().map { key in
            "- \(sourceDisplayName(key)): \(counts[key] ?? 0)"
        }.joined(separator: "\n")
    }

    private func sourceDisplayName(_ source: String?) -> String {
        switch source {
        case "live":
            return "Live"
        case "last_live":
            return "Last live"
        case "local_snapshot":
            return "Snapshot"
        case .some(let value):
            return value.replacingOccurrences(of: "_", with: " ").capitalized
        case nil:
            return "Unavailable"
        }
    }

    private func reportDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func trendSummary() -> String {
        let samples = readHistorySamples()
        let now = Date()
        let fiveHourHistory = quotaHistoryValues(
            currentFiveHourWindowSamples(from: samples, resetEpoch: snapshot?.codex.fiveHourReset, now: now),
            \.fiveHourLeft
        )
        let sevenDayHistory = quotaHistoryValues(
            historySamples(since: now.addingTimeInterval(-24 * 60 * 60), from: samples),
            \.sevenDayLeft
        )
        guard fiveHourHistory.count >= 2 || sevenDayHistory.count >= 2 else {
            return "Trend: collecting samples"
        }
        let five = deltaText(label: "5h", values: fiveHourHistory, suffix: "this window")
        let seven = deltaText(label: "7d", values: sevenDayHistory, suffix: "in 24h")
        return "Trend: \(five) - \(seven)"
    }

    private func deltaText(label: String, values: [Int], suffix: String) -> String {
        guard values.count >= 2, let first = values.first, let latest = values.last else {
            return "\(label) collecting"
        }
        let delta = latest - first
        if abs(delta) < 2 {
            return "\(label) stable \(suffix)"
        }
        let sign = delta > 0 ? "+" : ""
        return "\(label) \(sign)\(delta)% \(suffix)"
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

    private func rotateLogIfNeeded(_ url: URL) {
        _ = url
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
        switch status.source {
        case "last_live":
            return lastLiveRefreshMenuLabel
        case "live", nil:
            return liveRefreshMenuLabel
        default:
            return snapshotRefreshMenuLabel
        }
    }

    private func statusTooltipTitle(_ snapshot: UsageSnapshot) -> String {
        guard let suffix = sourceTooltipSuffix(snapshot.codex.source) else {
            return snapshot.title
        }
        return "\(snapshot.title) · \(suffix)"
    }

    private func sourceTooltipSuffix(_ source: String?) -> String? {
        switch source {
        case "last_live":
            return "Zero persistence keeps no cached fallback"
        case "live", nil:
            return nil
        default:
            return "Zero persistence keeps no local snapshot fallback"
        }
    }

    private func isSnapshotSource(_ source: String?) -> Bool {
        guard let source else {
            return false
        }
        return source != "live" && source != "last_live"
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

    private func applicationSupportDirectory() -> String {
        let manager = FileManager.default
        let base = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? manager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("CodexGauge", isDirectory: true).path
    }

    private func ssdTemperatureDiagnosticsText() -> String {
        ssdTemperatureStatusText(ssdTemperature)
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
            "Storage mode: Zero persistence",
            "Current data source: \(source)",
            "Last refresh time: \(lastRefresh)",
            "Last error summary: \(error)",
            "Legacy LaunchAgent state: \(launchState)",
            "Notifications permission: \(notificationState)",
            "SSD temperature: \(ssdTemperatureDiagnosticsText())",
            "Battery state: \(batteryDiagnosticsText())",
            "Power Saver state: \(powerSaverStatusText())",
            "Refresh mode: \(currentRefreshMode())",
            "Updater state: \(lastUpdateSummary ?? "manual check only")",
            "Excludes: browser cookies, ~/.codex/auth.json, session file contents, local histories, caches, reports, runtime logs, prompts, responses",
        ].joined(separator: "\n")
    }

    private func openURL(_ value: String) {
        guard let url = URL(string: value) else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func installLaunchAgentForCurrentApp() -> Bool {
        false
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
                .appendingPathComponent("Contents/MacOS/CodexGauge-bin")
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
