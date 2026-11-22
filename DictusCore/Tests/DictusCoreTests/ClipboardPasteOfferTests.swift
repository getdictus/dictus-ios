// DictusCore/Tests/DictusCoreTests/ClipboardPasteOfferTests.swift
// When the keyboard toolbar offers Paste for the clipboard (#634).
import XCTest
@testable import DictusCore

final class ClipboardPasteOfferTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!
    private let start = Date(timeIntervalSince1970: 1_000_000)

    override func setUpWithError() throws {
        suiteName = "ClipboardPasteOfferTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func text(_ change: Int) -> PasteboardSnapshot {
        PasteboardSnapshot(changeCount: change, hasInsertableContent: true)
    }

    private func offered(_ snapshot: PasteboardSnapshot,
                         fullAccess: Bool = true,
                         at date: Date? = nil,
                         offer: ClipboardPasteOffer? = nil) -> Bool {
        (offer ?? ClipboardPasteOffer(defaults: defaults))
            .isOffered(hasFullAccess: fullAccess, pasteboard: snapshot, now: date ?? start)
    }

    func testANewCopyIsOffered() {
        XCTAssertTrue(offered(text(7)))
    }

    /// A first copy can carry change count 0, which must not read as "already seen".
    func testChangeCountZeroIsStillANewCopy() {
        XCTAssertTrue(offered(text(0)))
    }

    func testWithoutFullAccessThePasteboardIsNeverRead() {
        let offer = ClipboardPasteOffer(defaults: defaults)
        let shown = offer.isOffered(
            hasFullAccess: false,
            pasteboard: { XCTFail("pasteboard read without Full Access"); return self.text(7) }()
        )
        XCTAssertFalse(shown)
    }

    func testAnImageOnlyClipboardIsNotOffered() {
        let offer = ClipboardPasteOffer(defaults: defaults)
        XCTAssertFalse(offered(PasteboardSnapshot(changeCount: 7, hasInsertableContent: false), offer: offer))
        XCTAssertEqual(offer.lastSeenChangeCount, 7, "seen, so the per-keystroke check can stop at the count")
    }

    func testTheOfferHoldsInsideTheFreshnessWindow() {
        XCTAssertTrue(offered(text(7)))
        XCTAssertTrue(offered(text(7), at: start.addingTimeInterval(ClipboardPasteOffer.freshness - 1)))
    }

    func testTheOfferExpiresAfterTheFreshnessWindow() {
        XCTAssertTrue(offered(text(7)))
        XCTAssertFalse(offered(text(7), at: start.addingTimeInterval(ClipboardPasteOffer.freshness)))
    }

    /// The window starts when the keyboard first notices the copy, so a newer copy
    /// restarts it.
    func testANewerCopyRestartsTheWindow() {
        XCTAssertTrue(offered(text(7)))
        let later = start.addingTimeInterval(ClipboardPasteOffer.freshness + 60)
        XCTAssertFalse(offered(text(7), at: later))
        XCTAssertTrue(offered(text(8), at: later))
    }

    func testAPastedCopyIsNotOfferedAgain() {
        let offer = ClipboardPasteOffer(defaults: defaults)
        XCTAssertTrue(offered(text(7), offer: offer))
        offer.notePasted(changeCount: 7)
        XCTAssertFalse(offered(text(7), offer: offer))
        XCTAssertTrue(offered(text(8), offer: offer))
    }

    func testExpiryIsTheFirstSightingPlusTheWindow() {
        let offer = ClipboardPasteOffer(defaults: defaults)
        XCTAssertNil(offer.expiry())
        XCTAssertTrue(offered(text(7), offer: offer))
        XCTAssertEqual(offer.expiry(), start.addingTimeInterval(ClipboardPasteOffer.freshness))
        XCTAssertEqual(offer.lastSeenChangeCount, 7)
    }

    /// The keyboard process restarts between host apps; a fresh instance over the
    /// same store must remember both the sighting and the paste.
    func testStateSurvivesANewInstance() {
        XCTAssertTrue(offered(text(7)))
        let afterWindow = start.addingTimeInterval(ClipboardPasteOffer.freshness + 1)
        XCTAssertFalse(offered(text(7), at: afterWindow, offer: ClipboardPasteOffer(defaults: defaults)))

        ClipboardPasteOffer(defaults: defaults).notePasted(changeCount: 9)
        XCTAssertFalse(offered(text(9), offer: ClipboardPasteOffer(defaults: defaults)))
    }
}
