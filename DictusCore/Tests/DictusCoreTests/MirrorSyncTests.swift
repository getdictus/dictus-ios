// DictusCore/Tests/DictusCoreTests/MirrorSyncTests.swift
// Tests for the #530 fix: arming on a mirror that stopped reflecting the keyboard's
// own edits, and the two automatic sites refusing to act while it is armed.
//
// The fake proxy below is the point of these tests. Criterion 2 asks for proof that
// nothing deletes while armed, and "proof" means running it, not reading the code.

import XCTest
@testable import DictusCore

final class MirrorSyncTests: XCTestCase {

    /// A stand-in for UITextDocumentProxy that counts what was actually done to it.
    ///
    /// `mirror` is what `documentContextBeforeInput` reports; `phantom` is how many
    /// characters it holds that the document does not, i.e. how far it is lying.
    /// `deleteCalls` is the number criterion 2 is about.
    private final class FakeProxy {
        private(set) var document: String
        private(set) var mirror: String
        private(set) var deleteCalls = 0
        private(set) var inserted = ""
        /// When true the mirror ignores deletions — the measured #530 failure.
        var mirrorIgnoresDeletes = false

        init(document: String, phantom: String = "") {
            self.document = document
            self.mirror = document + phantom
        }

        var contextBeforeInput: String? { mirror.isEmpty ? nil : mirror }
        var mirrorLength: Int { mirror.count }

        func deleteBackward() {
            deleteCalls += 1
            if !document.isEmpty { document.removeLast() }
            if !mirrorIgnoresDeletes, !mirror.isEmpty { mirror.removeLast() }
        }

        /// Sets the mirror to something the document is not, for cases where the
        /// phantom is not a simple appended character.
        func forceMirror(_ text: String) { mirror = text }

        /// A host-side edit: text changes with no keyboard operation behind it.
        func hostEdit(to text: String) {
            document = text
            mirror = text
        }

        func insertText(_ text: String) {
            inserted += text
            document += text
            mirror += text
        }
    }

    /// Runs one keyboard edit through the real arming path, exactly as the bridge
    /// does: read the mirror length, edit, report. Keeping this in one place is what
    /// stops the test drifting from `DictusKeyboardBridge.observeMirror`.
    private func edit(
        _ proxy: FakeProxy,
        state: MirrorSyncState,
        deleted: Int = 0,
        insert: String = "",
        _ body: () -> Void
    ) {
        let before = proxy.mirrorLength
        body()
        state.observe(
            before: before,
            after: proxy.mirrorLength,
            deleted: deleted,
            inserted: insert.count
        )
    }

    // MARK: - Criterion 1: what arms, and what must not

    func testAnEditTheMirrorIgnoresMakesItSuspect() {
        // The measured trigger: MIRROR-PROBE seq=41 ev=key-delete. The keyboard
        // pressed backspace, the document lost a character, the mirror did not move.
        let proxy = FakeProxy(document: "Ok je vais")
        let state = MirrorSyncState()
        proxy.mirrorIgnoresDeletes = true

        edit(proxy, state: state, deleted: 1) { proxy.deleteBackward() }

        XCTAssertTrue(state.isSuspect)
    }

    func testAnEditTheMirrorReflectsDoesNotArm() {
        let proxy = FakeProxy(document: "Ok je vais")
        let state = MirrorSyncState()

        edit(proxy, state: state, deleted: 1) { proxy.deleteBackward() }
        edit(proxy, state: state, insert: "s") { proxy.insertText("s") }

        XCTAssertFalse(state.isSuspect)
    }

    func testAHostSideChangeAloneDoesNotArm() {
        // A selection delete removes text with no keyboard edit between the two
        // readings. Nothing is reported, so nothing arms: only an edit the keyboard
        // made and the mirror ignored can arm the flag.
        let state = MirrorSyncState()
        let proxy = FakeProxy(document: "Ok je vais faire un test")

        _ = proxy.mirrorLength
        proxy.hostEdit(to: "Ok je vais un test")

        XCTAssertFalse(state.isSuspect)
    }

    // MARK: - Criterion 9: suspicion unreachable on a healthy mirror

    func testOrdinaryTypingNeverArms() {
        // The regression that decides whether this ships. A fix that quietly dampens
        // autocorrect on healthy input is worse than the bug, because nobody reports it.
        let proxy = FakeProxy(document: "")
        let state = MirrorSyncState()

        for character in "Ok je vais faire un test. " {
            edit(proxy, state: state, insert: String(character)) {
                proxy.insertText(String(character))
            }
        }
        for _ in 0..<5 {
            edit(proxy, state: state, deleted: 1) { proxy.deleteBackward() }
        }

        XCTAssertFalse(state.isSuspect)
        XCTAssertEqual(proxy.document, "Ok je vais faire un t")
    }

    func testBackspaceOnAnEmptyFieldDoesNotArm() {
        // deleteBackward() with nothing to delete moves neither document nor mirror.
        // Without min(deleted, before) this expects -1, observes 0, and looks exactly
        // like the bug — arming the suppression on the emptiest possible input.
        let proxy = FakeProxy(document: "")
        let state = MirrorSyncState()

        edit(proxy, state: state, deleted: 1) { proxy.deleteBackward() }

        XCTAssertFalse(state.isSuspect)
    }

    func testAMirrorThatGrowsLessThanTheInsertDoesNotArm() {
        // A combining mark merging into the previous grapheme, or a windowed mirror
        // that has stopped growing (#266). The mirror ends SHORTER than the edit
        // implies, so a later count under-deletes and leaves a stray character —
        // recoverable with one backspace, and not what this suppression is for.
        let state = MirrorSyncState()
        let verdict = MirrorSync.verdict(before: 10, after: 10, deleted: 0, inserted: 1)

        XCTAssertEqual(verdict, .mirrorBehind(by: 1))
        state.observe(before: 10, after: 10, deleted: 0, inserted: 1)
        XCTAssertFalse(state.isSuspect)
    }

    func testTheMeasuredArithmeticFromTheCapture() {
        // seq=41: before 49, after 49, one deleteBackward.
        XCTAssertEqual(
            MirrorSync.verdict(before: 49, after: 49, deleted: 1, inserted: 0),
            .mirrorAhead(by: 1)
        )
        // seq=40, the healthy readings either side of it.
        XCTAssertEqual(
            MirrorSync.verdict(before: 50, after: 49, deleted: 1, inserted: 0),
            .consistent
        )
    }


    // MARK: - The revised reaction: correct the count, do not refuse

    func testTheCapturedDesyncCorrectsToTheExactWord() {
        // Field capture 2: the mirror reports "vaiss" for a document holding "vais",
        // so the boundary check hands out 5. Deleting 5 removes s, i, a, v AND the
        // space: "Ok jevais ". Deleting 5 - 1 removes exactly "vais".
        let proxy = FakeProxy(document: "Ok je vais", phantom: "s")
        XCTAssertEqual(
            AutocorrectReplacement.check(context: proxy.contextBeforeInput, word: "vaiss"),
            .ok(deleteCount: 5),
            "precondition: the boundary check cannot see the desync"
        )

        let gated = MirrorGatedReplacement.check(
            trust: .surplus(1), context: proxy.contextBeforeInput, word: "vaiss"
        )
        XCTAssertEqual(gated, .ok(deleteCount: 4))

        guard case .ok(let count) = gated else { return XCTFail("expected a corrected count") }
        for _ in 0..<count { proxy.deleteBackward() }
        proxy.insertText("vais ")
        XCTAssertEqual(proxy.document, "Ok je vais ")
    }

    func testTheFirstFieldCaptureAlsoLandsExactly() {
        // "tonn"(4) with surplus 1 -> delete 3 -> "Une fois " + "ton " = "Une fois ton ".
        let proxy = FakeProxy(document: "Une fois ton", phantom: "n")
        let gated = MirrorGatedReplacement.check(
            trust: .surplus(1), context: proxy.contextBeforeInput, word: "tonn"
        )
        XCTAssertEqual(gated, .ok(deleteCount: 3))

        guard case .ok(let count) = gated else { return XCTFail("expected a corrected count") }
        for _ in 0..<count { proxy.deleteBackward() }
        proxy.insertText("ton ")
        XCTAssertEqual(proxy.document, "Une fois ton ")
    }

    func testATrustedMirrorSpendsTheCountUnchanged() {
        XCTAssertEqual(
            MirrorGatedReplacement.check(trust: .trusted, context: "je pense quee", word: "quee"),
            .ok(deleteCount: 4)
        )
    }

    // MARK: - Question 1: does the surplus stay correct across successive desyncs?

    func testSuccessiveDesyncsAccumulateTheSurplus() {
        let proxy = FakeProxy(document: "Ok je vais")
        let state = MirrorSyncState()

        proxy.mirrorIgnoresDeletes = true
        edit(proxy, state: state, deleted: 1) { proxy.deleteBackward() }
        XCTAssertEqual(state.trust, .surplus(1))
        edit(proxy, state: state, deleted: 1) { proxy.deleteBackward() }
        XCTAssertEqual(state.trust, .surplus(2))
        edit(proxy, state: state, deleted: 1) { proxy.deleteBackward() }

        // Three ignored deletes, three phantoms. The mirror is now three characters
        // longer than the document, and a count taken off it is too big by three.
        XCTAssertEqual(state.trust, .surplus(3))
        XCTAssertEqual(proxy.mirror.count - proxy.document.count, 3)
    }

    func testAMirrorThatGivesBackMorePaysTheSurplusDown() {
        let proxy = FakeProxy(document: "Ok je vais")
        let state = MirrorSyncState()

        proxy.mirrorIgnoresDeletes = true
        edit(proxy, state: state, deleted: 1) { proxy.deleteBackward() }
        XCTAssertEqual(state.trust, .surplus(1))

        // The mirror drops two graphemes on a one-character delete: the phantom and
        // the real one. The accounting must follow it back down, not stay armed
        // forever on a debt that has been repaid.
        state.observe(before: 10, after: 8, deleted: 1, inserted: 0)
        XCTAssertEqual(state.trust, .trusted)
    }

    func testTheSurplusNeverGoesNegative() {
        // A negative surplus would mean ADDING deletions, which is the one thing that
        // destroys text. The floor at zero is the invariant that forbids it.
        let state = MirrorSyncState()
        state.observe(before: 20, after: 15, deleted: 1, inserted: 0)
        XCTAssertEqual(state.trust, .trusted)
        XCTAssertEqual(
            MirrorSync.adjust(deleteCount: 4, trust: state.trust),
            .exact(deleteCount: 4)
        )
    }

    // MARK: - Question 2: what happens when the accounting is unattributable

    func testAnAccumulationBeyondTheCeilingFallsBackToRefusal() {
        let state = MirrorSyncState()
        for _ in 0..<9 {
            state.observe(before: 40, after: 40, deleted: 1, inserted: 0)
        }
        XCTAssertEqual(state.trust, .unknown)
        XCTAssertEqual(
            MirrorGatedReplacement.check(trust: .unknown, context: "Ok je vais", word: "vais"),
            .failed(reason: MirrorGatedReplacement.unknownReason)
        )
    }

    func testUnknownIsStickyUntilRelease() {
        // A lost accounting cannot be re-derived from later edits: an edit the mirror
        // reflects perfectly says nothing about a surplus that was already there.
        let state = MirrorSyncState()
        state.markUnknown(reason: "test")
        state.observe(before: 10, after: 11, deleted: 0, inserted: 1)
        XCTAssertEqual(state.trust, .unknown)

        state.release(reason: "viewWillAppear")
        XCTAssertEqual(state.trust, .trusted)
    }

    func testASurplusClaimingTheWholeWordRefusesRatherThanDuplicatingIt() {
        // Deleting 0 and inserting the correction would give "tonton". Refusing is
        // the only sane answer, and it is the fallback rather than the behaviour.
        XCTAssertEqual(
            MirrorSync.adjust(deleteCount: 3, trust: .surplus(3)),
            .refuse(reason: MirrorGatedReplacement.surplusExceedsWordReason)
        )
        XCTAssertEqual(
            MirrorSync.adjust(deleteCount: 3, trust: .surplus(4)),
            .refuse(reason: MirrorGatedReplacement.surplusExceedsWordReason)
        )
    }

    // MARK: - Question 3: can correcting be worse than refusing?

    func testTheCorrectedCountIsNeverLargerThanTheUncorrectedOne() {
        // THE safety property. The corrected count can only ever be smaller, so this
        // fix cannot destroy text that develop would have kept — the worst it can do
        // is stop short and leave a stray character.
        for deleteCount in 1...12 {
            for surplus in 0...12 {
                let trust: MirrorTrust = surplus == 0 ? .trusted : .surplus(surplus)
                switch MirrorSync.adjust(deleteCount: deleteCount, trust: trust) {
                case .exact(let count), .corrected(let count, _):
                    XCTAssertLessThanOrEqual(count, deleteCount)
                    XCTAssertGreaterThan(count, 0)
                case .refuse:
                    break   // refusing deletes nothing, which is also never larger
                }
            }
        }
    }

    func testAnOverEstimatedSurplusUnderDeletesAndLeavesAStrayCharacter() {
        // The acceptable failure, proven to be the one that occurs. The mirror is
        // honest here but the accounting thinks it is holding two phantoms, so the
        // replacement stops short. The result is a visible typo, recoverable with one
        // backspace — never a merged word.
        let proxy = FakeProxy(document: "je pense quee")
        let gated = MirrorGatedReplacement.check(
            trust: .surplus(2), context: proxy.contextBeforeInput, word: "quee"
        )
        XCTAssertEqual(gated, .ok(deleteCount: 2))

        guard case .ok(let count) = gated else { return XCTFail("expected a corrected count") }
        for _ in 0..<count { proxy.deleteBackward() }
        proxy.insertText("que ")

        XCTAssertEqual(proxy.document, "je pense quque ")
        XCTAssertTrue(proxy.document.contains("pense "), "the preceding word and its space survive")
    }

    func testAPhantomNotAtTheTailStillCorrectsTheLengthSafely() {
        // The surplus is a length, not a position: the mirror holds "toxy" where the
        // document holds "toy", so dropping the LAST character would be wrong. The
        // count is still right, which is all a delete needs.
        let proxy = FakeProxy(document: "a toy")
        proxy.forceMirror("a toxy")
        let gated = MirrorGatedReplacement.check(
            trust: .surplus(1), context: proxy.contextBeforeInput, word: "toxy"
        )
        XCTAssertEqual(gated, .ok(deleteCount: 3))

        guard case .ok(let count) = gated else { return XCTFail("expected a corrected count") }
        for _ in 0..<count { proxy.deleteBackward() }
        XCTAssertEqual(proxy.document, "a ", "exactly the real word was removed, space intact")
    }

    // MARK: - Criterion 2: the auto-period still refuses, and why

    func testASuspectMirrorStopsTheAutoPeriodEvenWhenTheSurplusIsKnown() {
        // Unlike the replacement path, this asks what a character IS, and the surplus
        // cannot answer that. The capture caught it writing ". " over a space that was
        // not there, turning "Ok je vais" into "Ok je vai." on one press.
        let context = "Ok je vais "
        XCTAssertTrue(AutoFullStop.shouldSubstitute(context: context, mirrorSuspect: false))
        XCTAssertFalse(AutoFullStop.shouldSubstitute(context: context, mirrorSuspect: true))
    }

    func testAutoFullStopRulesAreUnchangedWhenTheMirrorIsTrusted() {
        XCTAssertFalse(AutoFullStop.shouldSubstitute(context: "Ok  ", mirrorSuspect: false))
        XCTAssertFalse(AutoFullStop.shouldSubstitute(context: "Ok. ", mirrorSuspect: false))
        XCTAssertFalse(AutoFullStop.shouldSubstitute(context: "Ok", mirrorSuspect: false))
        XCTAssertFalse(AutoFullStop.shouldSubstitute(context: nil, mirrorSuspect: false))
        XCTAssertFalse(AutoFullStop.shouldSubstitute(context: " ", mirrorSuspect: false))
        XCTAssertTrue(AutoFullStop.shouldSubstitute(context: "Ok ", mirrorSuspect: false))
    }

    // MARK: - Criterion 3: nothing is learned on a refusal

    func testARefusalCarriesASlugTheBridgeTurnsIntoNoLearning() {
        // The bridge clears wordWasEvaluated on `.failed`, which is what keeps the
        // word out of UserDictionary. Pinned so a refusal cannot quietly become a
        // different, learnable outcome.
        guard case .failed(let reason) = MirrorGatedReplacement.check(
            trust: .unknown, context: "Ok je vais", word: "vais"
        ) else { return XCTFail("unknown must refuse") }
        XCTAssertEqual(reason, "mirror-desync-unknown")
    }

    // MARK: - Release

    func testReleaseClearsTheAccountingAndTheCounters() {
        let state = MirrorSyncState()
        state.observe(before: 49, after: 49, deleted: 1, inserted: 0)
        state.noteSpaceWhileSuspect()
        state.noteSuppressedCorrection()
        state.noteCorrectedReplacement()
        XCTAssertEqual(state.trust, .surplus(1))

        state.release(reason: "viewWillAppear")

        XCTAssertEqual(state.trust, .trusted)
        XCTAssertEqual(state.spacesWhileSuspect, 0)
        XCTAssertEqual(state.suppressedCorrections, 0)
        XCTAssertEqual(state.correctedReplacements, 0)
    }

    func testNeitherFalsifiedReleaseExists() {
        // A word boundary and a run of correctly-reflected edits must both leave the
        // surplus in place: "tracking again" is not "truthful again" — from seq=43 the
        // mirror tracked every edit while still reporting "vaiss" for "vais".
        let proxy = FakeProxy(document: "Ok je vais")
        let state = MirrorSyncState()
        proxy.mirrorIgnoresDeletes = true
        edit(proxy, state: state, deleted: 1) { proxy.deleteBackward() }
        proxy.mirrorIgnoresDeletes = false

        for character in " faire un test " {
            edit(proxy, state: state, insert: String(character)) {
                proxy.insertText(String(character))
            }
        }

        XCTAssertEqual(state.trust, .surplus(1), "no release condition was observed; do not invent one")
    }
}
