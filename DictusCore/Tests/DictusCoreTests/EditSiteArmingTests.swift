// DictusCore/Tests/DictusCoreTests/EditSiteArmingTests.swift
// Every keyboard edit site must tell the mirror detector what it did (issue #548).
//
// #530 shipped a detector that only learns about an edit if that edit reports it.
// Three sites edited the document and reported nothing, so a desync they caused was
// invisible to the sites that refuse — #530's failure through a door left open for
// the replacements but never meant to be open for the detection.
//
// These tests are about the ARITHMETIC each site hands the detector, which is where
// the risk is. A site that over-states its deletions arms the detector on healthy
// typing, and that is #530's criterion 9 — the regression that would hurt most.
//
// The shapes below mirror the production call sites one for one. They are integer
// facts, so they are tested as integers; what the sites DO with the document is
// covered by CountingSiteReplayTests against a FakeDocument.

import XCTest
@testable import DictusCore

final class EditSiteArmingTests: XCTestCase {

    /// One site's report, named as the production call site names it.
    private struct EditShape {
        let site: String
        let deleted: Int
        let inserted: Int
    }

    /// Every site armed by #548, with the arithmetic it reports.
    private static let armedSites: [EditShape] = [
        EditShape(site: "handleWordDelete-fallback", deleted: 1, inserted: 0),
        EditShape(site: "handleWordDelete", deleted: 7, inserted: 0),
        EditShape(site: "prediction-tap", deleted: 0, inserted: 6),
        EditShape(site: "emoji-insert", deleted: 0, inserted: 1),
        EditShape(site: "emoji-delete", deleted: 1, inserted: 0),
        EditShape(site: "reject-correction-space", deleted: 0, inserted: 1),
        EditShape(site: "bar-undo", deleted: 9, inserted: 12),
        EditShape(site: "bar-replace", deleted: 4, inserted: 8)
    ]

    // MARK: - Criterion 4: healthy typing still never arms

    func testNoArmedSiteRaisesSuspicionWhenTheMirrorReflectsItFaithfully() {
        // The one that matters most. Every site's `deleted` is counted off the mirror
        // itself in production, so a faithful mirror always agrees — but the whole
        // point of #548 is that these numbers are newly load-bearing, so they are
        // checked rather than assumed.
        for shape in Self.armedSites {
            for before in 0...60 {
                let state = MirrorSyncState()
                let deleted = min(shape.deleted, before)
                let after = before - deleted + shape.inserted

                state.observe(
                    before: before, after: after,
                    deleted: shape.deleted, inserted: shape.inserted
                )

                XCTAssertFalse(
                    state.isSuspect,
                    "\(shape.site) armed on a faithful mirror at before=\(before)"
                )
            }
        }
    }

    func testAnEmptyMirrorNeverArmsWhateverTheSiteClaimsToDelete() {
        // The word-delete fallback runs precisely when the mirror is empty, and a
        // delete that had nothing to consume must not look like a desync.
        for shape in Self.armedSites {
            let state = MirrorSyncState()
            state.observe(before: 0, after: shape.inserted,
                          deleted: shape.deleted, inserted: shape.inserted)
            XCTAssertFalse(state.isSuspect, "\(shape.site) armed on an empty mirror")
        }
    }

    func testAMirrorThatMovesLessThanTheInsertNeverArms() {
        // A grapheme that merges into the one before it — a combining accent, an
        // emoji modifier. The mirror ends SHORTER than the edit implies, which is the
        // recoverable direction and must not raise suspicion.
        for shape in Self.armedSites where shape.inserted > 0 {
            let state = MirrorSyncState()
            let before = 40
            let after = before - min(shape.deleted, before) + shape.inserted - 1

            state.observe(before: before, after: after,
                          deleted: shape.deleted, inserted: shape.inserted)

            XCTAssertFalse(state.isSuspect, "\(shape.site) armed on a merging grapheme")
        }
    }

    // MARK: - Criterion 2: an unreflected edit at any site raises suspicion

    func testEveryArmedSiteRaisesSuspicionWhenTheMirrorIgnoresItsDelete() {
        // The signal #548 exists to stop these sites from swallowing: the keyboard
        // deleted, and the mirror did not move.
        for shape in Self.armedSites where shape.deleted > 0 {
            let state = MirrorSyncState()
            let before = 40
            // The mirror takes the insert but not the delete.
            let after = before + shape.inserted

            state.observe(before: before, after: after,
                          deleted: shape.deleted, inserted: shape.inserted)

            XCTAssertTrue(
                state.isSuspect,
                "\(shape.site) hid a desync — the detector was never told"
            )
        }
    }

    func testASiteThatOnlyInsertsStillRaisesSuspicionOnASurplus() {
        // The insert-only sites — the prediction tap, the emoji key, the rejected
        // correction — cannot hide a missed delete, but they can still catch a mirror
        // that gained characters nobody wrote.
        for shape in Self.armedSites where shape.deleted == 0 {
            let state = MirrorSyncState()
            let before = 40
            let after = before + shape.inserted + 1

            state.observe(before: before, after: after,
                          deleted: shape.deleted, inserted: shape.inserted)

            XCTAssertTrue(state.isSuspect, "\(shape.site) missed a surplus")
        }
    }

    // MARK: - The point of arming: the automatic sites then refuse

    func testSuspicionRaisedAtAUserInitiatedSiteMakesTheNextCorrectionRefuse() {
        // This is the whole chain #548 restores. A word delete desyncs the mirror; the
        // user types a misspelling and presses space; the correction that follows must
        // refuse rather than count against a mirror nobody flagged.
        let state = MirrorSyncState()
        state.observe(before: 40, after: 40, deleted: 7, inserted: 0)   // word delete, ignored
        XCTAssertTrue(state.isSuspect)

        XCTAssertEqual(
            MirrorGatedReplacement.check(
                mirrorSuspect: state.isSuspect, context: "le quee", word: "quee"
            ),
            .failed(reason: MirrorGatedReplacement.suspectReason)
        )
        XCTAssertFalse(
            AutoFullStop.shouldSubstitute(context: "le quee ", mirrorSuspect: state.isSuspect)
        )
    }
}
