// DictusCore/Tests/DictusCoreTests/Vocabulary/VocabularyCorpusReplayTests.swift
// The #80 corpus replay, on every `swift test`.
//
// WHY this suite reaches out of the test bundle and into `docs/research/`: the same
// reason `PolishGuardrailCorpusReplayTests` does, in its own words — "a threshold
// whose evidence only exists in a command nobody runs is a threshold that drifts".
// `polish-harness vocabulary` prints these numbers, and it is a macOS executable
// that needs a human to run it. CI runs nothing in this repo, so a corpus that does
// not run here is a corpus nobody replays.
//
// It resolves the repo from `#filePath` rather than copying the corpus into test
// resources, following that suite and `DictationErrorCopyTests`: a copy would drift,
// and drift is the failure being checked for.
import XCTest
@testable import DictusCore

final class VocabularyCorpusReplayTests: XCTestCase {

    // MARK: - The replay

    /// **The acceptance criterion, executable.** Every committed case produces
    /// exactly the text it says it should, through the shipping matcher.
    func testEveryCaseProducesItsCommittedExpectation() throws {
        let corpus = try load()
        var wrong: [String] = []
        for item in corpus {
            let produced = VocabularyReplacer.apply(item.raw, entries: item.vocabulary)
            if produced != item.expected { wrong.append(item.label) }
        }
        XCTAssertEqual(wrong, [], "a case whose output changed is either a regression or a decision to record")
        XCTAssertGreaterThan(corpus.count, 15, "guard against a replay that passes on an empty corpus")
    }

    /// Idempotence, on the corpus rather than only on the unit cases: applying the
    /// pass twice must equal applying it once, including for the two cycle shapes the
    /// rule builder refuses to construct.
    func testTheCorpusIsIdempotent() throws {
        let notIdempotent = try load().filter { item in
            let once = VocabularyReplacer.apply(item.raw, entries: item.vocabulary)
            return VocabularyReplacer.apply(once, entries: item.vocabulary) != once
        }
        XCTAssertEqual(notIdempotent.map(\.label), [])
    }

    /// The device evidence must not quietly leave the file.
    ///
    /// The corpus was 14 constructed cases until #80's device test produced four
    /// `captured` ones, and constructed cases only prove the pass does what it was
    /// specified to do. Losing the captured ones would take the file back to
    /// measuring itself, with nothing on screen to say so.
    func testTheCapturedCasesAreStillThere() throws {
        let captured = try load().filter { $0.origin == "captured" }
        XCTAssertGreaterThanOrEqual(
            captured.count, 4,
            "the corpus is down to constructed cases; a capture session's evidence went missing"
        )
        for item in captured {
            XCTAssertFalse(
                item.note.isEmpty,
                "\(item.label) is captured but says nothing about the device, model and language it came from"
            )
        }
    }

    /// Every `origin` is one of the two the README defines. A typo here would let a
    /// constructed case pass itself off as evidence.
    func testEveryCaseDeclaresAKnownOrigin() throws {
        let unknown = try load().filter { $0.origin != "captured" && $0.origin != "constructed" }
        XCTAssertEqual(unknown.map(\.label), [])
    }

    /// The five cases #80 names its corpus must carry, asserted by the labels the
    /// file itself declares rather than by counting records.
    func testTheCorpusCoversWhatTheIssueAsksItTo() throws {
        let covered = Set(try load().flatMap(\.covers))
        for required in [
            "mangled technical term", "mid-sentence", "sentence start",
            "overlapping variants", "false positive", "non-spaced script"
        ] {
            XCTAssertTrue(covered.contains(required), "the corpus no longer covers: \(required)")
        }
    }

    // MARK: - Reading the corpus

    /// One replayable case. A structural subset of the harness's `VocabularyCase` —
    /// that type lives in an executable target this bundle cannot import, and
    /// duplicating six fields is cheaper than making the harness a library.
    private struct Case: Decodable {
        let source: String
        let fixture: String
        let origin: String
        let note: String
        let covers: [String]
        let entries: [Entry]
        let raw: String
        let expected: String

        struct Entry: Decodable {
            let term: String
            let variants: [String]
            let isEnabled: Bool?
        }

        var label: String { "\(source):\(fixture)" }

        /// The entries as the replacer receives them in production. An entry the
        /// model refuses to build would silently shrink the case to fewer rules than
        /// it declares, so it is a failure rather than a skip.
        var vocabulary: [VocabularyEntry] {
            entries.map {
                VocabularyEntry(term: $0.term, variants: $0.variants, isEnabled: $0.isEnabled ?? true)
                    ?? VocabularyEntry(term: "!invalid-entry-in-corpus")! // swiftlint:disable:this force_unwrapping
            }
        }
    }

    private func load(file: StaticString = #filePath, line: UInt = #line) throws -> [Case] {
        let url = repoRoot().appendingPathComponent("docs/research/80-vocabulary/corpus.json")
        let corpus = try JSONDecoder().decode([Case].self, from: Data(contentsOf: url))
        XCTAssertFalse(corpus.isEmpty, "no corpus found at \(url.path)", file: file, line: line)
        for item in corpus where item.vocabulary.contains(where: { $0.term.hasPrefix("!invalid") }) {
            XCTFail("\(item.label) declares an entry the model refuses", file: file, line: line)
        }
        return corpus
    }

    private func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // Vocabulary
            .deletingLastPathComponent()  // DictusCoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // DictusCore
            .deletingLastPathComponent()  // repo root
    }
}
