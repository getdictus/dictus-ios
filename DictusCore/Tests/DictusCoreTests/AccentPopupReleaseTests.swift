// DictusCore/Tests/DictusCoreTests/AccentPopupReleaseTests.swift
// Releasing a held letter without picking an accent types the letter, as Apple's does (#1089).
import XCTest
@testable import DictusCore

final class AccentPopupReleaseTests: XCTestCase {

    /// Apple's « E » key on an iPhone 17, French AZERTY: y 590 to 644, centre 617.
    private let bottom = 644.0, height = 54.0

    private func keeps(_ y: Double) -> Bool {
        AccentPopupRelease.keepsHeldLetter(fingerY: y, keyBottom: bottom, keyHeight: height)
    }

    /// The #1089 case: held past the popup's delay and lifted where it went down.
    func testAFingerStillOnTheKeyKeepsTheLetter() {
        XCTAssertTrue(keeps(617))
        XCTAssertTrue(keeps(590))
        XCTAssertTrue(keeps(644))
    }

    /// Up into the popup, or far above it, Apple's still types the letter.
    func testAFingerAboveTheKeyKeepsTheLetter() {
        XCTAssertTrue(keeps(560))  // on the popup
        XCTAssertTrue(keeps(500))  // above it
        XCTAssertTrue(keeps(300))  // in the host's text
    }

    /// Down, the letter holds to half a key below the key: Apple's typed E at 53 pt below
    /// the centre and nothing at 56.
    func testAFingerSlightlyBelowTheKeyKeepsTheLetter() {
        XCTAssertTrue(keeps(640))
        XCTAssertTrue(keeps(660))
        XCTAssertTrue(keeps(670))
        XCTAssertTrue(keeps(671))
    }

    func testAFingerHalfAKeyBelowTheKeyCancels() {
        XCTAssertFalse(keeps(673))
        XCTAssertFalse(keeps(680))
        XCTAssertFalse(keeps(760))
    }
}
