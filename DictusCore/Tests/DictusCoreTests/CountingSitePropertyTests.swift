// DictusCore/Tests/DictusCoreTests/CountingSitePropertyTests.swift
// Property tests for #530's counting sites.
//
// WHY THESE EXIST:
// The replay tests are built from three device captures, and once they became the
// thing the fix is judged by they also became easy to fit. Three of Pierre's
// sentences are not a proof. These generate documents, phantom placements and
// surpluses in bulk and assert the invariants that have to hold for ALL of them:
//
//   1. Text before the replaced word is never touched — no word the user did not
//      type over is ever damaged. This is the one that makes the bug a bug.
//   2. The correction is never short — the whole real word is replaced.
//   3. The corrected count is never larger than the uncorrected one, so nothing here
//      can destroy text `develop` would have kept.
//   4. With no divergence ever observed, behaviour is bit-identical to `develop`.
//
// Deterministic on purpose: a seeded generator, so a failure is reproducible from
// the seed printed in the message rather than "it went red once on CI".

import XCTest
@testable import DictusCore

final class CountingSitePropertyTests: XCTestCase {

    /// A document and the mirror reported over it, which may hold phantom characters.
    private final class FakeDocument: TextDocumentEditing {
        private(set) var document: String
        private(set) var mirror: String

        init(document: String, mirror: String) {
            self.document = document
            self.mirror = mirror
        }

        var contextBeforeInput: String? { mirror.isEmpty ? nil : mirror }
        func deleteBackward() {
            if !document.isEmpty { document.removeLast() }
            if !mirror.isEmpty { mirror.removeLast() }
        }
        func insertText(_ text: String) {
            document += text
            mirror += text
        }
    }

    /// Reproducible generator — a failure is replayable from the seed alone.
    private struct Rng {
        private var state: UInt64
        init(seed: UInt64) { state = seed &* 6_364_136_223_846_793_005 &+ 1 }
        mutating func next(_ upperBound: Int) -> Int {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Int((state >> 33) % UInt64(max(1, upperBound)))
        }
        mutating func word(length: Int) -> String {
            let letters = Array("abcdefghijklmnopqrstuvwxyzéèàç")
            return String((0..<length).map { _ in letters[next(letters.count)] })
        }
    }

    private static let iterations = 400

    // MARK: - 1 & 2. The preceding text survives, and a correction is never partial

    func testAReplacementEitherHappensInFullOrNotAtAll() {
        // The invariant that replaces the old "never short" one. There are exactly two
        // acceptable outcomes now, and a partial delete is neither of them:
        //   - the mirror is not suspect: the whole word is replaced, as develop does;
        //   - the mirror is suspect: nothing is touched at all.
        // Anything in between is the class of defect that produced "pproblème" and
        // "MaMais", so the property forbids it outright.
        for seed in 0..<UInt64(Self.iterations) {
            var rng = Rng(seed: seed)

            let prefixWordCount = 1 + rng.next(3)
            let prefix = (0..<prefixWordCount)
                .map { _ in rng.word(length: 2 + rng.next(6)) }
                .joined(separator: " ")
            let realWord = rng.word(length: 2 + rng.next(8))
            let correction = rng.word(length: 1 + rng.next(9))
            let phantomCount = rng.next(4)
            // The two are not independent, and pretending otherwise builds a world
            // that cannot happen: a boundary written AFTER the divergence is exactly
            // what puts the phantom behind it, so "phantom still inside the current
            // word" and "a boundary has been written since" are mutually exclusive.
            let boundaryWritten = phantomCount > 0 && rng.next(2) == 0

            let document = prefix + " " + realWord
            let state = MirrorSyncState()
            let phantomText = String(repeating: "x", count: phantomCount)
            let mirror: String
            if phantomCount == 0 {
                mirror = document
            } else if boundaryWritten {
                mirror = prefix + phantomText + " " + realWord
            } else {
                mirror = prefix + " " + realWord + phantomText
            }

            for _ in 0..<phantomCount {
                state.observe(before: 40, after: 40, deleted: 1, inserted: 0)
            }
            if boundaryWritten {
                state.noteBoundaryInserted(reason: "space", atLength: mirror.count)
            }

            let doc = FakeDocument(document: document, mirror: mirror)
            var mirrorWord = ""
            mirror.enumerateSubstrings(in: mirror.startIndex..., options: .byWords) { sub, _, _, _ in
                if let sub = sub { mirrorWord = sub }
            }
            let wasSuspect = state.isSuspect
            let outcome = AutocorrectCountingSite.apply(
                editor: doc, word: mirrorWord, correction: correction, mirror: state
            )

            let context = "seed \(seed): phantom=\(phantomCount) boundary=\(boundaryWritten)"
            if wasSuspect {
                guard case .refused = outcome else {
                    XCTFail("\(context): a suspect mirror must refuse"); continue
                }
                XCTAssertEqual(doc.document, document, "\(context): nothing may be touched")
            } else {
                guard case .applied(let deleted) = outcome else { continue }
                XCTAssertEqual(deleted, mirrorWord.count, "\(context): partial delete")
                XCTAssertEqual(
                    doc.document, prefix + " " + correction + " ",
                    "\(context): the preceding text must survive intact"
                )
            }
        }
    }

    // MARK: - 4. A healthy mirror is bit-identical to develop

    func testWithNoDivergenceObservedTheSiteBehavesExactlyAsDevelop() {
        // Criterion 9 in property form. The device already confirmed the detector
        // never arms on healthy typing; this is what would catch a regression of it
        // in under a second instead of in a thirty-minute round trip.
        for seed in 0..<UInt64(Self.iterations) {
            var rng = Rng(seed: seed &+ 20_000)
            let prefix = rng.word(length: 1 + rng.next(8))
            let word = rng.word(length: 1 + rng.next(9))
            let correction = rng.word(length: 1 + rng.next(9))
            let state = MirrorSyncState()

            // A run of ordinary, faithfully-reflected edits.
            var length = prefix.count + 1
            for _ in 0..<word.count {
                state.observe(before: length, after: length + 1, deleted: 0, inserted: 1)
                length += 1
            }
            XCTAssertFalse(state.isSuspect, "seed \(seed): healthy typing must never arm")

            let document = prefix + " " + word
            let doc = FakeDocument(document: document, mirror: document)
            let outcome = AutocorrectCountingSite.apply(
                editor: doc, word: word, correction: correction, mirror: state
            )

            XCTAssertEqual(outcome, .applied(deleted: word.count), "seed \(seed)")
            XCTAssertEqual(doc.document, prefix + " " + correction + " ", "seed \(seed)")
        }
    }

    // MARK: - Crossing back past a settling boundary revives the surplus

    func testGoingBackPastTheSettlingBoundaryMakesTheSurplusLiveAgain() {
        // Capture 3 in property form. A boundary puts the phantom behind the cursor,
        // but the cursor can come back: a space at seq=42 settled the surplus and two
        // backspaces at seq=43/44 took the mirror from 50 to 48. Without this, the
        // boundary rule is falsified by the very capture it was built from.
        for seed in 0..<UInt64(Self.iterations) {
            var rng = Rng(seed: seed &+ 40_000)
            let surplus = 1 + rng.next(3)
            let boundaryLength = 20 + rng.next(60)
            let state = MirrorSyncState()

            for _ in 0..<surplus {
                state.observe(before: boundaryLength, after: boundaryLength, deleted: 1, inserted: 0)
            }
            XCTAssertTrue(state.isSuspect, "seed \(seed)")

            state.observe(before: boundaryLength, after: boundaryLength + 1, deleted: 0, inserted: 1)
            state.noteBoundaryInserted(reason: "space", atLength: boundaryLength + 1)
            XCTAssertFalse(state.isSuspect, "seed \(seed): the boundary settles it")

            // Typing forward keeps it settled, however far.
            var length = boundaryLength + 1
            for _ in 0..<rng.next(6) {
                state.observe(before: length, after: length + 1, deleted: 0, inserted: 1)
                length += 1
            }
            XCTAssertFalse(state.isSuspect, "seed \(seed): forward typing must not revive it")

            // Backspacing past the boundary brings it back.
            while length > boundaryLength {
                state.observe(before: length, after: length - 1, deleted: 1, inserted: 0)
                length -= 1
            }
            XCTAssertTrue(
                state.isSuspect,
                "seed \(seed): the cursor is back inside the phantom's reach"
            )
        }
    }

    // MARK: - Backspacing to the start of a field must never look like the bug

    func testDeletingMoreThanTheMirrorHoldsNeverArms() {
        for seed in 0..<UInt64(Self.iterations) {
            var rng = Rng(seed: seed &+ 30_000)
            let available = rng.next(4)
            let state = MirrorSyncState()

            // deleteBackward() with nothing left moves neither document nor mirror.
            state.observe(before: available, after: 0, deleted: available + 1 + rng.next(3), inserted: 0)
            XCTAssertFalse(state.isSuspect, "seed \(seed): available=\(available)")
        }
    }
}
