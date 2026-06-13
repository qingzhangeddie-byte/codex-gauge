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

private struct HistorySample: Codable {
    let time: String
    let source: String
    let fiveHourLeft: Int?
    let sevenDayLeft: Int?
}

private struct DoctorCheck {
    let title: String
    let state: String
    let detail: String
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
    let firstFiveHourLeft: Int?
    let latestFiveHourLeft: Int?
    let firstSevenDayLeft: Int?
    let latestSevenDayLeft: Int?
    let largestFiveHourDrop: Int?
    let largestSevenDayDrop: Int?
    let sourceCounts: [String: Int]
    let generatedAt: Date
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
    let healthSummaryText: String
    let doctorChecks: [DoctorCheck]
    let lastRefreshText: String
    let source: String?
    let isUnavailable: Bool
    let isRefreshing: Bool
}

private final class SignalConsolePanelView: NSView {
    private let model: SignalConsoleModel
    private weak var target: AnyObject?
    private let runCheckAction: Selector
    private let generateReportAction: Selector
    private let copyDiagnosticsAction: Selector
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
        target: AnyObject,
        runCheckAction: Selector,
        generateReportAction: Selector,
        copyDiagnosticsAction: Selector,
        openCodexAction: Selector,
        refreshAction: Selector,
        preferencesAction: Selector,
        quitAction: Selector
    ) {
        self.model = model
        self.target = target
        self.runCheckAction = runCheckAction
        self.generateReportAction = generateReportAction
        self.copyDiagnosticsAction = copyDiagnosticsAction
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
        addButton(title: "Generate", frame: NSRect(x: 528, y: 500, width: 82, height: 28), action: generateReportAction, style: .filled)
        addButton(title: "Run Check...", frame: NSRect(x: 518, y: 558, width: 90, height: 28), action: runCheckAction, style: .icon)
        addButton(title: "Copy", frame: NSRect(x: 548, y: 628, width: 60, height: 30), action: copyDiagnosticsAction, style: .icon)
        addButton(title: "Open Codex", frame: NSRect(x: 28, y: 678, width: 160, height: 30), action: openCodexAction, style: .plain)
        addButton(title: "Refresh Now", frame: NSRect(x: 200, y: 678, width: 150, height: 30), action: refreshAction, style: .plain)
        addButton(title: "Preferences...", frame: NSRect(x: 362, y: 678, width: 150, height: 30), action: preferencesAction, style: .plain)
        addButton(title: "Quit Codex Gauge", frame: NSRect(x: 28, y: 716, width: 220, height: 30), action: quitAction, style: .plain)
    }

    private enum SignalButtonStyle {
        case filled
        case icon
        case plain
    }

    private func addButton(title: String, frame: NSRect, action: Selector, style: SignalButtonStyle) {
        let button = NSButton(title: title, target: target, action: action)
        button.frame = frame
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.cornerRadius = style == .plain ? 7 : 8
        button.layer?.backgroundColor = buttonBackground(style).cgColor
        button.attributedTitle = NSAttributedString(
            string: title,
            attributes: textAttributes(
                size: 13,
                weight: style == .filled ? .medium : .regular,
                color: style == .plain ? textPrimary : textSecondary
            )
        )
        addSubview(button)
    }

    private func buttonBackground(_ style: SignalButtonStyle) -> NSColor {
        switch style {
        case .filled:
            return NSColor.white.withAlphaComponent(0.10)
        case .icon:
            return NSColor.white.withAlphaComponent(0.12)
        case .plain:
            return NSColor.clear
        }
    }

    private func drawSignalConsolePanel() {
        drawPanelBackground()
        drawHeader()
        drawSignalHeroCard()
        drawDivider(y: 144)
        drawStatusSection()
        drawDivider(y: 211)
        drawQuotaSection()
        drawDivider(y: 296)
        drawResetSection()
        drawDivider(y: 374)
        drawTrendSection()
        drawDivider(y: 490)
        drawReportSection()
        drawDivider(y: 548)
        drawHealthSection()
        drawDivider(y: 614)
        drawDiagnosticsSection()
        drawDivider(y: 668)
        drawBottomKeyHints()
    }

    private func drawPanelBackground() {
        let rect = bounds.insetBy(dx: 1, dy: 1)
        let background = NSBezierPath(roundedRect: rect, xRadius: 18, yRadius: 18)
        panelBackground.setFill()
        background.fill()
        panelBorder.setStroke()
        background.lineWidth = 1
        background.stroke()
    }

    private func drawHeader() {
        drawText("Codex Gauge  •  Signal Console", x: 28, y: 20, width: 320, height: 24, size: 14, weight: .medium, color: textSecondary)
        drawPill(text: model.sourcePill, rect: NSRect(x: 462, y: 16, width: 132, height: 28), color: NSColor.white.withAlphaComponent(0.08))
        drawCircle(center: NSPoint(x: 614, y: 30), radius: 10, color: NSColor.white.withAlphaComponent(0.08), stroke: panelBorder)
        drawText("i", x: 610, y: 20, width: 10, height: 20, size: 13, weight: .medium, color: textSecondary)
    }

    private func drawSignalHeroCard() {
        let card = NSRect(x: 28, y: 54, width: bounds.width - 56, height: 74)
        drawRoundedRect(card, radius: 10, fill: cardBackground, stroke: panelBorder)
        drawMiniGaugeRow(label: "5h", value: model.fiveHourLeft, resetProgress: model.fiveHourResetProgress, y: 73)
        drawMiniGaugeRow(label: "7d", value: model.sevenDayLeft, resetProgress: model.sevenDayResetProgress, y: 101)

        let stateColor = sourceColor(source: model.source, unavailable: model.isUnavailable)
        drawText(model.stateTitle, x: 456, y: 72, width: 128, height: 22, size: 16, weight: .medium, color: stateColor)
        drawText(model.stateDetail, x: 456, y: 98, width: 130, height: 22, size: 14, weight: .regular, color: textPrimary)
        drawCircle(center: NSPoint(x: 602, y: 91), radius: 7, color: stateColor, stroke: nil)
        drawRoundedRect(NSRect(x: 615, y: 70, width: 2, height: 42), radius: 1, fill: stateColor, stroke: nil)
    }

    private func drawMiniGaugeRow(label: String, value: Int?, resetProgress: Int?, y: CGFloat) {
        drawText(label, x: 44, y: y - 11, width: 30, height: 22, size: 15, weight: .bold, color: textPrimary, mono: true)
        drawSegmentedRail(value: value, rect: NSRect(x: 86, y: y - 2, width: 126, height: 8), fill: quotaColor(value), segments: 10)
        drawText(percentText(value), x: 232, y: y - 11, width: 52, height: 22, size: 14, weight: .medium, color: value == nil ? textMuted : textPrimary, mono: true)
        drawMoodLane(value: resetProgress, rect: NSRect(x: 324, y: y - 2, width: 104, height: 8))
    }

    private func drawStatusSection() {
        drawSectionLabel("Status", y: 166)
        let color = sourceColor(source: model.source, unavailable: model.isUnavailable)
        drawCircle(center: NSPoint(x: 164, y: 178), radius: 5, color: color, stroke: nil)
        drawText(model.statusTitle, x: 178, y: 164, width: 250, height: 22, size: 14, weight: .medium, color: textPrimary)
        drawText(model.statusDetail, x: 178, y: 188, width: 380, height: 22, size: 13, weight: .regular, color: textSecondary)
        if model.isRefreshing {
            drawPill(text: "Refreshing", rect: NSRect(x: 512, y: 164, width: 88, height: 26), color: NSColor.white.withAlphaComponent(0.08))
        }
    }

    private func drawQuotaSection() {
        drawSectionLabel("Quota", y: 238)
        drawQuotaRow(label: "5-hour", value: model.fiveHourLeft, y: 232)
        drawQuotaRow(label: "7-day", value: model.sevenDayLeft, y: 264)
    }

    private func drawQuotaRow(label: String, value: Int?, y: CGFloat) {
        drawText(label, x: 158, y: y - 3, width: 84, height: 22, size: 14, weight: .regular, color: textPrimary)
        drawText(value.map { "\($0) / 100" } ?? "-- / --", x: 258, y: y - 3, width: 80, height: 22, size: 14, weight: .medium, color: value == nil ? textMuted : textPrimary, mono: true)
        drawSegmentedRail(value: value, rect: NSRect(x: 356, y: y, width: 220, height: 18), fill: quotaColor(value), segments: 12)
        drawText(value == nil ? "Unavailable" : "Live", x: 590, y: y - 3, width: 60, height: 22, size: 13, weight: .regular, color: value == nil ? textMuted : textSecondary)
    }

    private func drawResetSection() {
        drawSectionLabel("Reset", y: 318)
        drawText("5-hour resets in", x: 158, y: 314, width: 140, height: 22, size: 14, weight: .regular, color: textPrimary)
        drawText(model.fiveHourResetText, x: 330, y: 314, width: 120, height: 22, size: 14, weight: .medium, color: resetTextColor(model.fiveHourResetText), mono: true)
        drawText("7-day resets", x: 158, y: 344, width: 140, height: 22, size: 14, weight: .regular, color: textPrimary)
        drawText(model.sevenDayResetText, x: 330, y: 344, width: 140, height: 22, size: 14, weight: .medium, color: resetTextColor(model.sevenDayResetText), mono: true)
    }

    private func drawTrendSection() {
        drawSectionLabel("Trend", y: 402)
        drawTrendRow(label: "5-hour trend", text: model.fiveHourTrendText, values: model.fiveHourHistory, y: 398)
        drawTrendRow(label: "7-day trend", text: model.sevenDayTrendText, values: model.sevenDayHistory, y: 438)
        drawTrendContext()
    }

    private func drawTrendContext() {
        drawText(model.trendContextText, x: 158, y: 466, width: 430, height: 18, size: 11, weight: .regular, color: textMuted)
    }

    private func drawTrendRow(label: String, text: String, values: [Int], y: CGFloat) {
        drawText(label, x: 158, y: y - 3, width: 150, height: 22, size: 14, weight: .regular, color: textPrimary)
        drawText(text, x: 314, y: y - 3, width: 132, height: 22, size: 13, weight: .regular, color: textSecondary)
        drawTrendSparkline(values: values, rect: NSRect(x: 456, y: y - 6, width: 116, height: 30))
        drawPill(text: values.isEmpty ? "--" : deltaPill(values), rect: NSRect(x: 586, y: y - 7, width: 34, height: 24), color: NSColor.white.withAlphaComponent(0.07))
    }

    private func drawReportSection() {
        drawSectionLabel("Report", y: 512)
        drawText("Usage Report", x: 158, y: 506, width: 112, height: 22, size: 14, weight: .regular, color: textPrimary)
        drawText("24h quota summary", x: 286, y: 506, width: 160, height: 22, size: 13, weight: .regular, color: textSecondary)
    }

    private func drawHealthSection() {
        drawSectionLabel("Health", y: 570)
        drawText(model.healthSummaryText, x: 158, y: 562, width: 96, height: 22, size: 13, weight: .medium, color: textPrimary)
        let checks = Array(model.doctorChecks.prefix(5))
        for (index, check) in checks.enumerated() {
            let x = 270 + CGFloat(index) * 47
            drawCircle(center: NSPoint(x: x, y: 573), radius: 4.5, color: doctorColor(check.state), stroke: nil)
            drawText(healthShortLabel(check.title), x: x + 8, y: 563, width: 38, height: 18, size: 10, weight: .regular, color: textSecondary)
        }
    }

    private func drawDiagnosticsSection() {
        drawSectionLabel("Diagnostics", y: 635)
        drawText("Copy Safe Diagnostics...", x: 158, y: 628, width: 220, height: 22, size: 13, weight: .regular, color: textPrimary)
        drawText("Includes: version, source, last error, LaunchAgent state.", x: 158, y: 650, width: 350, height: 20, size: 11, weight: .regular, color: textMuted)
    }

    private func drawBottomKeyHints() {
        drawText("⌘O", x: 584, y: 681, width: 40, height: 22, size: 12, weight: .regular, color: textMuted)
        drawText("⌘Q", x: 584, y: 719, width: 40, height: 22, size: 12, weight: .regular, color: textMuted)
    }

    private func drawTrendSparkline(values: [Int], rect: NSRect) {
        let baseline = NSBezierPath()
        baseline.move(to: NSPoint(x: rect.minX, y: rect.midY + 6))
        baseline.line(to: NSPoint(x: rect.maxX, y: rect.midY + 6))
        baseline.lineWidth = 1
        baseline.setLineDash([5, 5], count: 2, phase: 0)
        NSColor.white.withAlphaComponent(0.16).setStroke()
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
            drawRoundedRect(bar, radius: 1, fill: NSColor.white.withAlphaComponent(0.18), stroke: nil)
        }
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

    private func drawPill(text: String, rect: NSRect, color: NSColor) {
        drawRoundedRect(rect, radius: rect.height / 2, fill: color, stroke: panelBorder.withAlphaComponent(0.42))
        drawText(text, x: rect.minX + 10, y: rect.minY + 4, width: rect.width - 20, height: rect.height - 8, size: 12, weight: .regular, color: textSecondary)
    }

    private func drawSegmentedRail(value: Int?, rect: NSRect, fill: NSColor, segments: Int) {
        let gap: CGFloat = 2
        let segmentWidth = max(2, (rect.width - gap * CGFloat(segments - 1)) / CGFloat(segments))
        let filled = Int(ceil(clamped(value) * CGFloat(segments)))
        for index in 0..<segments {
            let x = rect.minX + CGFloat(index) * (segmentWidth + gap)
            let segmentRect = NSRect(x: x, y: rect.minY, width: segmentWidth, height: rect.height)
            let color = index < filled ? fill : NSColor.white.withAlphaComponent(0.10)
            drawRoundedRect(segmentRect, radius: min(3, rect.height / 2), fill: color, stroke: nil)
        }
    }

    private func drawMoodLane(value: Int?, rect: NSRect) {
        drawRoundedRect(rect, radius: rect.height / 2, fill: NSColor.white.withAlphaComponent(0.10), stroke: nil)
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

    private func deltaPill(_ values: [Int]) -> String {
        guard let first = values.first, let last = values.last else {
            return "--"
        }
        let delta = last - first
        if abs(delta) < 2 {
            return "-"
        }
        return delta > 0 ? "+\(delta)" : "\(delta)"
    }

    private func quotaColor(_ value: Int?) -> NSColor {
        guard let value else {
            return textMuted
        }
        switch max(0, min(100, value)) {
        case 0..<20:
            return NSColor(calibratedRed: 0.92, green: 0.24, blue: 0.28, alpha: 0.96)
        case 20..<45:
            return NSColor(calibratedRed: 0.97, green: 0.49, blue: 0.25, alpha: 0.96)
        case 45..<75:
            return NSColor(calibratedRed: 0.91, green: 0.72, blue: 0.30, alpha: 0.96)
        default:
            return NSColor(calibratedRed: 0.22, green: 0.83, blue: 0.64, alpha: 0.96)
        }
    }

    private func resetColor(_ value: Int) -> NSColor {
        switch max(0, min(100, value)) {
        case 0..<25:
            return NSColor(calibratedRed: 0.85, green: 0.25, blue: 0.22, alpha: 0.95)
        case 25..<55:
            return NSColor(calibratedRed: 0.94, green: 0.43, blue: 0.24, alpha: 0.95)
        case 55..<80:
            return NSColor(calibratedRed: 0.98, green: 0.65, blue: 0.25, alpha: 0.95)
        default:
            return NSColor(calibratedRed: 1.00, green: 0.79, blue: 0.31, alpha: 0.95)
        }
    }

    private func sourceColor(source: String?, unavailable: Bool) -> NSColor {
        if unavailable {
            return NSColor(calibratedRed: 1.00, green: 0.67, blue: 0.28, alpha: 1.0)
        }
        switch source {
        case "last_live":
            return NSColor(calibratedRed: 1.00, green: 0.67, blue: 0.28, alpha: 1.0)
        case "local_snapshot":
            return NSColor(calibratedRed: 0.42, green: 0.66, blue: 0.98, alpha: 1.0)
        default:
            return NSColor(calibratedRed: 0.28, green: 0.84, blue: 0.64, alpha: 1.0)
        }
    }

    private func doctorColor(_ state: String) -> NSColor {
        switch state {
        case "green":
            return NSColor(calibratedRed: 0.28, green: 0.76, blue: 0.46, alpha: 1.0)
        case "amber":
            return NSColor(calibratedRed: 1.00, green: 0.67, blue: 0.28, alpha: 1.0)
        case "red":
            return NSColor(calibratedRed: 0.92, green: 0.24, blue: 0.28, alpha: 1.0)
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
        case "LaunchAgent running":
            return "Login"
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
        NSColor(calibratedRed: 0.04, green: 0.08, blue: 0.12, alpha: 0.84)
    }

    private var cardBackground: NSColor {
        NSColor.white.withAlphaComponent(0.055)
    }

    private var panelBorder: NSColor {
        NSColor.white.withAlphaComponent(0.16)
    }

    private var textPrimary: NSColor {
        NSColor(calibratedRed: 0.88, green: 0.93, blue: 1.00, alpha: 0.96)
    }

    private var textSecondary: NSColor {
        NSColor(calibratedRed: 0.72, green: 0.78, blue: 0.88, alpha: 0.90)
    }

    private var textMuted: NSColor {
        NSColor(calibratedRed: 0.54, green: 0.60, blue: 0.68, alpha: 0.78)
    }
}

private final class CodexGaugeApp: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private var signalPopover: NSPopover?
    private var timer: Timer?
    private var animationTimer: Timer?
    private var preferencesWindow: NSWindow?
    private var setupDoctorWindow: NSWindow?
    private var refreshPopup: NSPopUpButton?
    private var notificationsCheckbox: NSButton?
    private var launchAtLoginCheckbox: NSButton?
    private var snapshot: UsageSnapshot?
    private var lastError: String?
    private var isRefreshing = false
    private var allowTermination = false
    private var activity: NSObjectProtocol?
    private var moodPulseStep = 0
    private var previousFiveHourLeft: Int?
    private var liveUnavailableSince: Date?
    private var didNotifyLiveUnavailable = false
    private var resetHighlightUntil: Date?
    private let normalRefreshInterval: TimeInterval = 5 * 60
    private let watchRefreshInterval: TimeInterval = 3 * 60
    private let criticalRefreshInterval: TimeInterval = 2 * 60
    private let failureRefreshInterval: TimeInterval = 60
    private let moodAnimationFrameLimit = 8
    private let maxRuntimeLogBytes: UInt64 = 512 * 1024
    private let maxHistorySamples = 720
    private let historyRetentionWindow: TimeInterval = 48 * 60 * 60
    private let statusItemWidth: CGFloat = 196
    private let statusImageSize = NSSize(width: 190, height: 22)
    private let signalPopoverSize = NSSize(width: 640, height: 750)
    private let quotaRailWidth: CGFloat = 51
    private let resetRailWidth: CGFloat = 34
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
    private let launchAgentLabel = "app.codexgauge.menubar"
    private let launchAgentPlistName = "app.codexgauge.menubar.plist"
    private let refreshModeKey = "refreshMode"
    private let notificationsEnabledKey = "notificationsEnabled"
    private let launchAtLoginKey = "launchAtLogin"
    private let adaptiveRefreshMode = "adaptive"
    private let fiveMinuteRefreshMode = "5m"
    private let tenMinuteRefreshMode = "10m"
    private let fiveHourLowNotification = "fiveHourLowNotification"
    private let fiveHourRestoredNotification = "fiveHourRestoredNotification"
    private let liveUnavailableNotification = "liveUnavailableNotification"
    private let liveUnavailableNotificationDelay: TimeInterval = 900

    private lazy var resourcesDir = Bundle.main.resourcePath ?? FileManager.default.currentDirectoryPath
    private lazy var supportDir = applicationSupportDirectory()
    private lazy var pythonPath = infoString("CodexGaugePythonPath", fallback: "/usr/bin/python3")
    private lazy var appVersion = infoString("CFBundleShortVersionString", fallback: "0.6.0")
    private lazy var releaseURL = infoString("CodexGaugeReleaseURL", fallback: "https://github.com/qingzhangeddie-byte/codex-gauge/releases")
    private lazy var usagePath = resolveUsagePath()
    private lazy var logPath = "\(supportDir)/\(runtimeLogFileName)"
    private lazy var historyPath = "\(supportDir)/\(historyFileName)"
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
        if let button = statusItem.button {
            button.title = ""
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleNone
            button.toolTip = "Codex quota"
            button.target = self
            button.action = #selector(toggleSignalConsole(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        setStatusImage(title: "Codex quota")
        rebuildMenu()
        refresh()
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        animationTimer?.invalidate()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        allowTermination ? .terminateNow : .terminateCancel
    }

    @objc private func toggleSignalConsole(_ sender: Any?) {
        if let signalPopover, signalPopover.isShown {
            signalPopover.performClose(sender)
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
        popover.appearance = NSAppearance(named: .darkAqua)
        popover.contentSize = signalPopoverSize
        popover.contentViewController = makeSignalConsoleViewController()
        signalPopover = popover
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func refreshSignalPopoverIfNeeded() {
        guard let signalPopover, signalPopover.isShown else {
            return
        }
        signalPopover.contentViewController = makeSignalConsoleViewController()
    }

    private func makeSignalConsoleViewController() -> NSViewController {
        let controller = NSViewController()
        let visual = NSVisualEffectView(frame: NSRect(origin: .zero, size: signalPopoverSize))
        visual.material = .hudWindow
        visual.blendingMode = .behindWindow
        visual.state = .active
        visual.wantsLayer = true
        visual.layer?.cornerRadius = 18
        visual.layer?.masksToBounds = true

        let panel = SignalConsolePanelView(
            frame: visual.bounds,
            model: signalConsoleModel(),
            target: self,
            runCheckAction: #selector(openSetupDoctor),
            generateReportAction: #selector(generateUsageReport),
            copyDiagnosticsAction: #selector(copyDiagnostics),
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
            let fiveHourSamples = currentFiveHourWindowSamples(from: samples, resetEpoch: status.fiveHourReset, now: now)
            let sevenDaySamples = lastDaySamples
            let fiveHourHistory = quotaHistoryValues(fiveHourSamples, \.fiveHourLeft)
            let sevenDayHistory = quotaHistoryValues(sevenDaySamples, \.sevenDayLeft)
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
                healthSummaryText: healthSummaryText(doctorChecks),
                doctorChecks: doctorChecks,
                lastRefreshText: shortTime(status.dataTime ?? snapshot.updatedAt),
                source: status.source,
                isUnavailable: unavailable,
                isRefreshing: isRefreshing
            )
        }

        let detail = lastError == nil ? "Live data is unavailable until Codex is open." : clipped(lastError ?? "", limit: 96)
        let fiveHourSamples = currentFiveHourWindowSamples(from: samples, resetEpoch: nil, now: now)
        let sevenDaySamples = lastDaySamples
        let fiveHourHistory = quotaHistoryValues(fiveHourSamples, \.fiveHourLeft)
        let sevenDayHistory = quotaHistoryValues(sevenDaySamples, \.sevenDayLeft)
        return SignalConsoleModel(
            planName: "Codex Gauge",
            sourcePill: "Source: Menu Bar",
            stateTitle: "Codex closed",
            stateDetail: "Open Codex",
            statusTitle: "Open Codex to refresh live usage.",
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
            healthSummaryText: healthSummaryText(doctorChecks),
            doctorChecks: doctorChecks,
            lastRefreshText: "none",
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

    @objc private func refreshNow() {
        timer?.invalidate()
        refresh()
    }

    @objc private func openCodexAnalytics() {
        openURL("https://chatgpt.com/codex/cloud/settings/analytics")
    }

    @objc private func openReleases() {
        openURL(releaseURL)
    }

    @objc private func openPreferences() {
        let window = preferencesWindow ?? makePreferencesWindow()
        preferencesWindow = window
        syncPreferencesControls()
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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

        let reportURL = URL(fileURLWithPath: supportDir).appendingPathComponent("CodexGauge-usage-report.md")
        do {
            try report.write(to: reportURL, atomically: true, encoding: .utf8)
            showReportAlert(title: "Usage report copied", detail: "Copied to clipboard and saved to Application Support.")
            appendLog("usage report copied path=\(reportURL.path)")
        } catch {
            showReportAlert(title: "Usage report copied", detail: "Copied to clipboard. File save failed: \(error.localizedDescription)")
            appendLog("usage report save failed=\(error.localizedDescription)")
        }
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
        NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/Codex.app"))
    }

    @objc private func openSupportFolder() {
        NSWorkspace.shared.open(URL(fileURLWithPath: supportDir, isDirectory: true))
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
        UserDefaults.standard.set(mode, forKey: refreshModeKey)
        if !isRefreshing {
            scheduleNextRefresh(after: nextRefreshInterval(for: snapshot?.codex))
        }
    }

    @objc private func notificationsPreferenceChanged(_ sender: Any?) {
        guard let checkbox = sender as? NSButton else {
            return
        }
        let enabled = checkbox.state == .on
        UserDefaults.standard.set(enabled, forKey: notificationsEnabledKey)
        if enabled {
            requestNotificationAuthorization()
        }
    }

    @objc private func launchAtLoginPreferenceChanged(_ sender: Any?) {
        guard let checkbox = sender as? NSButton else {
            return
        }
        if checkbox.state == .on {
            if installLaunchAgentForCurrentApp() {
                UserDefaults.standard.set(true, forKey: launchAtLoginKey)
            } else {
                checkbox.state = .off
                UserDefaults.standard.set(false, forKey: launchAtLoginKey)
            }
            return
        }
        removeLaunchAgentPlist()
        unloadLaunchAgent()
        UserDefaults.standard.set(false, forKey: launchAtLoginKey)
    }

    private func refresh() {
        guard !isRefreshing else {
            return
        }
        isRefreshing = true
        if snapshot == nil {
            setStatusImage(title: "Refreshing Codex quota")
        }
        rebuildMenu()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.arguments = [usagePath, "--status-json"]
        process.environment = helperEnvironment()
        process.currentDirectoryURL = URL(fileURLWithPath: supportDir, isDirectory: true)

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
        animationTimer?.invalidate()
        moodPulseStep = 0
        let nextTimer = Timer(timeInterval: 0.18, repeats: true) { [weak self] timer in
            guard let self, let snapshot = self.snapshot, snapshot.codex.ok else {
                timer.invalidate()
                return
            }
            self.moodPulseStep += 1
            self.setStatusImage(title: self.statusTooltipTitle(snapshot), status: snapshot.codex)
            if self.moodPulseStep >= self.moodAnimationFrameLimit {
                self.stopMoodAnimation()
            }
        }
        animationTimer = nextTimer
        RunLoop.main.add(nextTimer, forMode: .common)
    }

    private func stopMoodAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        moodPulseStep = 0
    }

    private func registerDefaultPreferences() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: refreshModeKey) == nil {
            defaults.set(adaptiveRefreshMode, forKey: refreshModeKey)
        }
        if defaults.object(forKey: notificationsEnabledKey) == nil {
            defaults.set(false, forKey: notificationsEnabledKey)
        }
        defaults.set(isLaunchAgentConfigured(), forKey: launchAtLoginKey)
    }

    private func makePreferencesWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Codex Gauge Preferences"
        window.isReleasedWhenClosed = false

        let content = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 300))
        window.contentView = content

        let title = NSTextField(labelWithString: "Codex Gauge")
        title.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        title.frame = NSRect(x: 24, y: 254, width: 220, height: 24)
        content.addSubview(title)

        let refreshLabel = NSTextField(labelWithString: "Refresh")
        refreshLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        refreshLabel.frame = NSRect(x: 24, y: 212, width: 96, height: 22)
        content.addSubview(refreshLabel)

        let popup = NSPopUpButton(frame: NSRect(x: 132, y: 210, width: 180, height: 26), pullsDown: false)
        popup.addItems(withTitles: ["Adaptive", "5 minutes", "10 minutes"])
        popup.item(withTitle: "Adaptive")?.representedObject = adaptiveRefreshMode
        popup.item(withTitle: "5 minutes")?.representedObject = fiveMinuteRefreshMode
        popup.item(withTitle: "10 minutes")?.representedObject = tenMinuteRefreshMode
        popup.target = self
        popup.action = #selector(refreshPreferenceChanged)
        content.addSubview(popup)
        refreshPopup = popup

        let notificationsLabel = NSTextField(labelWithString: "Notifications")
        notificationsLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        notificationsLabel.frame = NSRect(x: 24, y: 168, width: 110, height: 22)
        content.addSubview(notificationsLabel)

        let notifications = NSButton(checkboxWithTitle: "Quota notifications", target: self, action: #selector(notificationsPreferenceChanged))
        notifications.frame = NSRect(x: 132, y: 166, width: 220, height: 24)
        content.addSubview(notifications)
        notificationsCheckbox = notifications

        let startupLabel = NSTextField(labelWithString: "Startup")
        startupLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        startupLabel.frame = NSRect(x: 24, y: 128, width: 110, height: 22)
        content.addSubview(startupLabel)

        let login = NSButton(checkboxWithTitle: "Launch at login", target: self, action: #selector(launchAtLoginPreferenceChanged))
        login.frame = NSRect(x: 132, y: 126, width: 220, height: 24)
        content.addSubview(login)
        launchAtLoginCheckbox = login

        let diagnosticsLabel = NSTextField(labelWithString: "Diagnostics")
        diagnosticsLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        diagnosticsLabel.frame = NSRect(x: 24, y: 82, width: 110, height: 22)
        content.addSubview(diagnosticsLabel)

        let testRefresh = NSButton(title: "Test Refresh", target: self, action: #selector(refreshNow))
        testRefresh.frame = NSRect(x: 132, y: 78, width: 92, height: 28)
        content.addSubview(testRefresh)

        let setupDoctor = NSButton(title: "Setup Doctor", target: self, action: #selector(openSetupDoctor))
        setupDoctor.frame = NSRect(x: 230, y: 78, width: 108, height: 28)
        content.addSubview(setupDoctor)

        let diagnostics = NSButton(title: "Copy Diagnostics", target: self, action: #selector(copyDiagnostics))
        diagnostics.frame = NSRect(x: 132, y: 46, width: 136, height: 28)
        content.addSubview(diagnostics)

        let footer = NSTextField(labelWithString: "Live, Last live, Snapshot, and unavailable labels stay visible in the menu.")
        footer.font = NSFont.systemFont(ofSize: 11)
        footer.textColor = .secondaryLabelColor
        footer.frame = NSRect(x: 24, y: 18, width: 372, height: 18)
        content.addSubview(footer)

        return window
    }

    private func syncPreferencesControls() {
        let mode = currentRefreshMode()
        refreshPopup?.selectItem(withTitle: refreshTitle(for: mode))
        notificationsCheckbox?.state = notificationsEnabled() ? .on : .off
        let launchEnabled = isLaunchAgentConfigured()
        UserDefaults.standard.set(launchEnabled, forKey: launchAtLoginKey)
        launchAtLoginCheckbox?.state = launchEnabled ? .on : .off
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

    private func currentRefreshMode() -> String {
        let mode = UserDefaults.standard.string(forKey: refreshModeKey) ?? adaptiveRefreshMode
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
            "CODEX_GAUGE_SUPPORT_DIR": supportDir,
        ]
        if FileManager.default.isExecutableFile(atPath: codexCliBundlePath) {
            helperEnv["CODEX_GAUGE_CODEX_CLI_PATH"] = codexCliBundlePath
        }
        return helperEnv
    }

    private func finishRefresh(status: Int32, output: String, errorOutput: String) {
        isRefreshing = false
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
                appendHistorySample(decoded.codex)
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
        rebuildMenu()
        scheduleNextRefresh(after: nextRefreshInterval(for: snapshot?.codex))
    }

    private func notificationsEnabled() -> Bool {
        UserDefaults.standard.bool(forKey: notificationsEnabledKey)
    }

    private func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] granted, error in
            DispatchQueue.main.async {
                if let error {
                    self?.appendLog("notification authorization failed=\(error.localizedDescription)")
                }
                if !granted {
                    UserDefaults.standard.set(false, forKey: self?.notificationsEnabledKey ?? "notificationsEnabled")
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
        let checks = runSetupDoctorChecks()
        let rowHeight: CGFloat = 34
        let height = 118 + CGFloat(checks.count) * rowHeight
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: height),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Setup Doctor"
        window.isReleasedWhenClosed = false
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 440, height: height))
        window.contentView = content

        let title = NSTextField(labelWithString: "Setup Doctor")
        title.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        title.frame = NSRect(x: 24, y: height - 42, width: 240, height: 24)
        content.addSubview(title)

        let subtitle = NSTextField(labelWithString: "Checks the local pieces Codex Gauge needs. No cookies, auth files, or logs are copied.")
        subtitle.font = NSFont.systemFont(ofSize: 11)
        subtitle.textColor = .secondaryLabelColor
        subtitle.frame = NSRect(x: 24, y: height - 66, width: 392, height: 18)
        content.addSubview(subtitle)

        var y = height - 104
        for check in checks {
            let dot = NSView(frame: NSRect(x: 26, y: y + 9, width: 10, height: 10))
            dot.wantsLayer = true
            dot.layer?.backgroundColor = doctorStatusColor(check.state).cgColor
            dot.layer?.cornerRadius = 5
            content.addSubview(dot)

            let label = NSTextField(labelWithString: check.title)
            label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
            label.frame = NSRect(x: 50, y: y + 12, width: 160, height: 17)
            content.addSubview(label)

            let detail = NSTextField(labelWithString: check.detail)
            detail.font = NSFont.systemFont(ofSize: 12)
            detail.textColor = .secondaryLabelColor
            detail.frame = NSRect(x: 218, y: y + 11, width: 198, height: 18)
            content.addSubview(detail)
            y -= rowHeight
        }

        let refresh = NSButton(title: "Run Check", target: self, action: #selector(openSetupDoctor))
        refresh.frame = NSRect(x: 24, y: 20, width: 94, height: 28)
        content.addSubview(refresh)

        let diagnostics = NSButton(title: "Copy Diagnostics", target: self, action: #selector(copyDiagnostics))
        diagnostics.frame = NSRect(x: 124, y: 20, width: 136, height: 28)
        content.addSubview(diagnostics)

        return window
    }

    private func runSetupDoctorChecks() -> [DoctorCheck] {
        let codexFound = FileManager.default.fileExists(atPath: "/Applications/Codex.app")
        let helperWorks = FileManager.default.isReadableFile(atPath: usagePath)
        let liveAvailable = snapshot?.codex.ok == true && snapshot?.codex.source == "live"
        let launchAgentRunning = isLaunchAgentConfigured()
        let notificationsAllowed = notificationsEnabled()
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
                title: "LaunchAgent running",
                state: launchAgentRunning ? "green" : "amber",
                detail: launchAgentRunning ? "Starts at login" : "Enable Launch at login"
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
            addDisabled("Open Codex to refresh live usage")
            addDisabled(clipped(lastError, limit: 96))
        } else {
            addDisabled("Waiting for first refresh")
            addDisabled("Open Codex to refresh live usage")
        }

        menu.addItem(NSMenuItem.separator())
        addDisabled("Codex Gauge v" + appVersion)
        addAction("Check for Updates...", action: #selector(openReleases))
        addAction("Preferences...", action: #selector(openPreferences))
        menu.addItem(NSMenuItem.separator())
        addAction("Refresh Now", action: #selector(refreshNow))
        addAction("Open Codex", action: #selector(openCodexApp))
        addAction("Setup Doctor", action: #selector(openSetupDoctor))
        addAction("Copy Diagnostics", action: #selector(copyDiagnostics))
        addAction("Open Codex Analytics", action: #selector(openCodexAnalytics))
        addAction("Open Support Folder", action: #selector(openSupportFolder))
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
            return "Open Codex to refresh live usage"
        }
        switch status.source {
        case "last_live":
            return "Showing last live cache"
        case "local_snapshot":
            return "Showing recent local snapshot"
        case "live", nil:
            return status.ok ? "Live data is current" : "Open Codex to refresh live usage"
        default:
            return "Showing recent local snapshot"
        }
    }

    private func sourceStatusDetail(_ status: ServiceStatus) -> String {
        if isUnavailableStatus(status) {
            return "Codex is closed or unreachable. Open Codex, then Refresh Now."
        }
        switch status.source {
        case "last_live":
            return "Codex not reachable - showing last live"
        case "local_snapshot":
            return "Codex closed - showing recent local snapshot"
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
                source: status.source
            )
        } else if let status, status.ok {
            button.image = makeStatusImage(fiveHourLeft: nil, sevenDayLeft: nil, fiveHourReset: nil, sevenDayReset: nil, source: status.source)
        } else {
            button.image = makeStatusImage(fiveHourLeft: nil, sevenDayLeft: nil, fiveHourReset: nil, sevenDayReset: nil, source: nil)
        }
        button.toolTip = title
    }

    private func makeStatusImage(fiveHourLeft: Int?, sevenDayLeft: Int?, fiveHourReset: Double?, sevenDayReset: Double?, source: String?) -> NSImage {
        let image = NSImage(size: statusImageSize)
        image.lockFocus()

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

        image.unlockFocus()
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

    private func drawSignalSourceRail(source: String?, palette: GaugePalette) {
        let color = sourceIndicatorColor(source) ?? NSColor(calibratedRed: 0.14, green: 0.79, blue: 0.60, alpha: 0.82)
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
        switch source {
        case "last_live":
            return NSColor(calibratedRed: 1.00, green: 0.67, blue: 0.22, alpha: 0.95)
        case "local_snapshot":
            return NSColor(calibratedRed: 0.38, green: 0.64, blue: 0.92, alpha: 0.72)
        case .some:
            return NSColor(calibratedRed: 0.62, green: 0.62, blue: 0.68, alpha: 0.70)
        case .none:
            return unavailableSourceColor()
        }
    }

    private func unavailableSourceColor() -> NSColor {
        NSColor(calibratedRed: 1.00, green: 0.62, blue: 0.22, alpha: 0.90)
    }

    private func isUnavailableStatus(fiveHourLeft: Int?, sevenDayLeft: Int?, source: String?) -> Bool {
        fiveHourLeft == nil && sevenDayLeft == nil && source == nil
    }

    private func drawUnavailableGauge(palette: GaugePalette) {
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 7.4, weight: .bold),
            .foregroundColor: palette.primaryText,
        ]
        ("5h" as NSString).draw(at: NSPoint(x: 6, y: 10.5), withAttributes: labelAttrs)
        ("7d" as NSString).draw(at: NSPoint(x: 6, y: 2.0), withAttributes: labelAttrs)

        drawGaugeRail(value: nil, rect: NSRect(x: 27, y: 13, width: quotaRailWidth, height: 3), palette: palette, fillColor: palette.mutedText)
        drawGaugeRail(value: nil, rect: NSRect(x: 27, y: 4, width: quotaRailWidth, height: 3), palette: palette, fillColor: palette.mutedText)

        let dashAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 7.4, weight: .semibold),
            .foregroundColor: palette.mutedText,
        ]
        ("--" as NSString).draw(at: NSPoint(x: 83, y: 9.9), withAttributes: dashAttrs)
        ("--" as NSString).draw(at: NSPoint(x: 83, y: 1.0), withAttributes: dashAttrs)

        let actionAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 7.2, weight: .semibold),
            .foregroundColor: unavailableSourceColor(),
        ]
        ("Open Codex" as NSString).draw(at: NSPoint(x: 122, y: 6.4), withAttributes: actionAttrs)
    }

    private func drawPlanBGauge(fiveHourLeft: Int?, sevenDayLeft: Int?, fiveHourReset: Double?, sevenDayReset: Double?, palette: GaugePalette) {
        drawPlanBRow(window: "5h", quotaLeft: fiveHourLeft, resetEpoch: fiveHourReset, windowHours: 5, y: 13, palette: palette)
        drawPlanBRow(window: "7d", quotaLeft: sevenDayLeft, resetEpoch: sevenDayReset, windowHours: 24 * 7, y: 4, palette: palette)
    }

    private func drawPlanBRow(window: String, quotaLeft: Int?, resetEpoch: Double?, windowHours: Double, y: CGFloat, palette: GaugePalette) {
        let windowAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 7.4, weight: .bold),
            .foregroundColor: palette.primaryText,
        ]
        (window as NSString).draw(at: NSPoint(x: 6, y: y - 2.5), withAttributes: windowAttrs)

        drawQuotaRail(value: quotaLeft, rect: NSRect(x: 27, y: y, width: quotaRailWidth, height: 3), palette: palette)

        let percentText = quotaLeft.map { "\($0)%" } ?? "--"
        let valueAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 7.4, weight: .semibold),
            .foregroundColor: quotaLeft == nil ? palette.mutedText : palette.primaryText,
        ]
        (percentText as NSString).draw(at: NSPoint(x: 83, y: y - 3.1), withAttributes: valueAttrs)

        let resetProgress = resetProgressPercent(epoch: resetEpoch, windowHours: windowHours)
        drawResetMoodLane(value: resetProgress, rect: NSRect(x: 122, y: y, width: resetRailWidth + 4, height: 3), palette: palette)

        let resetText = window == "5h" ? fiveHourResetCountdown(resetEpoch) : sevenDayResetCountdown(resetEpoch)
        let resetAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 6.8, weight: .semibold),
            .foregroundColor: resetEpoch == nil ? palette.mutedText : palette.secondaryText,
        ]
        (resetText as NSString).draw(at: NSPoint(x: 164, y: y - 3.2), withAttributes: resetAttrs)
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
        if isDarkMenuBar() {
            return GaugePalette(
                background: NSColor(calibratedRed: 0.05, green: 0.11, blue: 0.12, alpha: 0.88),
                border: NSColor(calibratedRed: 0.30, green: 0.62, blue: 0.58, alpha: 0.62),
                track: NSColor.white.withAlphaComponent(0.18),
                resetTrack: NSColor(calibratedRed: 1.00, green: 0.68, blue: 0.22, alpha: 0.24),
                primaryText: NSColor.white.withAlphaComponent(0.94),
                secondaryText: NSColor.white.withAlphaComponent(0.72),
                mutedText: NSColor.white.withAlphaComponent(0.42)
            )
        }
        return GaugePalette(
            background: NSColor.white.withAlphaComponent(0.72),
            border: NSColor.black.withAlphaComponent(0.22),
            track: NSColor.black.withAlphaComponent(0.15),
            resetTrack: NSColor(calibratedRed: 0.92, green: 0.50, blue: 0.12, alpha: 0.26),
            primaryText: NSColor.black.withAlphaComponent(0.82),
            secondaryText: NSColor.black.withAlphaComponent(0.58),
            mutedText: NSColor.black.withAlphaComponent(0.34)
        )
    }

    private func isDarkMenuBar() -> Bool {
        let match = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
        return match == .darkAqua
    }

    private func bucketedGaugeColor(_ value: Int?) -> NSColor {
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
        let hours = max(1, Int(ceil(remaining / 3600)))
        if includeDays {
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

    private func minQuota(_ first: Int?, _ second: Int?) -> Int? {
        let values = [first, second].compactMap { $0 }
        return values.min()
    }

    private func nextRefreshInterval(for status: ServiceStatus?) -> TimeInterval {
        guard let status, status.ok else {
            return failureRefreshInterval
        }
        if let interval = fixedRefreshInterval() {
            return interval
        }
        guard let lowest = minQuota(status.fiveHourLeft, status.sevenDayLeft) else {
            return failureRefreshInterval
        }
        if lowest < 10 {
            return criticalRefreshInterval
        }
        if lowest <= 40 {
            return watchRefreshInterval
        }
        return normalRefreshInterval
    }

    private func scheduleNextRefresh(after interval: TimeInterval) {
        timer?.invalidate()
        let nextTimer = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            self?.refresh()
        }
        timer = nextTimer
        RunLoop.main.add(nextTimer, forMode: .common)
    }

    private func appendHistorySample(_ status: ServiceStatus) {
        guard status.ok, status.fiveHourLeft != nil || status.sevenDayLeft != nil else {
            return
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let sample = HistorySample(
            time: status.dataTime ?? formatter.string(from: Date()),
            source: status.source ?? "live",
            fiveHourLeft: status.fiveHourLeft,
            sevenDayLeft: status.sevenDayLeft
        )
        var samples = readHistorySamples()
        if let latest = samples.last,
           latest.time == sample.time,
           latest.source == sample.source,
           latest.fiveHourLeft == sample.fiveHourLeft,
           latest.sevenDayLeft == sample.sevenDayLeft {
            return
        }
        samples.append(sample)
        samples = retainedHistorySamples(samples)
        do {
            let data = try JSONEncoder().encode(samples)
            try FileManager.default.createDirectory(
                atPath: (historyPath as NSString).deletingLastPathComponent,
                withIntermediateDirectories: true
            )
            try data.write(to: URL(fileURLWithPath: historyPath), options: .atomic)
        } catch {
            appendLog("history write failed=\(error.localizedDescription)")
        }
    }

    private func readHistorySamples() -> [HistorySample] {
        guard
            let data = try? Data(contentsOf: URL(fileURLWithPath: historyPath)),
            let samples = try? JSONDecoder().decode([HistorySample].self, from: data)
        else {
            return []
        }
        return retainedHistorySamples(samples)
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
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return fractional.date(from: sample.time) ?? plain.date(from: sample.time)
    }

    private func historySamples(since start: Date, from samples: [HistorySample]) -> [HistorySample] {
        samples.filter { sample in
            guard let date = historyDate(sample) else {
                return false
            }
            return date >= start
        }
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
        return UsageReportSummary(
            windowLabel: "24h",
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
            "## Quota movement estimate",
            movementLine(label: "5-hour", first: summary.firstFiveHourLeft, latest: summary.latestFiveHourLeft, largestDrop: summary.largestFiveHourDrop),
            movementLine(label: "7-day", first: summary.firstSevenDayLeft, latest: summary.latestSevenDayLeft, largestDrop: summary.largestSevenDayDrop),
            "",
            "## Source mix",
            sourceCountsText(summary.sourceCounts),
            "",
            "## Limitations",
            "This report estimates quota movement from local snapshots.",
            "It is not token accounting, billing, or spend.",
        ].joined(separator: "\n")
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
        let url = URL(fileURLWithPath: logPath)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        rotateLogIfNeeded(url)
        let line = "[\(Date())] \(value)\n"
        guard let data = line.data(using: .utf8) else {
            return
        }
        if FileManager.default.fileExists(atPath: logPath),
           let handle = try? FileHandle(forWritingTo: url) {
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
            try? handle.close()
        } else {
            try? data.write(to: url)
        }
    }

    private func rotateLogIfNeeded(_ url: URL) {
        guard
            let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
            let size = attrs[.size] as? NSNumber,
            size.uint64Value > maxRuntimeLogBytes
        else {
            return
        }
        let rotated = url.appendingPathExtension("1")
        try? FileManager.default.removeItem(at: rotated)
        try? FileManager.default.moveItem(at: url, to: rotated)
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
            return "Codex not reachable - showing last live"
        case "live", nil:
            return nil
        default:
            return "Codex closed - showing recent local snapshot"
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

    private func shortTime(_ value: String) -> String {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        let date = fractional.date(from: value) ?? plain.date(from: value)
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
        let target = Date(timeIntervalSince1970: epoch)
        let remaining = target.timeIntervalSinceNow
        if remaining <= 0 {
            return "now"
        }
        let minutes = max(1, Int(ceil(remaining / 60)))
        if minutes < 60 {
            return "in \(minutes)m"
        }
        if minutes < 24 * 60 {
            return "in \(minutes / 60)h \(minutes % 60)m"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE HH:mm"
        return formatter.string(from: target)
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
        let url = base.appendingPathComponent("CodexGauge", isDirectory: true)
        try? manager.createDirectory(at: url, withIntermediateDirectories: true)
        return url.path
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
            "Current data source: \(source)",
            "Last refresh time: \(lastRefresh)",
            "Last error summary: \(error)",
            "LaunchAgent state: \(launchState)",
            "Notifications permission: \(notificationState)",
            "Refresh mode: \(currentRefreshMode())",
            "Excludes: browser cookies, ~/.codex/auth.json, Session file contents, Runtime logs, prompts, responses",
        ].joined(separator: "\n")
    }

    private func openURL(_ value: String) {
        guard let url = URL(string: value) else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func installLaunchAgentForCurrentApp() -> Bool {
        let binaryPath = currentAppBinaryPath()
        guard FileManager.default.isExecutableFile(atPath: binaryPath) else {
            appendLog("launch agent install failed=missing executable \(binaryPath)")
            return false
        }

        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
          <key>Label</key>
          <string>\(xmlEscaped(launchAgentLabel))</string>
          <key>ProgramArguments</key>
          <array>
            <string>\(xmlEscaped(binaryPath))</string>
          </array>
          <key>RunAtLoad</key>
          <true/>
          <key>KeepAlive</key>
          <true/>
          <key>LimitLoadToSessionType</key>
          <string>Aqua</string>
          <key>ProcessType</key>
          <string>Interactive</string>
          <key>StandardOutPath</key>
          <string>\(xmlEscaped(supportDir + "/launchd.out.log"))</string>
          <key>StandardErrorPath</key>
          <string>\(xmlEscaped(supportDir + "/launchd.err.log"))</string>
        </dict>
        </plist>
        """

        do {
            try FileManager.default.createDirectory(
                atPath: (launchAgentPlistPath as NSString).deletingLastPathComponent,
                withIntermediateDirectories: true
            )
            try FileManager.default.createDirectory(atPath: supportDir, withIntermediateDirectories: true)
            try plist.write(toFile: launchAgentPlistPath, atomically: true, encoding: .utf8)
            unloadLaunchAgent()
            _ = runLaunchctl(arguments: ["bootstrap", launchctlDomain(), launchAgentPlistPath])
            _ = runLaunchctl(arguments: ["kickstart", "-k", "\(launchctlDomain())/\(launchAgentLabel)"])
            appendLog("launch agent installed path=\(launchAgentPlistPath)")
            return true
        } catch {
            appendLog("launch agent install failed=\(error.localizedDescription)")
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

let app = NSApplication.shared
private let delegate = CodexGaugeApp()
app.delegate = delegate
app.run()
