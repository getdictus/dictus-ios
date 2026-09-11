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


    // MARK: - Refusal, not arithmetic

    func testASuspectMirrorRefusesOutright() {
        // The mirror reports "vaiss" for a document holding "vais", so the boundary
        // check would hand out 5 and the replacement would eat the space. While the
        // mirror is suspect no count is produced at all.
        let proxy = FakeProxy(document: "Ok je vais", phantom: "s")
        XCTAssertEqual(
            AutocorrectReplacement.check(context: proxy.contextBeforeInput, word: "vaiss"),
            .ok(deleteCount: 5),
            "precondition: the boundary check cannot see the desync"
        )

        XCTAssertEqual(
            MirrorGatedReplacement.check(
                mirrorSuspect: true, context: proxy.contextBeforeInput, word: "vaiss"
            ),
            .failed(reason: MirrorGatedReplacement.suspectReason)
        )
        XCTAssertEqual(proxy.deleteCalls, 0)
        XCTAssertEqual(proxy.document, "Ok je vais", "untouched")
    }

    func testATrustedMirrorSpendsTheCountUnchanged() {
        XCTAssertEqual(
            MirrorGatedReplacement.check(
                mirrorSuspect: false, context: "je pense quee", word: "quee"
            ),
            .ok(deleteCount: 4)
        )
    }

    // MARK: - What the surplus still does: decide suspicion, and nothing else

    func testSuccessiveDesyncsKeepTheMirrorSuspect() {
        let proxy = FakeProxy(document: "Ok je vais")
        let state = MirrorSyncState()

        proxy.mirrorIgnoresDeletes = true
        for _ in 0..<3 {
            edit(proxy, state: state, deleted: 1) { proxy.deleteBackward() }
            XCTAssertTrue(state.isSuspect)
        }
        XCTAssertEqual(proxy.mirror.count - proxy.document.count, 3)
    }

    func testAMirrorThatGivesBackMoreEndsTheSuspicion() {
        let proxy = FakeProxy(document: "Ok je vais")
        let state = MirrorSyncState()

        proxy.mirrorIgnoresDeletes = true
        edit(proxy, state: state, deleted: 1) { proxy.deleteBackward() }
        XCTAssertTrue(state.isSuspect)

        // The mirror drops two graphemes on a one-character delete: the phantom and
        // the real one. The debt is repaid, so the suspicion ends.
        state.observe(before: 10, after: 8, deleted: 1, inserted: 0)
        XCTAssertFalse(state.isSuspect)
    }

    func testSuspicionNeverGoesNegative() {
        let state = MirrorSyncState()
        state.observe(before: 20, after: 15, deleted: 1, inserted: 0)
        XCTAssertFalse(state.isSuspect)
    }

    // MARK: - The auto-period, which could never use a magnitude anyway

    func testASuspectMirrorStopsTheAutoPeriod() {
        let context = "Ok je vais "
        XCTAssertTrue(
            AutoFullStop.shouldSubstitute(context: context, mirrorSuspect: false),
            "precondition: this context is a genuine double-space substitution"
        )
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
            mirrorSuspect: true, context: "Ok je vais", word: "vais"
        ) else { return XCTFail("a suspect mirror must refuse") }
        XCTAssertEqual(reason, "mirror-desync")
    }

    // MARK: - Release

    func testReleaseClearsTheSuspicionAndTheCounters() {
        let state = MirrorSyncState()
        state.observe(before: 49, after: 49, deleted: 1, inserted: 0)
        state.noteSpaceWhileSuspect()
        state.noteSuppressedCorrection()
        XCTAssertTrue(state.isSuspect)
        XCTAssertEqual(state.spacesWhileSuspect, 1)

        state.release(reason: "viewWillAppear")

        XCTAssertFalse(state.isSuspect)
        XCTAssertEqual(state.spacesWhileSuspect, 0)
        XCTAssertEqual(state.suppressedCorrections, 0)
    }

    func testForwardTypingAloneNeverEndsTheSuspicion() {
        // Both cheaper releases stay falsified: "tracking again" is not "truthful
        // again". Only a boundary the keyboard writes ends it.
        let proxy = FakeProxy(document: "Ok je vais")
        let state = MirrorSyncState()
        proxy.mirrorIgnoresDeletes = true
        edit(proxy, state: state, deleted: 1) { proxy.deleteBackward() }
        proxy.mirrorIgnoresDeletes = false

        for character in "faireuntest" {
            edit(proxy, state: state, insert: String(character)) {
                proxy.insertText(String(character))
            }
        }

        XCTAssertTrue(state.isSuspect, "no release condition was observed; do not invent one")
    }
}
