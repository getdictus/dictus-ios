// DictusCore/Tests/DictusCoreTests/MirrorSurplusUnknowabilityTests.swift
// Why #530's surplus MAGNITUDE cannot be made correct (2026-09-12 decision).
//
// Three rounds each fixed a different way the surplus went wrong — latched, then
// settled-but-revivable, then spurious. This file is why a fourth rule would not
// have helped either: the correct delete count is not a function of anything a
// keyboard extension can observe.
//
// The proof is a pair of documents, BOTH measured on device, that produce an
// identical observable trace and need different answers:
//
//   A — capture 3. A host edit leaves the mirror stale; the keyboard's next delete
//       removes a character from the document and not from the mirror. The mirror
//       now carries a phantom inside the word. Correct count: word length minus one.
//   B — capture 6. A host edit repositions things; the keyboard's next delete
//       removes nothing from either side. No phantom exists. Correct count: the full
//       word length.
//
// In both the mirror reports the same text and the same lengths at every step, so
// every reading the extension can take is identical. Whatever number it computes is
// right for one and wrong for the other. That is not a gap in the rules — it is the
// absence of a function.

import XCTest
@testable import DictusCore

final class MirrorSurplusUnknowabilityTests: XCTestCase {

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

    /// The trace both scenarios produce: one keyboard delete the mirror did not
    /// reflect, immediately after a host-side change. Capture 6 shows all three of
    /// its armings taking exactly this shape (seq=275, seq=315, and 14:22:24).
    private func replayTheAmbiguousDelete(into state: MirrorSyncState, mirrorLength: Int) {
        state.observe(before: mirrorLength, after: mirrorLength, deleted: 1, inserted: 0)
    }

    func testNoDeleteCountCanBeRightForBothDocuments() {
        // The proof, and it holds for EVERY possible rule rather than for the one that
        // was deleted. Both documents present the same mirror, so any rule — however
        // it is written, whatever history it keeps — must hand the site one number.
        // This sweeps every number it could possibly choose and shows each one damages
        // at least one of the two documents.
        let mirrorText = "le Maois"
        let word = "Maois"

        for candidate in 0...word.count {
            let scenarioA = FakeDocument(document: "le Maos", mirror: mirrorText)  // phantom "i"
            let scenarioB = FakeDocument(document: "le Maois", mirror: mirrorText) // no phantom

            for doc in [scenarioA, scenarioB] {
                for _ in 0..<candidate { doc.deleteBackward() }
                doc.insertText("Mais ")
            }

            let bothRight = scenarioA.document == "le Mais " && scenarioB.document == "le Mais "
            XCTAssertFalse(
                bothRight,
                "a count of \(candidate) satisfied both documents — the scenarios were "
                + "not actually indistinguishable, and the proof would be void"
            )
        }

        // And the two counts that ARE each individually right differ by exactly one,
        // which is the whole difficulty: 4 replaces "Maos", 5 replaces "Maois".
        let onlyA = FakeDocument(document: "le Maos", mirror: mirrorText)
        for _ in 0..<4 { onlyA.deleteBackward() }
        onlyA.insertText("Mais ")
        XCTAssertEqual(onlyA.document, "le Mais ")

        let onlyB = FakeDocument(document: "le Maois", mirror: mirrorText)
        for _ in 0..<5 { onlyB.deleteBackward() }
        onlyB.insertText("Mais ")
        XCTAssertEqual(onlyB.document, "le Mais ")
    }

    func testBothScenariosProduceAnIdenticalObservableTrace() {
        // The premise of the proof above: everything the extension can read is the
        // same in both. If this ever fails, something distinguishes them and the
        // magnitude might be recoverable after all — so it is worth a test of its own.
        let mirrorText = "le Maois"
        let scenarioA = FakeDocument(document: "le Maos", mirror: mirrorText)
        let scenarioB = FakeDocument(document: "le Maois", mirror: mirrorText)

        let stateA = MirrorSyncState()
        let stateB = MirrorSyncState()
        replayTheAmbiguousDelete(into: stateA, mirrorLength: mirrorText.count)
        replayTheAmbiguousDelete(into: stateB, mirrorLength: mirrorText.count)

        XCTAssertEqual(scenarioA.contextBeforeInput, scenarioB.contextBeforeInput)
        XCTAssertEqual(stateA.isSuspect, stateB.isSuspect)
        XCTAssertTrue(stateA.isSuspect, "and both are suspect, which is the correct answer")
    }

    func testWhileSuspectTheSiteRefusesBothRatherThanDamagingOne() {
        // What the decision does with that impossibility: refuse. Neither document is
        // touched, so neither is damaged. The cost is that the misspelling stands.
        let mirrorText = "le Maois"
        for document in ["le Maos", "le Maois"] {
            let doc = FakeDocument(document: document, mirror: mirrorText)
            let state = MirrorSyncState()
            replayTheAmbiguousDelete(into: state, mirrorLength: mirrorText.count)

            let outcome = AutocorrectCountingSite.apply(
                editor: doc, word: "Maois", correction: "Mais", mirror: state
            )

            XCTAssertEqual(outcome, .refused(reason: MirrorGatedReplacement.suspectReason))
            XCTAssertEqual(doc.document, document, "untouched")
        }
    }

    func testTheDetectorIsSoundEvenThoughTheMagnitudeIsNot() {
        // What survives the proof above. The detector answers a different, answerable
        // question: "might the mirror be lying right now?" It never fires on healthy
        // typing — device-confirmed twice, criterion 9 — and it fires on both
        // scenarios above, which is correct, because in one of them the mirror IS
        // lying and nothing can say which.
        let healthy = MirrorSyncState()
        for length in 0..<40 {
            healthy.observe(before: length, after: length + 1, deleted: 0, inserted: 1)
        }
        XCTAssertFalse(healthy.isSuspect, "healthy typing must never raise suspicion")

        let suspect = MirrorSyncState()
        replayTheAmbiguousDelete(into: suspect, mirrorLength: 40)
        XCTAssertTrue(suspect.isSuspect, "an unreflected edit must raise it")
    }
}
