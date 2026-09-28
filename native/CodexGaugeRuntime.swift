import Foundation

enum UsageFailureKind: String {
    case connection
    case timeout
    case signIn = "sign_in"
    case compatibility
    case cliMissing = "cli_missing"
    case unknown

    var title: String {
        switch self {
        case .connection: return "Offline"
        case .signIn: return "Sign in"
        case .compatibility: return "App changed"
        case .cliMissing: return "Not found"
        case .timeout, .unknown: return "Retrying"
        }
    }

    var advice: String {
        switch self {
        case .connection: return "Check your connection"
        case .signIn: return "Sign in to ChatGPT"
        case .compatibility: return "Check for a Gauge update"
        case .cliMissing: return "Open or reinstall ChatGPT"
        case .timeout, .unknown: return "Reconnecting to ChatGPT"
        }
    }
}

struct GaugeReadingPresentation {
    let showsQuota: Bool
    let isStale: Bool
    let title: String
    let detail: String

    init(hasReading: Bool, age: TimeInterval?, maximumAge: TimeInterval,
         failure: UsageFailureKind?, isRefreshing: Bool) {
        showsQuota = hasReading && age.map { $0 >= 0 && $0 < maximumAge } == true
        isStale = showsQuota && failure != nil
        if let failure {
            title = failure.title
            detail = failure.advice
        } else if isRefreshing {
            title = "Refreshing"
            detail = "Checking usage"
        } else if showsQuota {
            title = "Live"
            detail = "Current"
        } else {
            title = "Unavailable"
            detail = "Waiting for live usage"
        }
    }
}

struct GaugeRefreshPolicy {
    private(set) var lastAttemptAt: Date?
    private(set) var retryAt: Date?
    private(set) var failureCount = 0
    let freshnessInterval: TimeInterval = 60

    func canStart(at now: Date, force: Bool, installationChanged: Bool) -> Bool {
        if force || installationChanged { return true }
        if let retryAt, now < retryAt { return false }
        return lastAttemptAt.map { now.timeIntervalSince($0) >= freshnessInterval } ?? true
    }

    mutating func started(at now: Date) {
        lastAttemptAt = now
    }

    mutating func succeeded() {
        failureCount = 0
        retryAt = nil
    }

    mutating func failed(at now: Date, initialDelay: TimeInterval) {
        failureCount = min(failureCount + 1, 10)
        let delay = min(initialDelay * pow(2, Double(failureCount - 1)), 900)
        retryAt = now.addingTimeInterval(delay)
    }

    func retryDelay(at now: Date) -> TimeInterval? {
        retryAt.map { max(1, $0.timeIntervalSince(now)) }
    }

    func pollingInterval(base: TimeInterval, idleSeconds: TimeInterval) -> TimeInterval {
        // Keep low-quota polling responsive even while the user is away.
        base >= 300 && idleSeconds >= 600 ? max(base, 600) : base
    }
}

enum CodexCLIResolver {
    private struct Package: Decodable {
        let entrypoint: String
    }

    private static let fallbackSuffixes = [
        "Contents/Resources/codex-cli/bin/codex",
        "Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex",
        "Contents/Resources/codex",
    ]

    static func find(in appURLs: [URL]) -> String? {
        for appURL in appURLs {
            let packageURL = appURL.appendingPathComponent("Contents/Resources/codex-cli")
            let manifestURL = packageURL.appendingPathComponent("codex-package.json")
            if let data = try? Data(contentsOf: manifestURL),
               let package = try? JSONDecoder().decode(Package.self, from: data),
               let candidate = packagedExecutable(package.entrypoint, root: packageURL),
               isExecutable(candidate) {
                return candidate.path
            }
            for suffix in fallbackSuffixes {
                let candidate = appURL.appendingPathComponent(suffix)
                if isExecutable(candidate) { return candidate.path }
            }
        }
        return nil
    }

    private static func packagedExecutable(_ entrypoint: String, root: URL) -> URL? {
        guard !entrypoint.isEmpty, !entrypoint.hasPrefix("/"),
              !entrypoint.split(separator: "/").contains("..") else { return nil }
        let resolvedRoot = root.resolvingSymlinksInPath().standardizedFileURL
        let candidate = resolvedRoot.appendingPathComponent(entrypoint)
            .resolvingSymlinksInPath().standardizedFileURL
        guard candidate.path.hasPrefix(resolvedRoot.path + "/") else { return nil }
        return candidate
    }

    private static func isExecutable(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
            && !isDirectory.boolValue && FileManager.default.isExecutableFile(atPath: url.path)
    }

    static func fingerprint(appURLs: [URL], executable: String?) -> String {
        var paths = appURLs.flatMap {
            [$0.appendingPathComponent("Contents/Info.plist").path,
             $0.appendingPathComponent("Contents/Resources/codex-cli/codex-package.json").path]
        }
        if let executable { paths.append(executable) }
        return paths.map { path in
            let attributes = try? FileManager.default.attributesOfItem(atPath: path)
            let date = (attributes?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
            let size = (attributes?[.size] as? NSNumber)?.uint64Value ?? 0
            return "\(path):\(date):\(size)"
        }.joined(separator: "|")
    }
}
