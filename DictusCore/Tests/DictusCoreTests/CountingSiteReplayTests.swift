// DictusCore/Tests/DictusCoreTests/CountingSiteReplayTests.swift
// The feedback loop for #530: the real counting sites, run against a document that
// is NOT what the mirror says it is, with mirror trajectories replayed from device
// captures rather than invented.
//
// WHY THE ASSERTIONS ARE ALL ON `document`:
// Every earlier test in this issue asserted against a mirror the test itself
// controlled, which is the same blindness the bug is made of. A mirror validated
// against itself always agrees. `FakeDocument` keeps the two apart and the
// assertions only ever look at the side the user can see.
//
// PRIVACY: the captures are Pierre's own notes and this repo is public, so the
// fixtures below are reduced to event skeletons — kinds, lengths, counts — plus the
// few short words the assertions actually need.

import XCTest
@testable import DictusCore

final class CountingSiteReplayTests: XCTestCase {

    // MARK: - A document and a mirror that can disagree

    /// The live document plus the mirror `TextDocumentEditing` reports.
    ///
    /// `mirrorIgnoresDeletes` is the measured failure: `MIRROR-PROBE seq=41
    /// ev=key-delete`, where the keyboard pressed backspace, the document lost a
    /// character and the mirror did not move.
    private final class FakeDocument: TextDocumentEditing {
        private(set) var document: String
        private(set) var mirror: String
        private(set) var deleteCalls = 0
        var mirrorIgnoresDeletes = false

        init(document: String, mirrorPhantomSuffix: String = "") {
            self.document = document
            self.mirror = document + mirrorPhantomSuffix
        }

        var contextBeforeInput: String? { mirror.isEmpty ? nil : mirror }

        func deleteBackward() {
            deleteCalls += 1
            if !document.isEmpty { document.removeLast() }
            if !mirrorIgnoresDeletes, !mirror.isEmpty { mirror.removeLast() }
        }

        func insertText(_ text: String) {
            document += text
            mirror += text
        }
    }

    /// One recorded `MIRROR-PROBE` line, reduced to what the accounting consumes.
    private struct RecordedEdit {
        let event: String
        let before: Int
        let after: Int
        let deleted: Int
        let inserted: Int
    }

    /// Feeds a recorded trajectory through the REAL arming code.
    private func replay(_ edits: [RecordedEdit], into state: MirrorSyncState) {
        for edit in edits {
            state.observe(
                before: edit.before,
                after: edit.after,
                deleted: edit.deleted,
                inserted: edit.inserted
            )
        }
    }

    // MARK: - 1. A word the user never touched is merged

    func testAWordTheUserNeverTouchedIsNeverMerged() {
        // Capture 1, "Une fois ton" -> "Une foiston". The mirror reports "tonn" for a
        // document holding "ton", so the boundary check hands out 4. Deleting 4
        // removes n, o, t AND the space before the word, and "fois" — which the user
        // never touched — is swallowed by the insert.
        //
        // `.trusted` is develop's state: no accounting, so nothing corrects the count.
        let doc = FakeDocument(document: "Une fois ton", mirrorPhantomSuffix: "n")
        let state = MirrorSyncState()
        XCTAssertEqual(state.trust, .trusted, "develop has no surplus accounting")

        AutocorrectCountingSite.apply(
            editor: doc, word: "tonn", correction: "ton", mirror: state
        )

        XCTAssertEqual(doc.document, "Une fois ton ")
        XCTAssertTrue(doc.document.hasPrefix("Une fois "), "the preceding word and its space survive")
    }

    func testTheSameReplacementIsCorrectOnceTheDesyncHasBeenObserved() {
        // The same document, reached the way the device reaches it: the arming event
        // is replayed first, so the accounting knows the mirror is one character long.
        let doc = FakeDocument(document: "Une fois ton", mirrorPhantomSuffix: "n")
        let state = MirrorSyncState()
        replay([RecordedEdit(event: "key-delete", before: 13, after: 13, deleted: 1, inserted: 0)],
               into: state)
        XCTAssertEqual(state.trust, .surplus(1))

        AutocorrectCountingSite.apply(
            editor: doc, word: "tonn", correction: "ton", mirror: state
        )

        XCTAssertEqual(doc.document, "Une fois ton ")
    }

    // MARK: - 2. Suppression, once armed, never releases

    func testAutocorrectStillWorksAfterADesyncHasBeenSeen() {
        // Capture 4: armed once at 12:16:09 with surplus=+1, released never, ten
        // suppressions in 25 seconds — seven of them real misspellings. The reporter:
        // "ça a complètement désactivé l'autocorrection".
        //
        // The trajectory is the recorded one: the arming edit, then ordinary typing
        // that the mirror reflects perfectly. Nothing in it releases anything, which
        // is the point — the fix must keep correcting rather than wait for a release.
        let state = MirrorSyncState()
        var trajectory = [RecordedEdit(event: "key-delete", before: 82, after: 82, deleted: 1, inserted: 0)]
        for index in 0..<20 {
            trajectory.append(RecordedEdit(
                event: "key-insert", before: 82 + index, after: 83 + index, deleted: 0, inserted: 1
            ))
        }
        replay(trajectory, into: state)
        XCTAssertEqual(state.trust, .surplus(1), "nothing observed releases the desync")

        // Every one of these is a word capture 4 refused to correct.
        for (typed, corrected) in [("oense", "pense"), ("contee", "contre"), ("ca", "ça")] {
            let doc = FakeDocument(document: "le \(typed)")
            let outcome = AutocorrectCountingSite.apply(
                editor: doc, word: typed, correction: corrected, mirror: state
            )

            // Two distinct failures, and the test names both. Refusal is capture 4's:
            // autocorrect dark. A wrong result is capture 5's successor to it: the
            // stale surplus makes every later correction one character short, so the
            // same words come out damaged instead of uncorrected.
            XCTAssertNotEqual(
                outcome, .refused(reason: MirrorGatedReplacement.unknownReason),
                "\(typed) was refused — autocorrect has gone dark (capture 4)"
            )
            XCTAssertEqual(
                doc.document, "le \(corrected) ",
                "\(typed) was corrected, but not to the right text (capture 5's stale surplus)"
            )
        }
    }

    // MARK: - 3. The stale surplus leaves a correction one character short

    func testAStaleSurplusDoesNotLeaveTheWordOneCharacterShort() {
        // Capture 5, build c47f944: MIRROR-CORRECTED word="probkeme" planned=8
        // deleted=7 surplus=1, eight times in 26 seconds, each one short.
        //
        // The trajectory is the recorded one. seq=680 arms the surplus — a key-delete
        // the mirror ignored, before=62 after=62. Then seq=681..689 are a space and
        // seven key-inserts that the mirror reflects EXACTLY, off=0 on every line.
        // By the time the correction fires, the mirror and document agree; the
        // surplus of 1 is stale, so subtracting it deletes one character too few and
        // the leading "p" of "probkeme" survives into "pproblème".
        let state = MirrorSyncState()
        var trajectory = [
            RecordedEdit(event: "key-delete", before: 62, after: 62, deleted: 1, inserted: 0),
            RecordedEdit(event: "space", before: 62, after: 63, deleted: 0, inserted: 1)
        ]
        for index in 0..<7 {
            trajectory.append(RecordedEdit(
                event: "key-insert", before: 64 + index, after: 65 + index, deleted: 0, inserted: 1
            ))
        }
        replay(trajectory, into: state)

        // The double space is from the capture: the user's space landed while the
        // mirror was already reporting one.
        let doc = FakeDocument(document: "le  probkeme")
        let outcome = AutocorrectCountingSite.apply(
            editor: doc, word: "probkeme", correction: "problème", mirror: state
        )

        XCTAssertEqual(doc.document, "le  problème ")
        XCTAssertFalse(doc.document.contains("pproblème"), "the correction was one character short")
        XCTAssertEqual(outcome, .applied(deleted: 8, correctedBy: 0))
    }

    // MARK: - The seam itself

    func testTheFakeKeepsDocumentAndMirrorApart() {
        // Guards the loop against the blindness it exists to avoid: if this ever
        // passes with one string, every test above becomes a mirror validating
        // itself and the suite goes quiet while text is destroyed.
        let doc = FakeDocument(document: "abc", mirrorPhantomSuffix: "d")
        XCTAssertEqual(doc.document, "abc")
        XCTAssertEqual(doc.contextBeforeInput, "abcd")

        doc.mirrorIgnoresDeletes = true
        doc.deleteBackward()
        XCTAssertEqual(doc.document, "ab", "the document lost a character")
        XCTAssertEqual(doc.contextBeforeInput, "abcd", "the mirror did not notice")
    }

    func testTheAutoPeriodSiteRunsOnTheSeamToo() {
        let doc = FakeDocument(document: "Ok ")
        let state = MirrorSyncState()

        XCTAssertTrue(AutoFullStopCountingSite.apply(editor: doc, mirror: state))
        XCTAssertEqual(doc.document, "Ok. ")
    }
}
