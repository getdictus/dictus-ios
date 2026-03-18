// DictusCore/Sources/DictusCore/PersistentLog.swift
// File-based structured logging that persists in the App Group container.
// Readable even when the Xcode debugger disconnects (Signal 9).
import Foundation
import os.log
#if canImport(UIKit)
import UIKit
#endif

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
///
/// WHY NSFileCoordinator:
/// Both DictusApp and DictusKeyboard write to the same log file. Without
/// coordination, concurrent writes corrupt the file. NSFileCoordinator
/// serializes cross-process access via the App Group.
public enum PersistentLog {

    /// Process source tag — set once at app/extension launch.
    /// WHY static var (not auto-detected): Bundle.main.bundleIdentifier is
    /// unreliable in keyboard extensions (can return the host app's ID).
    public static var source: String = "?"

    // MARK: - Constants

    static let maxLines = 1000
    private static let fileName = "dictus_debug.log"

    /// Serial queue for ordering writes within a single process.
    /// Cross-process safety is handled by NSFileCoordinator.
    private static let writeQueue = DispatchQueue(label: "com.pivi.dictus.persistentlog", qos: .utility)

    private static var fileURL: URL? {
        AppGroup.containerURL?.appendingPathComponent(fileName)
    }

    // MARK: - Public API (Structured)

    /// Log a structured event to the persistent file.
    /// This is the primary public API — callers pass typed LogEvent cases.
    public static func log(_ event: LogEvent) {
        let line = event.formatted() + "\n"

        // Forward to os.log for Xcode console visibility
        forwardToOSLog(event)

        guard let url = fileURL else { return }

        writeQueue.async {
            coordinatedAppend(line, to: url)
            coordinatedTrim(url: url)
        }
    }

    /// Read the full log contents.
    public static func read() -> String {
        guard let url = fileURL else { return "(no logs)" }
        return coordinatedRead(from: url)
    }

    /// Clear all logs.
    public static func clear() {
        guard let url = fileURL else { return }
        coordinatedWrite("", to: url)
    }

    /// Export log with device header for sharing.
    /// Returns header + full log content.
    #if canImport(UIKit)
    public static func exportContent() -> String {
        let iosVersion = UIDevice.current.systemVersion
        let deviceModel = UIDevice.current.model
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        let activeModel = AppGroup.defaults.string(forKey: SharedKeys.activeModel) ?? "none"

        let header = buildExportHeader(
            iosVersion: iosVersion,
            appVersion: appVersion,
            buildNumber: buildNumber,
            deviceModel: deviceModel,
            activeModel: activeModel
        )
        return header + read()
    }
    #endif

    /// Testable header builder — accepts injected values so tests don't need UIDevice.
    static func buildExportHeader(
        iosVersion: String,
        appVersion: String,
        buildNumber: String,
        deviceModel: String,
        activeModel: String
    ) -> String {
        "Dictus Debug Log\niOS \(iosVersion) | App \(appVersion) (\(buildNumber)) | \(deviceModel) | Model: \(activeModel)\n---\n"
    }

    // MARK: - Legacy API (Deprecated)

    /// Legacy free-text log method. Use `log(_ event: LogEvent)` instead.
    @available(*, deprecated, message: "Use log(_ event: LogEvent) instead")
    public static func log(_ message: String, function: String = #function) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let entry = "[\(timestamp)] \(function): \(message)\n"

        if #available(iOS 14.0, *) {
            DictusLogger.app.info("\(message, privacy: .public)")
        }

        guard let url = fileURL else { return }

        writeQueue.async {
            coordinatedAppend(entry, to: url)
            coordinatedTrim(url: url)
        }
    }

    // MARK: - NSFileCoordinator Helpers

    private static func coordinatedAppend(_ text: String, to url: URL) {
        let coordinator = NSFileCoordinator()
        var error: NSError?

        coordinator.coordinate(writingItemAt: url, options: .forMerging, error: &error) { coordURL in
            if !FileManager.default.fileExists(atPath: coordURL.path) {
                FileManager.default.createFile(atPath: coordURL.path, contents: nil)
            }
            guard let handle = try? FileHandle(forWritingTo: coordURL) else { return }
            handle.seekToEndOfFile()
            if let data = text.data(using: .utf8) {
                handle.write(data)
            }
            handle.closeFile()
        }
    }

    private static func coordinatedRead(from url: URL) -> String {
        let coordinator = NSFileCoordinator()
        var error: NSError?
        var result = "(no logs)"

        coordinator.coordinate(readingItemAt: url, options: [], error: &error) { coordURL in
            if let content = try? String(contentsOf: coordURL, encoding: .utf8) {
                result = content
            }
        }
        return result
    }

    private static func coordinatedWrite(_ text: String, to url: URL) {
        let coordinator = NSFileCoordinator()
        var error: NSError?

        coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &error) { coordURL in
            try? text.write(to: coordURL, atomically: true, encoding: .utf8)
        }
    }

    private static func coordinatedTrim(url: URL) {
        let coordinator = NSFileCoordinator()
        var error: NSError?

        coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &error) { coordURL in
            guard let content = try? String(contentsOf: coordURL, encoding: .utf8) else { return }
            var lines = content.components(separatedBy: "\n")
            if lines.count > maxLines {
                lines = Array(lines.suffix(maxLines))
                let trimmed = lines.joined(separator: "\n")
                try? trimmed.write(to: coordURL, atomically: true, encoding: .utf8)
            }
        }
    }

    // MARK: - os.log Forwarding

    private static func forwardToOSLog(_ event: LogEvent) {
        guard #available(iOS 14.0, *) else { return }

        let logger: Logger
        switch event.subsystem {
        case .dictation, .audio, .transcription, .model, .lifecycle:
            logger = DictusLogger.app
        case .keyboard:
            logger = DictusLogger.keyboard
        }

        // WHY privacy: .public — LogEvent is privacy-safe by design (no user text,
        // no keystrokes). Without .public, os.log masks ALL interpolated values as
        // <private> in the Xcode console, making debugging impossible.
        let msg = "\(event.name) \(event.message)"
        switch event.level {
        case .debug: logger.debug("\(msg, privacy: .public)")
        case .info: logger.info("\(msg, privacy: .public)")
        case .warning: logger.warning("\(msg, privacy: .public)")
        case .error: logger.error("\(msg, privacy: .public)")
        }
    }

    // MARK: - Test Helpers

    /// Append text to an arbitrary URL (for unit tests with temp files).
    static func appendForTesting(_ text: String, to url: URL) {
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        guard let handle = try? FileHandle(forWritingTo: url) else { return }
        handle.seekToEndOfFile()
        if let data = text.data(using: .utf8) {
            handle.write(data)
        }
        handle.closeFile()
    }

    /// Read from an arbitrary URL (for unit tests with temp files).
    static func readForTesting(from url: URL) -> String {
        (try? String(contentsOf: url, encoding: .utf8)) ?? "(no logs)"
    }

    /// Trim an arbitrary URL to maxLines (for unit tests).
    static func trimForTesting(url: URL) {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
        var lines = content.components(separatedBy: "\n")
        if lines.count > maxLines {
            lines = Array(lines.suffix(maxLines))
            let trimmed = lines.joined(separator: "\n")
            try? trimmed.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    /// Clear an arbitrary URL (for unit tests).
    static func clearForTesting(url: URL) {
        try? "".write(to: url, atomically: true, encoding: .utf8)
    }

    /// Expose maxLines for test assertions.
    static var testableMaxLines: Int { maxLines }
}
