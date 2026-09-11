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

    /// Feeds a recorded trajectory through the REAL arming code, including the
    /// boundary notifications the bridge raises — a `space` or `return` event is a
    /// boundary this keyboard wrote, and the production path tells the accounting so.
    private func replay(_ edits: [RecordedEdit], into state: MirrorSyncState) {
        for edit in edits {
            state.observe(
                before: edit.before,
                after: edit.after,
                deleted: edit.deleted,
                inserted: edit.inserted
            )
            if edit.event == "space" || edit.event == "return" {
                state.noteBoundaryInserted(reason: edit.event, atLength: edit.after)
            }
        }
    }

    /// Capture 3 (`3-diagnostic-jevais.txt`), seq 41-45, verbatim. `before` is the
    /// previous line's `mlen`, `after` is this one's.
    ///
    /// seq=42 is a SPACE and seq=43/44 are two backspaces that take the cursor back
    /// past it — the shape that matters, and the one a truncated fixture hid.
    private static let capture3JeVais: [RecordedEdit] = [
        RecordedEdit(event: "key-delete", before: 49, after: 49, deleted: 1, inserted: 0),
        RecordedEdit(event: "space", before: 49, after: 50, deleted: 0, inserted: 1),
        RecordedEdit(event: "key-delete", before: 50, after: 49, deleted: 1, inserted: 0),
        RecordedEdit(event: "key-delete", before: 49, after: 48, deleted: 1, inserted: 0),
        RecordedEdit(event: "key-insert", before: 48, after: 49, deleted: 0, inserted: 1)
    ]

    /// Capture 4 (`4-suppression-went-dark.txt`), seq 316-335, verbatim.
    private static let capture4BeforeOense: [RecordedEdit] = [
        RecordedEdit(event: "key-delete", before: 82, after: 82, deleted: 1, inserted: 0),
        RecordedEdit(event: "space", before: 82, after: 83, deleted: 0, inserted: 1),
        RecordedEdit(event: "key-delete", before: 83, after: 82, deleted: 1, inserted: 0),
        RecordedEdit(event: "space", before: 82, after: 83, deleted: 0, inserted: 1),
        RecordedEdit(event: "key-delete", before: 83, after: 82, deleted: 1, inserted: 0),
        // seq 321-322 are host-side; the keyboard observes none of its own edits there.
        RecordedEdit(event: "return", before: 94, after: 95, deleted: 0, inserted: 1),
        RecordedEdit(event: "return", before: 95, after: 96, deleted: 0, inserted: 1),
        RecordedEdit(event: "key-insert", before: 96, after: 97, deleted: 0, inserted: 1),
        RecordedEdit(event: "key-insert", before: 97, after: 98, deleted: 0, inserted: 1),
        RecordedEdit(event: "space", before: 98, after: 99, deleted: 0, inserted: 1),
        RecordedEdit(event: "key-insert", before: 99, after: 100, deleted: 0, inserted: 1),
        RecordedEdit(event: "key-insert", before: 100, after: 101, deleted: 0, inserted: 1),
        RecordedEdit(event: "space", before: 101, after: 102, deleted: 0, inserted: 1),
        RecordedEdit(event: "key-insert", before: 102, after: 103, deleted: 0, inserted: 1),
        RecordedEdit(event: "key-insert", before: 103, after: 104, deleted: 0, inserted: 1),
        RecordedEdit(event: "key-insert", before: 104, after: 105, deleted: 0, inserted: 1),
        RecordedEdit(event: "key-insert", before: 105, after: 106, deleted: 0, inserted: 1),
        RecordedEdit(event: "key-insert", before: 106, after: 107, deleted: 0, inserted: 1)
    ]

    /// Capture 5 (`5-pproblème-stale-surplus.txt`), seq 680-689, verbatim.
    private static let capture5Probkeme: [RecordedEdit] = [
        RecordedEdit(event: "key-delete", before: 62, after: 62, deleted: 1, inserted: 0),
        RecordedEdit(event: "space", before: 62, after: 63, deleted: 0, inserted: 1)
    ] + (0..<8).map { index in
        RecordedEdit(event: "key-insert", before: 63 + index, after: 64 + index,
                     deleted: 0, inserted: 1)
    }

    // MARK: - 1. A word the user never touched is merged

    func testWhileTheMirrorIsSuspectTheWordIsLeftAloneRatherThanMerged() {
        // Capture 1, "Une fois ton" -> "Une foiston". The mirror reports "tonn" for a
        // document holding "ton", so the boundary check hands out 4. Deleting 4
        // removes n, o, t AND the space before the word, and "fois" — which the user
        // never touched — is swallowed by the insert.
        //
        // The arming edit is replayed first, the way the device reaches this moment:
        // capture 3's `MIRROR-PROBE seq=41 ev=key-delete`, before=49 after=49, the
        // keyboard's own backspace that the mirror did not register. No boundary is
        // inserted between that and the space, so the phantom is still inside the
        // word about to be replaced.
        let doc = FakeDocument(document: "Une fois ton", mirrorPhantomSuffix: "n")
        let state = MirrorSyncState()
        replay(Self.capture3JeVais, into: state)

        AutocorrectCountingSite.apply(
            editor: doc, word: "tonn", correction: "ton", mirror: state
        )

        // Capture 3's trajectory leaves the mirror suspect at the apply: the space at
        // seq=42 settled it, then the backspaces at seq=43/44 took the mirror below
        // that boundary and revived it. So the site refuses and touches nothing.
        //
        // The word is LEFT ALONE, not corrected. That is the design, decided on
        // 2026-09-12: the magnitude of the mirror's error is not computable, so the
        // only honest options are "act as develop does" or "do not act", and while the
        // mirror is suspect acting as develop does is what merges the words.
        XCTAssertEqual(doc.document, "Une fois ton", "untouched — no delete, no insert")
        XCTAssertFalse(doc.document.contains("foiston"), "the merge does not happen")
    }

    func testWithNoAccountingAtAllTheMergeIsUnavoidable() {
        // Characterisation of `develop`, kept so the cost of having no accounting is
        // written down rather than remembered. With `.trusted` the only reader is the
        // mirror, and the mirror says "tonn" — there is no second signal, so nothing
        // inside the extension can prevent this. It is the reason suspicion has to be
        // detected at all, and it is NOT a target: no in-process change makes it pass.
        let doc = FakeDocument(document: "Une fois ton", mirrorPhantomSuffix: "n")
        let state = MirrorSyncState()
        XCTAssertFalse(state.isSuspect)

        AutocorrectCountingSite.apply(
            editor: doc, word: "tonn", correction: "ton", mirror: state
        )

        XCTAssertEqual(doc.document, "Une foiston ", "develop merges the untouched word")
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
        // RECONSTRUCTED, not replayed verbatim: the raw capture is no longer on this
        // machine, and what survives of it is the arming line
        // (`MIRROR-ARMED surplus=+1 before=82 after=82`) and the ten MIRROR-SUPPRESSED
        // lines. The shape in between is forced by those: each suppression fired on a
        // spacebar press, so the user typed a word and pressed space, repeatedly.
        let state = MirrorSyncState()
        replay(Self.capture4BeforeOense, into: state)

        // Every one of these is a word capture 4 refused to correct. Each is reached
        // the way the user reached it: a space before the word, which the keyboard
        // itself inserted.
        for (typed, corrected) in [("oense", "pense"), ("contee", "contre"), ("ca", "ça")] {
            let doc = FakeDocument(document: "le \(typed)")
            let outcome = AutocorrectCountingSite.apply(
                editor: doc, word: typed, correction: corrected, mirror: state
            )

            // Capture 4's failure was autocorrect going dark for a whole session.
            // The boundaries in the recorded trajectory end the suspicion long before
            // these words, so each one is corrected normally — and in full.
            XCTAssertNotEqual(
                outcome, .refused(reason: MirrorGatedReplacement.suspectReason),
                "\(typed) was refused — autocorrect has gone dark (capture 4)"
            )
            XCTAssertEqual(
                doc.document, "le \(corrected) ",
                "\(typed) was corrected, but not to the right text"
            )
        }
    }

    // MARK: - 3. The stale surplus leaves a correction one character short

    func testAfterABoundarySettlesItACorrectionIsMadeInFull() {
        // Capture 5, build c47f944: MIRROR-CORRECTED word="probkeme" planned=8
        // deleted=7 surplus=1, eight times in 26 seconds, each one short.
        //
        // The trajectory is the recorded one. seq=680 arms the surplus — a key-delete
        // the mirror ignored, before=62 after=62. Then seq=681..689 are a space and
        // seven key-inserts that the mirror reflects EXACTLY, off=0 on every line.
        // By the time the correction fires, the mirror and document agree; the
        // surplus of 1 is stale, so subtracting it deletes one character too few and
        // the leading "p" of "probkeme" survives into "pproblème".
        // seq=681 is a SPACE, and it is the keyboard's own. That is the event the
        // shipped build ignored: it left the surplus latched for the next 26 seconds.
        let state = MirrorSyncState()
        replay(Self.capture5Probkeme, into: state)

        // The double space is from the capture: the user's space landed while the
        // mirror was already reporting one.
        let doc = FakeDocument(document: "le  probkeme")
        let outcome = AutocorrectCountingSite.apply(
            editor: doc, word: "probkeme", correction: "problème", mirror: state
        )

        // seq=681's space settles the suspicion, and the eight key-inserts after it
        // never take the mirror back below that boundary. So the mirror is NOT suspect
        // by the time the correction fires, and it is made in full.
        XCTAssertEqual(doc.document, "le  problème ")
        XCTAssertFalse(doc.document.contains("pproblème"), "the correction was one character short")
        XCTAssertEqual(outcome, .applied(deleted: 8))
    }

    // MARK: - 4. The spurious surplus: the word is left alone, not damaged

    /// Capture 6 (`6-MaMais-spurious-surplus.txt`), seq 274-284, verbatim.
    ///
    /// A host-side textDidChange takes the mirror 83 -> 71, which revives an earlier
    /// suspicion; the keyboard's next delete at seq=275 is not reflected, 71 -> 71.
    /// Then seven deletes the mirror does follow, and two inserts. NO boundary is
    /// written anywhere in here, so the suspicion is still live at the correction.
    private static let capture6Maois: [RecordedEdit] = [
        RecordedEdit(event: "key-delete", before: 71, after: 71, deleted: 1, inserted: 0)
    ] + (0..<7).map { index in
        RecordedEdit(event: "key-delete", before: 71 - index, after: 70 - index,
                     deleted: 1, inserted: 0)
    } + [
        RecordedEdit(event: "key-insert", before: 64, after: 65, deleted: 0, inserted: 1),
        RecordedEdit(event: "key-insert", before: 65, after: 66, deleted: 0, inserted: 1)
    ]

    func testASpuriousSuspicionLeavesTheWordUntouchedInsteadOfDamagingIt() {
        // The device produced three of these in 26 seconds:
        //   MIRROR-CORRECTED word="Maois" planned=5 deleted=3 surplus=2  -> "MaMais"
        // Pierre had typed "Maois" in full. There was no phantom in it; the surplus
        // was spurious, and subtracting it ate two real characters' worth of word.
        //
        // The magnitude was never knowable — see MirrorSurplusUnknowabilityTests — so
        // the site no longer uses one. It refuses while suspect, and the word stands.
        let state = MirrorSyncState()
        replay(Self.capture6Maois, into: state)
        XCTAssertTrue(state.isSuspect, "no boundary is written anywhere in this trajectory")

        let doc = FakeDocument(document: "Maois")
        let outcome = AutocorrectCountingSite.apply(
            editor: doc, word: "Maois", correction: "Mais", mirror: state
        )

        XCTAssertEqual(outcome, .refused(reason: MirrorGatedReplacement.suspectReason))
        XCTAssertEqual(doc.document, "Maois", "left alone — the user's word stands")
        XCTAssertFalse(doc.document.contains("MaMais"), "the reported damage")
        XCTAssertEqual(doc.deleteCalls, 0)
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
