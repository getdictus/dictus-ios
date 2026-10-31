// DictusCore/Tests/DictusCoreTests/RecoveredTranscriptionChannelTests.swift
// The pending state behind the keyboard's "Dictation interrupted" banner (#860).

import XCTest
@testable import DictusCore

final class RecoveredTranscriptionChannelTests: XCTestCase {

    /// A suite of its own: the shared App Group suite is live state on a developer
    /// machine, and these tests write the key the keyboard writes.
    private let suiteName = "dictus.tests.recoveredTranscriptionChannel"
    private var defaults = UserDefaults.standard

    override func setUpWithError() throws {
        try super.setUpWithError()
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    /// The device capture that filed #860: an interrupted dictation transcribed on
    /// resume, refused `off-screen`, `outcome=refused-with-text`. Its text is pending.
    func testARefusedDictationLeavesItsTextPending() {
        RecoveredTranscriptionChannel.note(.refused("Rappelle-moi demain."), in: defaults)

        XCTAssertEqual(RecoveredTranscriptionChannel.current(in: defaults), "Rappelle-moi demain.")
    }

    func testAnInsertedDictationLeavesNothingPending() {
        RecoveredTranscriptionChannel.note(.inserted("Hello there. "), in: defaults)

        XCTAssertNil(RecoveredTranscriptionChannel.current(in: defaults))
    }

    /// A dictation that produced nothing has no text to recover; its own error message
    /// is what tells the user.
    func testADictationThatProducedNothingLeavesNothingPending() {
        RecoveredTranscriptionChannel.note(.nothing, in: defaults)

        XCTAssertNil(RecoveredTranscriptionChannel.current(in: defaults))
    }

    /// An insertion does not erase a refusal it is not about: the banner goes only on a
    /// new dictation's start or on opening the text.
    func testAnInsertionDoesNotClearAnEarlierRefusal() {
        RecoveredTranscriptionChannel.note(.refused("first"), in: defaults)
        RecoveredTranscriptionChannel.note(.inserted("second"), in: defaults)

        XCTAssertEqual(RecoveredTranscriptionChannel.current(in: defaults), "first")
    }

    func testStartingADictationClearsThePendingText() {
        RecoveredTranscriptionChannel.note(.refused("text"), in: defaults)

        RecoveredTranscriptionChannel.clear(in: defaults)

        XCTAssertNil(RecoveredTranscriptionChannel.current(in: defaults))
    }

    /// Opening the text from the banner hands it to the app once and drops it.
    func testOpeningTheTextReturnsItAndClearsIt() {
        RecoveredTranscriptionChannel.note(.refused("text"), in: defaults)

        XCTAssertEqual(RecoveredTranscriptionChannel.take(in: defaults), "text")
        XCTAssertNil(RecoveredTranscriptionChannel.current(in: defaults))
        XCTAssertNil(RecoveredTranscriptionChannel.take(in: defaults))
    }

    /// Survives what clears the hand-off's own answer: the app's next hand-off and its
    /// launch sweep both call `PolishedTextChannel.clear`, and the banner must outlive both.
    func testClearingThePolishedTextChannelKeepsThePendingText() {
        PolishedTextChannel.record(.refused("text"), in: defaults)
        RecoveredTranscriptionChannel.note(.refused("text"), in: defaults)

        PolishedTextChannel.clear(in: defaults)

        XCTAssertEqual(RecoveredTranscriptionChannel.current(in: defaults), "text")
    }

    func testTheBannerOpensTheTranscriptionIntent() throws {
        let url = try XCTUnwrap(KeyboardOpenURL.url(intent: .transcription))
        XCTAssertEqual(url.absoluteString, "dictus://open?source=keyboard&intent=transcription")
        XCTAssertEqual(KeyboardOpenURL.intent(from: url), .transcription)
    }
}
