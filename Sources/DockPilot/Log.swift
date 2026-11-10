import Foundation

/// Lightweight file logger for diagnosing behavior when the app is launched by
/// Finder / launchd (where stderr is not attached to a terminal).
///
/// Enabled only when the sentinel file `/tmp/dockpilot.debug` exists; writes to
/// `/tmp/dockpilot.log`. No-op otherwise, so it is safe in release builds.
enum Log {
    static let enabled = FileManager.default.fileExists(atPath: "/tmp/dockpilot.debug")
    private static let url = URL(fileURLWithPath: "/tmp/dockpilot.log")

    static func write(_ message: String) {
        guard enabled else { return }
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: url)
        }
    }
}
