import Darwin
import Foundation

func infoString(_ key: String, fallback: String) -> String {
    (Bundle.main.object(forInfoDictionaryKey: key) as? String) ?? fallback
}

func showDialog(_ message: String) {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    task.arguments = [
        "-e",
        "display dialog \"\(message)\" buttons {\"OK\"} default button \"OK\" with title \"Codex Gauge\""
    ]
    try? task.run()
}

let rootDir = infoString("ReplaceRootDir", fallback: FileManager.default.currentDirectoryPath)
let scriptPath = "\(rootDir)/script/replace_installed_app.sh"
let logURL = URL(fileURLWithPath: rootDir, isDirectory: true)
    .appendingPathComponent("native")
    .appendingPathComponent("build")
    .appendingPathComponent("CodexGauge-replace.log")

try? FileManager.default.createDirectory(at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true)
FileManager.default.createFile(atPath: logURL.path, contents: nil)

do {
    let log = try FileHandle(forWritingTo: logURL)
    defer { try? log.close() }

    let header = "Replacing Codex Gauge at \(Date())\nRoot: \(rootDir)\nScript: \(scriptPath)\n\n"
    if let data = header.data(using: .utf8) {
        try log.write(contentsOf: data)
    }

    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/bin/bash")
    task.arguments = [scriptPath]
    task.currentDirectoryURL = URL(fileURLWithPath: rootDir, isDirectory: true)
    task.standardOutput = log
    task.standardError = log

    try task.run()
    task.waitUntilExit()

    if task.terminationStatus == 0 {
        showDialog("Codex Gauge was replaced and relaunched. Log written to native/build/CodexGauge-replace.log.")
        exit(0)
    }

    showDialog("Codex Gauge replacement failed. Check native/build/CodexGauge-replace.log.")
    exit(task.terminationStatus)
} catch {
    let message = "Replacement helper failed before running the script: \(error)\n"
    if let data = message.data(using: .utf8),
       let log = try? FileHandle(forWritingTo: logURL) {
        try? log.write(contentsOf: data)
        try? log.close()
    }
    showDialog("Codex Gauge replacement failed. Check native/build/CodexGauge-replace.log.")
    exit(1)
}
