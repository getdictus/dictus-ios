// DictusCore/Tests/DictusCoreTests/DictusKeyboardPresenceTests.swift
// Reading the Dictus keyboard's presence from the keyboard list (#713).
import XCTest
@testable import DictusCore

final class DictusKeyboardPresenceTests: XCTestCase {

    func testDictusInTheListIsListedUnderItsIdentifier() {
        let presence = DictusKeyboardPresence(inputModeIdentifiers: [
            "fr_FR@sw=AZERTY-French;hw=Automatic",
            "com.pivi.dictus.keyboard",
            "emoji@sw=Emoji"
        ])
        XCTAssertEqual(presence, .listed(identifier: "com.pivi.dictus.keyboard"))
        XCTAssertTrue(presence.isListed)
    }

    /// The measured case of #713: three keyboards left, Dictus removed.
    func testAListWithoutDictusIsNotListed() {
        let presence = DictusKeyboardPresence(inputModeIdentifiers: [
            "fr_FR@sw=AZERTY-French;hw=Automatic",
            "en_US@sw=QWERTY;hw=Automatic",
            "emoji@sw=Emoji"
        ])
        XCTAssertEqual(presence, .notListed)
        XCTAssertFalse(presence.isListed)
    }

    /// iOS never lets the last keyboard go, so an empty list says nothing about Dictus and
    /// must not revert the onboarding step.
    func testAnEmptyListIsUnreadableNotAbsent() {
        let presence = DictusKeyboardPresence(inputModeIdentifiers: [])
        XCTAssertEqual(presence, .unreadable)
        XCTAssertFalse(presence.isListed)
    }

    func testAnotherAppsKeyboardIsNotTakenForDictus() {
        XCTAssertEqual(
            DictusKeyboardPresence(inputModeIdentifiers: ["com.example.dictation.keyboard"]),
            .notListed
        )
    }
}
