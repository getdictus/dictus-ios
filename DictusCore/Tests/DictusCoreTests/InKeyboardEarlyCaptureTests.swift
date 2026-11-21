// DictusCore/Tests/DictusCoreTests/InKeyboardEarlyCaptureTests.swift
// Tests for InKeyboardEarlyCapture — capture from the tap, keep or drop at the route
// decision (spike, #992 round 4).
import XCTest
@testable import DictusCore

final class InKeyboardEarlyCaptureTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_000_000)

    func testNoPongMeansTheAppIsNotKnownToRun() {
        XCTAssertFalse(InKeyboardEarlyCapture.appAnsweredRecently(lastPong: nil, now: now))
    }

    func testFreshPongVouchesForTheApp() {
        XCTAssertTrue(InKeyboardEarlyCapture.appAnsweredRecently(lastPong: now.addingTimeInterval(-5), now: now))
        XCTAssertTrue(InKeyboardEarlyCapture.appAnsweredRecently(lastPong: now.addingTimeInterval(-30), now: now))
    }

    func testStalePongDoesNot() {
        XCTAssertFalse(InKeyboardEarlyCapture.appAnsweredRecently(lastPong: now.addingTimeInterval(-31), now: now))
        XCTAssertFalse(InKeyboardEarlyCapture.appAnsweredRecently(lastPong: now.addingTimeInterval(5), now: now))
    }

    func testStartsAtTheTapOnlyForAColdApp() {
        XCTAssertTrue(InKeyboardEarlyCapture.shouldStartAtTap(mayTakeColdTap: true, appAnsweredRecently: false))
        XCTAssertFalse(InKeyboardEarlyCapture.shouldStartAtTap(mayTakeColdTap: true, appAnsweredRecently: true))
        XCTAssertFalse(InKeyboardEarlyCapture.shouldStartAtTap(mayTakeColdTap: false, appAnsweredRecently: false))
    }

    /// The case the feature exists for: the keyboard takes the session, the words said
    /// during the 500 ms wait are already in the buffer.
    func testKeyboardOwnedSessionKeepsTheBuffer() {
        XCTAssertEqual(InKeyboardEarlyCapture.resolve(route: .inKeyboard, claimOwner: .keyboard), .keep)
        // A claim that could not be written: the keyboard still dictates, as before.
        XCTAssertEqual(InKeyboardEarlyCapture.resolve(route: .inKeyboard, claimOwner: nil), .keep)
    }

    /// The late answer: the app claimed the session first, it records; the keyboard's
    /// buffer must go, or the same words would be inserted twice.
    func testAppOwnedSessionDropsTheBuffer() {
        XCTAssertEqual(InKeyboardEarlyCapture.resolve(route: .inKeyboard, claimOwner: .app), .drop)
        XCTAssertEqual(InKeyboardEarlyCapture.resolve(route: .appIsRecording, claimOwner: nil), .drop)
    }

    func testURLFallbackDropsTheBuffer() {
        XCTAssertEqual(InKeyboardEarlyCapture.resolve(route: .openAppURL, claimOwner: nil), .drop)
        XCTAssertEqual(InKeyboardEarlyCapture.resolve(route: .openAppURL, claimOwner: .keyboard), .drop)
    }

    /// End to end with the real claim: keyboard taps (early capture starts), the app
    /// answers at 525 ms and claims first; the route then drops the buffer.
    func testLateAppClaimDropsTheEarlyCapture() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("early-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        XCTAssertTrue(InKeyboardEarlyCapture.shouldStartAtTap(mayTakeColdTap: true, appAnsweredRecently: false))
        XCTAssertEqual(DictationSessionClaim.claim("S9", as: .app, in: directory), .app)
        let owner = DictationSessionClaim.claim("S9", as: .keyboard, in: directory)
        XCTAssertEqual(InKeyboardEarlyCapture.resolve(route: .inKeyboard, claimOwner: owner), .drop)
    }
}
