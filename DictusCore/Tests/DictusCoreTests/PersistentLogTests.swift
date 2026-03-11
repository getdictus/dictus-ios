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

    // MARK: - Rotation

    func testMaxLinesIs500() {
        XCTAssertEqual(PersistentLog.testableMaxLines, 500)
    }

    func testTrimKeepsExactly500Lines() {
        // Write 510 lines
        var lines = (1...510).map { "line \($0)" }
        let content = lines.joined(separator: "\n") + "\n"
        try? content.write(to: tempFileURL, atomically: true, encoding: .utf8)

        PersistentLog.trimForTesting(url: tempFileURL)

        let trimmed = (try? String(contentsOf: tempFileURL, encoding: .utf8)) ?? ""
        let resultLines = trimmed.components(separatedBy: "\n").filter { !$0.isEmpty }
        XCTAssertEqual(resultLines.count, 500)
        // Should keep the LAST 500 lines (11 through 510)
        XCTAssertTrue(resultLines.first?.contains("line 11") ?? false,
                      "First line should be 'line 11', got: \(resultLines.first ?? "nil")")
        XCTAssertTrue(resultLines.last?.contains("line 510") ?? false,
                      "Last line should be 'line 510', got: \(resultLines.last ?? "nil")")
    }

    func testNoTrimWhenUnder500Lines() {
        let content = (1...100).map { "line \($0)" }.joined(separator: "\n") + "\n"
        try? content.write(to: tempFileURL, atomically: true, encoding: .utf8)

        PersistentLog.trimForTesting(url: tempFileURL)

        let result = (try? String(contentsOf: tempFileURL, encoding: .utf8)) ?? ""
        let resultLines = result.components(separatedBy: "\n").filter { !$0.isEmpty }
        XCTAssertEqual(resultLines.count, 100)
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
