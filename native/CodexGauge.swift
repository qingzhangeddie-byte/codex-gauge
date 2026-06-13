import Cocoa
import Darwin
import Foundation

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

private struct GaugePalette {
    let background: NSColor
    let border: NSColor
    let track: NSColor
    let resetTrack: NSColor
    let primaryText: NSColor
    let secondaryText: NSColor
    let mutedText: NSColor
}

private final class CodexGaugeApp: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private var timer: Timer?
    private var animationTimer: Timer?
    private var snapshot: UsageSnapshot?
    private var lastError: String?
    private var isRefreshing = false
    private var allowTermination = false
    private var activity: NSObjectProtocol?
    private var moodPulseStep = 0
    private let normalRefreshInterval: TimeInterval = 5 * 60
    private let watchRefreshInterval: TimeInterval = 3 * 60
    private let criticalRefreshInterval: TimeInterval = 2 * 60
    private let failureRefreshInterval: TimeInterval = 60
    private let moodAnimationFrameLimit = 8
    private let maxRuntimeLogBytes: UInt64 = 512 * 1024
    private let statusItemWidth: CGFloat = 196
    private let statusImageSize = NSSize(width: 190, height: 22)
    private let quotaRailWidth: CGFloat = 51
    private let resetRailWidth: CGFloat = 34
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
    private let launchAgentLabel = "app.codexgauge.menubar"

    private lazy var resourcesDir = Bundle.main.resourcePath ?? FileManager.default.currentDirectoryPath
    private lazy var supportDir = applicationSupportDirectory()
    private lazy var pythonPath = infoString("CodexGaugePythonPath", fallback: "/usr/bin/python3")
    private lazy var appVersion = infoString("CFBundleShortVersionString", fallback: "0.4.1")
    private lazy var releaseURL = infoString("CodexGaugeReleaseURL", fallback: "https://github.com/qingzhangeddie-byte/codex-gauge/releases")
    private lazy var usagePath = resolveUsagePath()
    private lazy var logPath = "\(supportDir)/\(runtimeLogFileName)"

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
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
        }
        setStatusImage(title: "Codex quota")
        statusItem.menu = menu
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

    @objc private func openSupportFolder() {
        NSWorkspace.shared.open(URL(fileURLWithPath: supportDir, isDirectory: true))
    }

    @objc private func quit() {
        allowTermination = true
        unloadLaunchAgent()
        NSApp.terminate(nil)
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
                setStatusImage(title: statusTooltipTitle(decoded), status: decoded.codex)
                startMoodAnimation(for: decoded.codex)
                appendLog("title=\(decoded.title) ok=\(decoded.codex.ok) source=\(decoded.codex.source ?? "") error=\(decoded.codex.error ?? "")")
            } catch {
                snapshot = nil
                lastError = "Could not parse status JSON: \(error.localizedDescription)"
                stopMoodAnimation()
                setStatusImage(title: "Codex quota unavailable")
                appendLog("parse error=\(error.localizedDescription)")
            }
        } else {
            snapshot = nil
            stopMoodAnimation()
            let detail = errorOutput.isEmpty ? output : errorOutput
            lastError = detail.isEmpty ? "Status command exited with code \(status)" : clipped(detail, limit: 160)
            setStatusImage(title: "Codex quota unavailable")
        }
        rebuildMenu()
        scheduleNextRefresh(after: nextRefreshInterval(for: snapshot?.codex))
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
            addDisabled(clipped(lastError, limit: 96))
        } else {
            addDisabled("Waiting for first refresh")
        }

        menu.addItem(NSMenuItem.separator())
        addDisabled("Codex Gauge v" + appVersion)
        addAction("Check for Updates...", action: #selector(openReleases))
        menu.addItem(NSMenuItem.separator())
        addAction("Refresh Now", action: #selector(refreshNow))
        addAction("Open Codex Analytics", action: #selector(openCodexAnalytics))
        addAction("Open Support Folder", action: #selector(openSupportFolder))
        menu.addItem(NSMenuItem.separator())
        addAction("Quit", action: #selector(quit))
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

    private func addCodexDetail(_ snapshot: UsageSnapshot) {
        let status = snapshot.codex
        if status.ok {
            addDisabled(planTitle(status), monospaced: false)
            addDisabled("\(fiveHourMenuLabel)    \(percent(status.fiveHourLeft))  \(barString(status.fiveHourLeft))", monospaced: true)
            addDisabled("\(sevenDayMenuLabel)     \(percent(status.sevenDayLeft))  \(barString(status.sevenDayLeft))", monospaced: true)
            addDisabled("\(fiveHourResetMenuLabel) \(resetCountdown(status.fiveHourReset))")
            addDisabled("\(sevenDayResetMenuLabel) \(resetCountdown(status.sevenDayReset))")
            addDisabled("\(refreshLabel(status)) \(shortTime(status.dataTime ?? snapshot.updatedAt))")
            return
        }

        addDisabled("Codex")
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
        if let status, status.ok {
            button.image = makeStatusImage(
                fiveHourLeft: status.fiveHourLeft,
                sevenDayLeft: status.sevenDayLeft,
                fiveHourReset: status.fiveHourReset,
                sevenDayReset: status.sevenDayReset,
                source: status.source
            )
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
        drawSourceIndicator(source: source, palette: palette)

        drawPlanBGauge(
            fiveHourLeft: fiveHourLeft,
            sevenDayLeft: sevenDayLeft,
            fiveHourReset: fiveHourReset,
            sevenDayReset: sevenDayReset,
            palette: palette
        )

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

    private func sourceIndicatorColor(_ source: String?) -> NSColor? {
        switch source {
        case "last_live":
            return NSColor(calibratedRed: 1.00, green: 0.67, blue: 0.22, alpha: 0.95)
        case "local_snapshot":
            return NSColor(calibratedRed: 0.38, green: 0.64, blue: 0.92, alpha: 0.72)
        case .some:
            return NSColor(calibratedRed: 0.62, green: 0.62, blue: 0.68, alpha: 0.70)
        case .none:
            return nil
        }
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
        drawGaugeRail(value: value, rect: rect, palette: palette, fillColor: quotaColor(value))
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
            return "Last live"
        case "live", nil:
            return nil
        default:
            return "Snapshot"
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

    private func openURL(_ value: String) {
        guard let url = URL(string: value) else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func unloadLaunchAgent() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["bootout", "gui/\(getuid())/\(launchAgentLabel)"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            appendLog("launch agent unload failed=\(error.localizedDescription)")
        }
    }

}

let app = NSApplication.shared
private let delegate = CodexGaugeApp()
app.delegate = delegate
app.run()
