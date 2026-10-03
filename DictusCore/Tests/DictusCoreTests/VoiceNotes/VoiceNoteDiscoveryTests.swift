// DictusCore/Tests/DictusCoreTests/VoiceNotes/VoiceNoteDiscoveryTests.swift
// When the toolbar teaches the long press on ☰ that opens the voice note reader (#639).
//
// These tests mutate the real App Group suite, so setUp/tearDown remove the key.
import XCTest
@testable import DictusCore

final class VoiceNoteDiscoveryTests: XCTestCase {

    private var defaults: UserDefaults { AppGroup.defaults }

    override func setUp() {
        super.setUp()
        defaults.removeObject(forKey: SharedKeys.voiceNoteLongPressUsed)
    }

    override func tearDown() {
        defaults.removeObject(forKey: SharedKeys.voiceNoteLongPressUsed)
        super.tearDown()
    }

    func testTheHintIsOfferedWhileANoteWaitsAndTheGestureWasNeverUsed() {
        XCTAssertTrue(VoiceNoteDiscovery.offersHint(notesWaiting: 1, longPressUsed: false))
    }

    /// Nothing waiting: the gesture would only open the empty state.
    func testNoNoteWaitingMeansNoHint() {
        XCTAssertFalse(VoiceNoteDiscovery.offersHint(notesWaiting: 0, longPressUsed: false))
    }

    func testTheHintRetiresOnceTheGestureWasUsed() {
        XCTAssertFalse(VoiceNoteDiscovery.offersHint(notesWaiting: 3, longPressUsed: true))
    }

    /// Persisted in the App Group, set once and never cleared.
    func testTheFirstLongPressIsRememberedAndIdempotent() {
        XCTAssertFalse(VoiceNoteDiscovery.hasUsedLongPress)
        VoiceNoteDiscovery.noteLongPressUsed()
        VoiceNoteDiscovery.noteLongPressUsed()
        XCTAssertTrue(VoiceNoteDiscovery.hasUsedLongPress)
        XCTAssertTrue(defaults.bool(forKey: SharedKeys.voiceNoteLongPressUsed))
    }
}
