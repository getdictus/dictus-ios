// DictusCore/Tests/DictusCoreTests/PersistentLogTests.swift
// Tests for the evolved PersistentLog with structured API and rotation.
import XCTest
@testable import DictusCore

final class PersistentLogTests: XCTestCase {

    private var tempFileURL: URL!

    override func setUp() {
        super.setUp()
        // Use a temp file for isolation -- avoids polluting App Group
        tempFileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_dictus_\(UUID().uuidString).log")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempFileURL)
        super.tearDown()
    }

    // MARK: - Structured logging

    func testLogEventWritesFormattedOutput() {
        let event = LogEvent.dictationStarted(fromURL: true, appState: "active", engineRunning: false)
        PersistentLog.appendForTesting(event.formatted() + "\n", to: tempFileURL)

        let content = PersistentLog.readForTesting(from: tempFileURL)
        XCTAssertTrue(content.contains("dictationStarted"))
        XCTAssertTrue(content.contains("fromURL=true"))
        XCTAssertTrue(content.contains("[dictation]"))
        XCTAssertTrue(content.contains("INFO"))
    }

    func testLogEventWritesMultipleEntries() {
        PersistentLog.appendForTesting(
            LogEvent.audioEngineStarted.formatted() + "\n", to: tempFileURL)
        PersistentLog.appendForTesting(
            LogEvent.audioEngineStopped.formatted() + "\n", to: tempFileURL)

        let content = PersistentLog.readForTesting(from: tempFileURL)
        XCTAssertTrue(content.contains("audioEngineStarted"))
        XCTAssertTrue(content.contains("audioEngineStopped"))
    }

    // MARK: - Size-based trim

    func testMaxFileSizeIs200KB() {
        XCTAssertEqual(PersistentLog.testableMaxFileSize, 200_000)
    }

    func testShouldTrimReturnsFalseUnderLimit() {
        // Write ~100KB (well under 200KB limit)
        let smallContent = String(repeating: "A", count: 100_000) + "\n"
        try? smallContent.write(to: tempFileURL, atomically: true, encoding: .utf8)

        XCTAssertFalse(PersistentLog.shouldTrimForTesting(url: tempFileURL))
    }

    func testShouldTrimReturnsTrueOverLimit() {
        // Write ~250KB (over 200KB limit)
        let largeContent = String(repeating: "B", count: 250_000) + "\n"
        try? largeContent.write(to: tempFileURL, atomically: true, encoding: .utf8)

        XCTAssertTrue(PersistentLog.shouldTrimForTesting(url: tempFileURL))
    }

    func testTrimBySizeKeepsSuffix() {
        // Write ~300KB of numbered lines so we can verify the LAST ~200KB is kept
        var lines: [String] = []
        for i in 1...3000 {
            lines.append("line \(i) " + String(repeating: "X", count: 90))  // ~100 bytes each
        }
        let content = lines.joined(separator: "\n") + "\n"
        try? content.write(to: tempFileURL, atomically: true, encoding: .utf8)

        PersistentLog.trimBySizeForTesting(url: tempFileURL)

        let trimmed = (try? String(contentsOf: tempFileURL, encoding: .utf8)) ?? ""
        let resultSize = trimmed.utf8.count
        // Should be roughly maxFileSize (200KB), minus partial first line
        XCTAssertLessThanOrEqual(resultSize, 200_100, "Trimmed file should be ~200KB or less")
        XCTAssertGreaterThan(resultSize, 100_000, "Trimmed file should retain significant content")
        // Last line should be the very last line we wrote
        XCTAssertTrue(trimmed.contains("line 3000"), "Should keep the most recent (last) lines")
        // First lines should be gone
        XCTAssertFalse(trimmed.contains("line 1 "), "Should have removed the oldest lines")
    }

    func testNoTrimWhenUnderSizeLimit() {
        let content = (1...100).map { "line \($0)" }.joined(separator: "\n") + "\n"
        try? content.write(to: tempFileURL, atomically: true, encoding: .utf8)

        PersistentLog.trimBySizeForTesting(url: tempFileURL)

        let result = (try? String(contentsOf: tempFileURL, encoding: .utf8)) ?? ""
        let resultLines = result.components(separatedBy: "\n").filter { !$0.isEmpty }
        XCTAssertEqual(resultLines.count, 100)
    }

    // MARK: - Date-based retention

    func testPruneOldEntriesRemovesOldLines() {
        let formatter = ISO8601DateFormatter()
        let oldDate = Date().addingTimeInterval(-8 * 24 * 3600)  // 8 days ago
        let recentDate = Date().addingTimeInterval(-1 * 24 * 3600)  // 1 day ago
        let oldTimestamp = formatter.string(from: oldDate)
        let recentTimestamp = formatter.string(from: recentDate)

        let content = """
        [\(oldTimestamp)] INFO   [lifecycle] <APP> appLaunched old entry
        [\(recentTimestamp)] INFO   [lifecycle] <APP> appLaunched recent entry
        """
        try? content.write(to: tempFileURL, atomically: true, encoding: .utf8)

        // Prune with 7-day cutoff
        let cutoff = Date().addingTimeInterval(-7 * 24 * 3600)
        PersistentLog.pruneOldEntriesForTesting(url: tempFileURL, cutoffDate: cutoff)

        let result = (try? String(contentsOf: tempFileURL, encoding: .utf8)) ?? ""
        XCTAssertFalse(result.contains("old entry"), "Old entries should be removed")
        XCTAssertTrue(result.contains("recent entry"), "Recent entries should be kept")
    }

    func testPruneOldEntriesKeepsRecentLines() {
        let formatter = ISO8601DateFormatter()
        let recent1 = Date().addingTimeInterval(-1 * 24 * 3600)
        let recent2 = Date().addingTimeInterval(-3 * 24 * 3600)
        let ts1 = formatter.string(from: recent1)
        let ts2 = formatter.string(from: recent2)

        let content = """
        [\(ts1)] INFO   [lifecycle] <APP> appLaunched entry1
        [\(ts2)] INFO   [lifecycle] <APP> appLaunched entry2
        """
        try? content.write(to: tempFileURL, atomically: true, encoding: .utf8)

        let cutoff = Date().addingTimeInterval(-7 * 24 * 3600)
        PersistentLog.pruneOldEntriesForTesting(url: tempFileURL, cutoffDate: cutoff)

        let result = (try? String(contentsOf: tempFileURL, encoding: .utf8)) ?? ""
        XCTAssertTrue(result.contains("entry1"), "Recent entry1 should be kept")
        XCTAssertTrue(result.contains("entry2"), "Recent entry2 should be kept")
    }

    func testPruneOldEntriesKeepsUnparseableLines() {
        let formatter = ISO8601DateFormatter()
        let oldDate = Date().addingTimeInterval(-8 * 24 * 3600)
        let oldTimestamp = formatter.string(from: oldDate)

        let content = """
        [\(oldTimestamp)] INFO   [lifecycle] <APP> appLaunched old entry
        This line has no timestamp format
        Another unparseable line
        """
        try? content.write(to: tempFileURL, atomically: true, encoding: .utf8)

        let cutoff = Date().addingTimeInterval(-7 * 24 * 3600)
        PersistentLog.pruneOldEntriesForTesting(url: tempFileURL, cutoffDate: cutoff)

        let result = (try? String(contentsOf: tempFileURL, encoding: .utf8)) ?? ""
        XCTAssertFalse(result.contains("old entry"), "Old entry should be removed")
        XCTAssertTrue(result.contains("This line has no timestamp"), "Unparseable lines should be kept")
        XCTAssertTrue(result.contains("Another unparseable"), "Unparseable lines should be kept")
    }

    // MARK: - Export header

    func testExportHeaderFormat() {
        // Use the testable helper with injected values
        let header = PersistentLog.buildExportHeader(
            iosVersion: "18.2",
            appVersion: "1.2",
            buildNumber: "42",
            deviceModel: "iPhone",
            activeModel: "base"
        )

        XCTAssertTrue(header.hasPrefix("Dictus Debug Log\n"))
        XCTAssertTrue(header.contains("iOS 18.2"))
        XCTAssertTrue(header.contains("App 1.2 (42)"))
        XCTAssertTrue(header.contains("iPhone"))
        XCTAssertTrue(header.contains("Model: base"))
        XCTAssertTrue(header.contains("---"))
    }

    func testExportHeaderWithMissingValues() {
        let header = PersistentLog.buildExportHeader(
            iosVersion: "?",
            appVersion: "?",
            buildNumber: "?",
            deviceModel: "?",
            activeModel: "none"
        )

        XCTAssertTrue(header.contains("Model: none"))
    }

    // MARK: - Clear

    func testClearRemovesContent() {
        let content = "some log content\n"
        try? content.write(to: tempFileURL, atomically: true, encoding: .utf8)

        PersistentLog.clearForTesting(url: tempFileURL)

        let result = (try? String(contentsOf: tempFileURL, encoding: .utf8)) ?? ""
        XCTAssertTrue(result.isEmpty)
    }
}
