import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

@main
struct RuntimeBehaviorTests {
    static var checks = 0

    static func check(_ value: @autoclosure () -> Bool, _ message: String) throws {
        checks += 1
        if !value() {
            throw NSError(domain: "RuntimeBehaviorTests", code: checks,
                          userInfo: [NSLocalizedDescriptionKey: message])
        }
    }

    static func main() {
        do {
            try refreshPolicy()
            try readingStates()
            try installationDiscovery()
            #if canImport(CoreGraphics)
            try check(CGEventType(rawValue: UInt32.max) != nil, "All-input idle event type is supported")
            #endif
            print("\(checks) runtime checks passed")
        } catch {
            FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }

    static func refreshPolicy() throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        var policy = GaugeRefreshPolicy()
        try check(policy.canStart(at: start, force: false, installationChanged: false), "Initial refresh must run")
        policy.started(at: start)
        policy.succeeded()
        for second in [0.0, 2, 30, 59] {
            try check(!policy.canStart(at: start.addingTimeInterval(second), force: false, installationChanged: false),
                      "Panel/activation bursts must reuse a recent reading")
        }
        try check(policy.canStart(at: start.addingTimeInterval(60), force: false, installationChanged: false),
                  "Freshness cooldown must expire")
        try check(policy.canStart(at: start, force: true, installationChanged: false), "Manual refresh bypasses cooldown")

        var now = start
        for delay in [60.0, 120, 240, 480, 900, 900] {
            policy.started(at: now)
            policy.failed(at: now, initialDelay: 60)
            try check(policy.retryDelay(at: now) == delay, "Outage retries must back off and stop at 15 minutes")
            try check(!policy.canStart(at: now.addingTimeInterval(delay - 1), force: false, installationChanged: false),
                      "Focus events must not bypass retry backoff")
            try check(policy.canStart(at: now, force: false, installationChanged: true), "A changed installation retries immediately")
            try check(policy.canStart(at: now, force: true, installationChanged: false), "Manual refresh bypasses backoff")
            now = now.addingTimeInterval(delay)
            try check(policy.canStart(at: now, force: false, installationChanged: false), "A due retry must run")
        }
        policy.succeeded()
        try check(policy.failureCount == 0 && policy.retryAt == nil, "Recovery clears accumulated failures")
        policy.failed(at: now, initialDelay: 60)
        try check(policy.retryDelay(at: now) == 60, "A new outage starts with a short retry")
        try check(policy.pollingInterval(base: 300, idleSeconds: 599) == 300, "Active polling remains five minutes")
        try check(policy.pollingInterval(base: 300, idleSeconds: 600) == 600, "Idle polling slows to ten minutes")
        try check(policy.pollingInterval(base: 180, idleSeconds: 1800) == 180, "Low quota stays responsive when idle")
        try check(policy.pollingInterval(base: 120, idleSeconds: 1800) == 120, "Critical quota stays responsive when idle")
        for _ in 0..<20 { policy.failed(at: now, initialDelay: 60) }
        try check(policy.failureCount == 10 && policy.retryDelay(at: now) == 900,
                  "Long outages must retain a bounded retry delay")
    }

    static func readingStates() throws {
        let live = GaugeReadingPresentation(hasReading: true, age: 30, maximumAge: 600, failure: nil, isRefreshing: false)
        try check(live.showsQuota && !live.isStale && live.title == "Live", "A successful recent reading is live")
        for failure in [UsageFailureKind.connection, .timeout, .signIn, .compatibility, .cliMissing, .unknown] {
            let stale = GaugeReadingPresentation(hasReading: true, age: 240, maximumAge: 600, failure: failure, isRefreshing: false)
            try check(stale.showsQuota && stale.isStale && stale.title != "Live", "A retained reading must never be labeled live after failure")
            let retrying = GaugeReadingPresentation(hasReading: true, age: 241, maximumAge: 600, failure: failure, isRefreshing: true)
            try check(retrying.isStale && retrying.title == failure.title, "Retrying must retain the failure state until success")
            let expired = GaugeReadingPresentation(hasReading: true, age: 600, maximumAge: 600, failure: failure, isRefreshing: false)
            try check(!expired.showsQuota && expired.title != "Live", "Expired readings must hide their percentages")
        }
        for age: TimeInterval? in [nil, -1, 601, 1800] {
            let expired = GaugeReadingPresentation(hasReading: true, age: age, maximumAge: 600, failure: nil, isRefreshing: false)
            try check(!expired.showsQuota && expired.title != "Live", "Unknown/invalid/old timestamps cannot become live")
        }
        let missing = GaugeReadingPresentation(hasReading: false, age: 0, maximumAge: 600, failure: .cliMissing, isRefreshing: false)
        try check(!missing.showsQuota && missing.title == "Not found", "Missing CLI must have a distinct state")
        let auth = GaugeReadingPresentation(hasReading: false, age: nil, maximumAge: 600, failure: .signIn, isRefreshing: false)
        try check(auth.title == "Sign in", "Sign-in failures must have a distinct state")
        let changed = GaugeReadingPresentation(hasReading: false, age: nil, maximumAge: 600, failure: .compatibility, isRefreshing: false)
        try check(changed.title == "App changed", "Protocol changes must have a distinct state")
    }

    static func installationDiscovery() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = root.appendingPathComponent("Renamed Host.app")
        let package = app.appendingPathComponent("Contents/Resources/codex-cli")
        let manifest = package.appendingPathComponent("codex-package.json")
        let legacy = app.appendingPathComponent("Contents/Resources/codex")
        let custom = package.appendingPathComponent("next-release/bin/usage-cli")
        func executable(_ url: URL) throws {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data("#!/bin/sh\nexit 0\n".utf8).write(to: url)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        }
        func metadata(_ entrypoint: Any) throws {
            try JSONSerialization.data(withJSONObject: ["entrypoint": entrypoint]).write(to: manifest)
        }
        try executable(legacy)
        try executable(custom)
        try metadata("next-release/bin/usage-cli")
        try check(CodexCLIResolver.find(in: [app]) == custom.resolvingSymlinksInPath().path,
                  "Package metadata must take precedence over an obsolete binary")
        let before = CodexCLIResolver.fingerprint(appURLs: [app], executable: custom.path)
        try metadata("another-version/cli")
        let after = CodexCLIResolver.fingerprint(appURLs: [app], executable: custom.path)
        try check(before != after, "An installation update must change its fingerprint")
        for invalid: Any in ["../codex", legacy.path, "", 42, "next-release"] {
            try metadata(invalid)
            try check(CodexCLIResolver.find(in: [app]) == legacy.path, "Invalid metadata must use a valid fallback")
        }
        try Data("not json".utf8).write(to: manifest)
        try check(CodexCLIResolver.find(in: [app]) == legacy.path, "Malformed metadata must not break old installs")
        let escaped = package.appendingPathComponent("escaped")
        let outside = root.appendingPathComponent("outside-cli")
        try executable(outside)
        try FileManager.default.createSymbolicLink(at: escaped, withDestinationURL: outside)
        try metadata("escaped")
        try check(CodexCLIResolver.find(in: [app]) == legacy.path,
                  "A metadata symlink must not escape its package")
        try metadata("next-release/bin/usage-cli")
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: custom.path)
        try check(CodexCLIResolver.find(in: [app]) == legacy.path, "A nonexecutable entrypoint must be skipped")
        try FileManager.default.removeItem(at: legacy)
        try check(CodexCLIResolver.find(in: [app]) == nil, "No executable must produce a missing-install state")
    }
}
