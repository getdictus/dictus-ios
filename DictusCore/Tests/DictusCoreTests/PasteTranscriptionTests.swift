// DictusCore/Tests/DictusCoreTests/PasteTranscriptionTests.swift
// The paste pill (#881): its Experiments switch, the channel's ten minutes, and the
// unclaimed hand-off that is no longer typed on its own.

import XCTest
@testable import DictusCore

final class PasteTranscriptionTests: XCTestCase {

    /// A suite of its own: these tests write the keys the app and the keyboard write.
    private let suiteName = "dictus.tests.pasteTranscription"
    private var defaults = UserDefaults.standard
    private let storedAt = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUpWithError() throws {
        try super.setUpWithError()
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func settings(_ channel: BuildChannel) -> KeyboardFeatureSettings {
        KeyboardFeatureSettings(store: defaults, channel: channel)
    }

    /// What `handOffToKeyboard` leaves in the App Group for a keyboard to claim.
    private func handOff(_ raw: String, at date: Date) {
        defaults.set(raw, forKey: SharedKeys.lastTranscription)
        defaults.set(Data("{}".utf8), forKey: SharedKeys.lastTranscriptionPolicy)
        defaults.set("token", forKey: SharedKeys.handoffToken)
        defaults.set(date.timeIntervalSince1970, forKey: SharedKeys.lastTranscriptionTimestamp)
    }

    // MARK: - The switch

    func testTheSwitchIsOffByDefaultAndStoresNothing() {
        XCTAssertEqual(SharedKeys.keyboardPasteTranscription, "dictus.keyboard.pasteTranscription")
        XCTAssertFalse(KeyboardFeatureSettings.Defaults.pasteTranscription)
        XCTAssertFalse(settings(.testBuild).isPasteTranscriptionEffective)
        XCTAssertFalse(settings(.appStore).isPasteTranscriptionEffective)
        XCTAssertNil(defaults.object(forKey: SharedKeys.keyboardPasteTranscription))
    }

    func testOnATestBuildTheSwitchActs() {
        settings(.testBuild).pasteTranscription = true
        XCTAssertTrue(settings(.testBuild).isPasteTranscriptionEffective)
    }

    /// The App Store build has no Experiments page, so a value a TestFlight build stored
    /// is kept and ignored there.
    func testTheAppStoreBuildIgnoresAStoredOn() {
        settings(.testBuild).pasteTranscription = true
        XCTAssertTrue(settings(.appStore).pasteTranscription, "the choice is kept")
        XCTAssertFalse(settings(.appStore).isPasteTranscriptionEffective)
    }

    // MARK: - The channel's ten minutes

    func testTheTextIsPasteableForTenMinutesFromWhenItWasStored() {
        RecoveredTranscriptionChannel.note(.refused("Rappelle-moi demain."), in: defaults, now: storedAt)

        XCTAssertEqual(
            RecoveredTranscriptionChannel.pasteable(in: defaults, now: storedAt.addingTimeInterval(599)),
            "Rappelle-moi demain."
        )
        XCTAssertEqual(
            RecoveredTranscriptionChannel.remainingPasteTime(in: defaults, now: storedAt.addingTimeInterval(60)), 540
        )
        XCTAssertNil(RecoveredTranscriptionChannel.pasteable(in: defaults, now: storedAt.addingTimeInterval(600)))
    }

    /// Past the ten minutes the pill goes and the text stays, for DictusApp's card.
    func testAnExpiredTextStaysInTheChannel() {
        RecoveredTranscriptionChannel.note(.refused("text"), in: defaults, now: storedAt)
        let later = storedAt.addingTimeInterval(3600)

        XCTAssertEqual(RecoveredTranscriptionChannel.offer(in: defaults, pastes: true, now: later), RecoveredTranscriptionOffer.none)
        XCTAssertEqual(RecoveredTranscriptionChannel.current(in: defaults), "text")
    }

    /// A text stored before the pill existed has no time, and is never offered for pasting.
    func testATextWithNoStoredTimeIsNotPasteable() {
        defaults.set("old", forKey: SharedKeys.recoveredTranscription)

        XCTAssertNil(RecoveredTranscriptionChannel.pasteable(in: defaults, now: storedAt))
        XCTAssertEqual(RecoveredTranscriptionChannel.offer(in: defaults, pastes: false, now: storedAt), .openInApp)
    }

    func testClearingDropsTheTime() {
        RecoveredTranscriptionChannel.note(.refused("text"), in: defaults, now: storedAt)

        RecoveredTranscriptionChannel.clear(in: defaults)

        XCTAssertNil(defaults.object(forKey: SharedKeys.recoveredTranscriptionStoredAt))
        XCTAssertNil(RecoveredTranscriptionChannel.remainingPasteTime(in: defaults, now: storedAt))
    }

    /// Switch off, the #860 banner as it was: no time limit, whatever the age.
    func testTheSwitchPicksBetweenTheBannerAndThePill() {
        RecoveredTranscriptionChannel.note(.refused("text"), in: defaults, now: storedAt)
        let soon = storedAt.addingTimeInterval(5)
        let muchLater = storedAt.addingTimeInterval(86_400)

        XCTAssertEqual(RecoveredTranscriptionChannel.offer(in: defaults, pastes: true, now: soon), .paste)
        XCTAssertEqual(RecoveredTranscriptionChannel.offer(in: defaults, pastes: false, now: soon), .openInApp)
        XCTAssertEqual(RecoveredTranscriptionChannel.offer(in: defaults, pastes: false, now: muchLater), .openInApp)
    }

    func testNothingWaitingOffersNothing() {
        XCTAssertEqual(RecoveredTranscriptionChannel.offer(in: defaults, pastes: true, now: storedAt), RecoveredTranscriptionOffer.none)
        XCTAssertEqual(RecoveredTranscriptionChannel.offer(in: defaults, pastes: false, now: storedAt), RecoveredTranscriptionOffer.none)
    }

    // MARK: - #881: the unclaimed hand-off

    /// The path #881 filed: the raw is handed off, iOS kills the keyboard before
    /// `transcriptionReady` arrives, and a keyboard opens minutes later in another app.
    /// With the pill on it is offered, never typed.
    func testAStaleUnclaimedRawGoesToThePillNotIntoTheField() {
        handOff("Texte dicté.", at: storedAt)
        let threeMinutesLater = storedAt.addingTimeInterval(180)

        XCTAssertEqual(
            UnclaimedHandoff.disposition(
                handedOffAt: UnclaimedHandoff.handedOffAt(in: defaults), now: threeMinutesLater, pastes: true
            ),
            .offer
        )
    }

    /// Switch off, today's behaviour: every unclaimed raw is typed.
    func testSwitchOffTheUnclaimedRawIsStillTyped() {
        let threeMinutesLater = storedAt.addingTimeInterval(180)

        XCTAssertEqual(UnclaimedHandoff.disposition(handedOffAt: storedAt, now: threeMinutesLater, pastes: false), .type)
        XCTAssertEqual(UnclaimedHandoff.disposition(handedOffAt: nil, now: threeMinutesLater, pastes: false), .type)
    }

    /// The case worth keeping: a dropped post while the keyboard stayed on the field.
    func testAFreshUnclaimedRawIsStillTyped() {
        XCTAssertEqual(UnclaimedHandoff.disposition(handedOffAt: storedAt, now: storedAt.addingTimeInterval(2), pastes: true), .type)
        XCTAssertEqual(UnclaimedHandoff.disposition(handedOffAt: storedAt, now: storedAt.addingTimeInterval(5), pastes: true), .type)
        XCTAssertEqual(UnclaimedHandoff.disposition(handedOffAt: storedAt, now: storedAt.addingTimeInterval(5.1), pastes: true), .offer)
    }

    /// No hand-off time, or one in the future: the age is unknown, so it is not typed.
    func testAnUnknownAgeIsNotTyped() {
        XCTAssertEqual(UnclaimedHandoff.disposition(handedOffAt: nil, now: storedAt, pastes: true), .offer)
        XCTAssertEqual(
            UnclaimedHandoff.disposition(handedOffAt: storedAt.addingTimeInterval(60), now: storedAt, pastes: true), .offer
        )
    }

    /// DictusApp's watchdog gives up on the raw first: it moves the raw to the pill and
    /// leaves nothing for a later keyboard to claim.
    func testTheAppTimeoutMovesTheUnclaimedRawToThePill() {
        handOff("Texte dicté.", at: storedAt)
        let timedOut = storedAt.addingTimeInterval(20)

        XCTAssertEqual(UnclaimedHandoff.withdraw(in: defaults, now: timedOut), "Texte dicté.")

        XCTAssertNil(UnclaimedHandoff.waitingRaw(in: defaults), "no keyboard can claim it any more")
        XCTAssertNil(defaults.string(forKey: SharedKeys.lastTranscription))
        XCTAssertNil(defaults.data(forKey: SharedKeys.lastTranscriptionPolicy))
        XCTAssertNil(defaults.string(forKey: SharedKeys.handoffToken))
        XCTAssertEqual(
            RecoveredTranscriptionChannel.offer(in: defaults, pastes: true, now: timedOut.addingTimeInterval(599)), .paste
        )
        XCTAssertEqual(RecoveredTranscriptionChannel.pasteable(in: defaults, now: timedOut), "Texte dicté.")
    }

    /// A dictation finished inside DictusApp writes the raw with no policy. It is not a
    /// hand-off, and the watchdog leaves it alone.
    func testTheAppTimeoutLeavesAnInAppDictationAlone() {
        defaults.set("in app", forKey: SharedKeys.lastTranscription)

        XCTAssertNil(UnclaimedHandoff.withdraw(in: defaults, now: storedAt))
        XCTAssertEqual(defaults.string(forKey: SharedKeys.lastTranscription), "in app")
        XCTAssertNil(RecoveredTranscriptionChannel.current(in: defaults))
    }
}
