// DictusCore/Tests/DictusCoreTests/DictationTallyCallSiteTests.swift
// Where the dictation tally is written, checked against the source that writes it (#726).
//
// WHY this suite reaches across targets: what the tally promises (every user counts, a
// cancelled dictation does not, a shared voice note never does) is decided at its call
// site in `DictationCoordinator` and by `VoiceNoteProcessor` staying out of it. Both live in DictusApp, which
// has no test bundle, so a later `if proStatus.isPro` around a call would keep every
// behavioural test green. Reading the source catches it, the pattern
// `CallGuardCallSiteTests` uses for the same reason.
import XCTest
@testable import DictusCore

final class DictationTallyCallSiteTests: XCTestCase {

    private static let coordinatorPath = "DictusApp/DictationCoordinator.swift"
    private static let voiceNotesPath = "DictusApp/VoiceNotes/VoiceNoteProcessor.swift"
    private static let tallyPath = "DictusCore/Sources/DictusCore/Stats/DictationTally.swift"
    private static let recordCall = "DictationTally.record("

    /// Anything that would make counting depend on Pro, the trial or the paywall flag.
    private static let gates = ["isPro", "proActive", "paywallVisible", "ProTrialUsage", "isCounting", "trial"]

    // MARK: - Dictations

    func testTheCoordinatorRecordsOnceAndOnlyForTheLiveSession() throws {
        let lines = try codeLines(at: Self.coordinatorPath)
        let calls = lines.indices.filter { lines[$0].contains(Self.recordCall) }
        XCTAssertEqual(calls.count, 1, "one call serves the in-app and the keyboard dictation")
        let call = try XCTUnwrap(calls.first)
        let condition = try XCTUnwrap(lines[..<call].last { !$0.trimmingCharacters(in: .whitespaces).isEmpty })

        XCTAssertTrue(condition.contains("Task.isCancelled"),
                      "a dictation cancelled during transcription would be counted")
        XCTAssertTrue(condition.contains("sessionGeneration.mayReport(from: session)"),
                      "an abandoned session's late transcript would be counted")
        for gate in Self.gates {
            XCTAssertFalse(condition.contains(gate), "counting is gated on \(gate); #726 counts every user")
        }
    }

    /// Counted before the tails split, so both origins count, and before the keyboard
    /// tail's own `mayReport`, which logs the drop.
    func testTheCoordinatorRecordsBeforeTheOriginsSplit() throws {
        let lines = try codeLines(at: Self.coordinatorPath)
        let call = try XCTUnwrap(lines.firstIndex { $0.contains(Self.recordCall) })
        let split = try XCTUnwrap(lines[call...].firstIndex { $0.contains("switch dictationOrigin") },
                                  "the origin switch no longer follows the count")
        XCTAssertLessThan(call, split)
    }

    // MARK: - Shared voice notes are not counted (#726, decided 2026-10-21)

    /// A shared voice note is often someone else's voice: its words were not dictated
    /// by the user. The voice note queue must not write the tally.
    func testTheVoiceNoteQueueDoesNotRecord() throws {
        let lines = try codeLines(at: Self.voiceNotesPath)
        XCTAssertFalse(lines.contains { $0.contains("DictationTally") },
                       "VoiceNoteProcessor writes the tally; shared voice notes are excluded from the recap")
    }

    /// The voice note's chunks transcribe through the coordinator too, by their own
    /// entry point. That entry must not reach the dictation's count.
    func testTheVoiceNoteChunkEntryDoesNotRecord() throws {
        let source = try codeLines(at: Self.coordinatorPath).joined(separator: "\n")
        let start = try XCTUnwrap(source.range(of: "func transcribeVoiceNoteChunk(")?.lowerBound,
                                  "the coordinator no longer declares transcribeVoiceNoteChunk")
        let end = try XCTUnwrap(source.range(of: "\n    }\n", range: start..<source.endIndex)?.upperBound)
        XCTAssertFalse(source[start..<end].contains(Self.recordCall),
                       "a voice note chunk is counted as a dictation")
    }

    /// Nothing else in the app targets writes the tally: the coordinator's one call is
    /// the only way in, so only dictations count.
    func testTheCoordinatorIsTheOnlyWriter() throws {
        let root = repoRoot()
        var writers: [String] = []
        for target in ["DictusApp", "DictusKeyboard", "DictusShare", "DictusWidgets"] {
            let directory = root.appendingPathComponent(target)
            guard let files = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil) else { continue }
            for case let url as URL in files where url.pathExtension == "swift" {
                let path = String(url.path.dropFirst(root.path.count + 1))
                if try codeLines(at: path).contains(where: { $0.contains(Self.recordCall) }) {
                    writers.append(path)
                }
            }
        }
        XCTAssertEqual(writers, [Self.coordinatorPath])
    }

    // MARK: - The entry the coordinator calls

    func testTheTallyEntryReadsNoGate() throws {
        let source = try codeLines(at: Self.tallyPath).joined(separator: "\n")
        let start = try XCTUnwrap(source.range(of: "public static func record(_ text: String")?.lowerBound)
        let end = try XCTUnwrap(source.range(of: "static func record(words:", range: start..<source.endIndex)?.lowerBound)
        let body = source[start..<end]
        for gate in Self.gates {
            XCTAssertFalse(body.contains(gate), "the tally's entry reads \(gate); #726 counts every user")
        }
    }

    // MARK: - Reading the repo

    /// The file's lines, with comment lines removed: the comments at these call sites
    /// name the very things being checked.
    private func codeLines(at path: String) throws -> [String] {
        let url = repoRoot().appendingPathComponent(path)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("Source not found at \(url.path)")
            throw CocoaError(.fileNoSuchFile)
        }
        return text.split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
    }

    private func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // DictusCoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // DictusCore
            .deletingLastPathComponent()  // repo root
    }
}
