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

    func testOneObservableTraceHasTwoDifferentCorrectAnswers() {
        // Same mirror text, same lengths, same edit history. Different documents.
        let mirrorText = "le Maois"

        // A: the mirror's "Maois" carries a phantom; the document holds "Maos".
        let scenarioA = FakeDocument(document: "le Maos", mirror: mirrorText)
        let stateA = MirrorSyncState()
        replayTheAmbiguousDelete(into: stateA, mirrorLength: mirrorText.count)

        // B: no phantom anywhere; the document holds "Maois" in full.
        let scenarioB = FakeDocument(document: "le Maois", mirror: mirrorText)
        let stateB = MirrorSyncState()
        replayTheAmbiguousDelete(into: stateB, mirrorLength: mirrorText.count)

        XCTAssertEqual(stateA.trust, stateB.trust, "the traces are indistinguishable")
        XCTAssertEqual(scenarioA.contextBeforeInput, scenarioB.contextBeforeInput)

        AutocorrectCountingSite.apply(
            editor: scenarioA, word: "Maois", correction: "Mais", mirror: stateA
        )
        AutocorrectCountingSite.apply(
            editor: scenarioB, word: "Maois", correction: "Mais", mirror: stateB
        )

        // Exactly one of these can be right, whatever number the site chooses.
        let correctA = scenarioA.document == "le Mais "
        let correctB = scenarioB.document == "le Mais "
        XCTAssertFalse(
            correctA && correctB,
            "if both are right the scenarios were not actually indistinguishable"
        )
        XCTAssertTrue(
            correctA || correctB,
            "one of them must be right — the site does pick a number"
        )

        // And the one it gets wrong is wrong in the way the user reported: a leading
        // fragment of the typed word survives in front of the correction. Capture 6
        // had a surplus of 2 and produced "MaMais"; this minimal trace carries a
        // surplus of 1 and produces "MMais". Same defect, one character smaller.
        XCTAssertTrue(correctA, "the phantom scenario is the one the surplus is tuned for")
        XCTAssertEqual(scenarioB.document, "le MMais ", "the no-phantom document is damaged")
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
        XCTAssertEqual(healthy.trust, .trusted, "healthy typing must never raise suspicion")

        let suspect = MirrorSyncState()
        replayTheAmbiguousDelete(into: suspect, mirrorLength: 40)
        XCTAssertNotEqual(suspect.trust, .trusted, "an unreflected edit must raise it")
    }
}
