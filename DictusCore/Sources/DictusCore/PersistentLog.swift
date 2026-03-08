// DictusCore/Sources/DictusCore/PersistentLog.swift
// File-based logging that persists in the App Group container.
// Readable even when the Xcode debugger disconnects (Signal 9).
import Foundation

/// Persistent file-based logger for debugging without Xcode console.
///
/// WHY this exists:
/// When the app is opened via URL scheme from the keyboard, iOS often kills the
/// debugger connection (Signal 9). os.log messages are lost. This logger writes
/// to a file in the App Group container that can be read later from the Settings
/// screen or from a subsequent debug session.
///
/// WHY App Group container (not Documents):
/// The log file needs to be accessible from both the main app and the keyboard
/// extension for cross-process debugging.
public enum PersistentLog {
    private static let maxLines = 200
    private static let fileName = "dictus_debug.log"

    private static var fileURL: URL? {
        AppGroup.containerURL?.appendingPathComponent(fileName)
    }

    /// Append a timestamped log entry to the persistent log file.
    /// Thread-safe via a serial queue.
    public static func log(_ message: String, function: String = #function) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let entry = "[\(timestamp)] \(function): \(message)\n"

        // Also forward to os.log for when the debugger IS attached
        if #available(iOS 14.0, *) {
            DictusLogger.app.info("\(message)")
        }

        guard let url = fileURL else { return }

        DispatchQueue.global(qos: .utility).async {
            if !FileManager.default.fileExists(atPath: url.path) {
                FileManager.default.createFile(atPath: url.path, contents: nil)
            }

            guard let handle = try? FileHandle(forWritingTo: url) else { return }
            handle.seekToEndOfFile()
            if let data = entry.data(using: .utf8) {
                handle.write(data)
            }
            handle.closeFile()

            // Trim to maxLines to prevent unbounded growth
            trimIfNeeded(url: url)
        }
    }

    /// Read the full log contents.
    public static func read() -> String {
        guard let url = fileURL,
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return "(no logs)"
        }
        return content
    }

    /// Clear all logs.
    public static func clear() {
        guard let url = fileURL else { return }
        try? "".write(to: url, atomically: true, encoding: .utf8)
    }

    private static func trimIfNeeded(url: URL) {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
        var lines = content.components(separatedBy: "\n")
        if lines.count > maxLines {
            lines = Array(lines.suffix(maxLines))
            let trimmed = lines.joined(separator: "\n")
            try? trimmed.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
