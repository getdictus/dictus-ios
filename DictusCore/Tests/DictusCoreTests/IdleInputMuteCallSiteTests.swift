// DictusCore/Tests/DictusCoreTests/IdleInputMuteCallSiteTests.swift
// Where the warm engine's input is muted and unmuted (#430), checked against the source.
//
// WHY this suite reads the source: the orange indicator is AVFoundation state on a device,
// and `UnifiedAudioEngine` is `@MainActor`, owns a live `AVAudioEngine` and lives in
// DictusApp, which has no test bundle. What can regress is the call sites: a dictation
// that starts without unmuting records silence, and a stop that forgets to mute brings
// the indicator back for the whole warm window. Same pattern as `CallGuardCallSiteTests`.
import XCTest
@testable import DictusCore

final class IdleInputMuteCallSiteTests: XCTestCase {

    private static let enginePath = "DictusApp/Audio/UnifiedAudioEngine.swift"

    /// Every dictation ends here, cancel and the idle invariant's teardown included.
    func testCollectSamplesMutesTheIdleInput() throws {
        let body = try body(of: "func collectSamples() -> [Float] {", in: Self.enginePath)
        XCTAssertTrue(body.contains("muteInputIfIdle(context: \"collectSamples\")"),
                      "collectSamples() no longer mutes the input it leaves running")
    }

    /// A warm-up opens the input with nobody recording, on launch and on every foreground.
    func testWarmUpMutesBothWaysOut() throws {
        let body = try body(of: "func warmUp() throws {", in: Self.enginePath)
        XCTAssertTrue(body.contains("muteInputIfIdle(context: \"warmUp\")"),
                      "a cold warm-up no longer mutes the input it starts")
        XCTAssertTrue(body.contains("muteInputIfIdle(context: \"warmUp-alreadyRunning\")"),
                      "warmUp() on a running engine no longer mutes it")
    }

    /// The unmute must be a `try` that runs before the start can record: a muted start
    /// captures silence, and a throw after `cancelIdleRelease()` would strand the engine.
    func testStartRecordingUnmutesBeforeItRecords() throws {
        let body = try body(of: "func startRecording() throws {", in: Self.enginePath)
        let unmute = "try setInputMuted(false, context: \"startRecording\")"
        let unmuteIndex = try XCTUnwrap(body.range(of: unmute)?.lowerBound,
                                        "startRecording() no longer unmutes the input")

        for statement in ["cancelIdleRelease()", "engine.isRunning", "isRecording = true"] {
            let index = try XCTUnwrap(body.range(of: statement)?.lowerBound,
                                      "startRecording() no longer contains \(statement)")
            XCTAssertLessThan(unmuteIndex, index,
                              "the unmute must run before \(statement) in startRecording()")
        }
    }

    /// The two full teardowns hand the process back unmuted.
    func testTeardownsUnmute() throws {
        let release = try body(of: "func releaseWarmState(reason: String) {", in: Self.enginePath)
        XCTAssertTrue(release.contains("setInputMuted(false"),
                      "releaseWarmState() no longer unmutes the input")

        let deactivate = try body(of: "func deactivateSession() {", in: Self.enginePath)
        XCTAssertTrue(deactivate.contains("setInputMuted(false"),
                      "deactivateSession() no longer unmutes the input")
    }

    /// Muting is only ever for a running engine with nobody recording.
    func testMuteIsGatedOnIdle() throws {
        let body = try body(of: "private func muteInputIfIdle(context: String) {", in: Self.enginePath)
        XCTAssertTrue(body.contains("engine.isRunning && !isRecording"),
                      "muteInputIfIdle() no longer checks that the engine is idle")
    }

    // MARK: - Reading the repo

    /// The text between a function's opening brace and its matching close, with comment
    /// lines removed, so a comment naming a call cannot satisfy an assertion about it.
    private func body(of signature: String,
                      in path: String,
                      file: StaticString = #filePath,
                      line: UInt = #line) throws -> String {
        let source = try source(at: path, file: file, line: line)
        guard let signatureRange = source.range(of: signature) else {
            XCTFail("\(path) no longer declares `\(signature)`", file: file, line: line)
            throw CocoaError(.fileNoSuchFile)
        }

        var depth = 1
        var index = signatureRange.upperBound
        while index < source.endIndex, depth > 0 {
            let character = source[index]
            if character == "{" { depth += 1 }
            if character == "}" { depth -= 1 }
            if depth == 0 { break }
            index = source.index(after: index)
        }
        return String(source[signatureRange.upperBound..<index])
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    private func source(at path: String,
                        file: StaticString = #filePath,
                        line: UInt = #line) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // DictusCoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // DictusCore
            .deletingLastPathComponent()  // repo root
        let url = root.appendingPathComponent(path)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("Source not found at \(url.path)", file: file, line: line)
            throw CocoaError(.fileNoSuchFile)
        }
        return text
    }
}
