// DictusCore/Tests/DictusCoreTests/InKeyboardEarlyCaptureTests.swift
// Tests for InKeyboardEarlyCapture — capture from the tap, keep or drop at the route
// decision (spike, #992 round 4).
import XCTest
@testable import DictusCore

final class InKeyboardEarlyCaptureTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_000_000)

    func testNoPongMeansTheAppDidNotAnswer() {
        XCTAssertFalse(InKeyboardEarlyCapture.appAnsweredTapPing(pingSentAt: now, lastPong: nil))
    }

    func testOnlyAPongAfterThisTapsPingCounts() {
        XCTAssertTrue(InKeyboardEarlyCapture.appAnsweredTapPing(pingSentAt: now, lastPong: now.addingTimeInterval(0.004)))
        XCTAssertFalse(InKeyboardEarlyCapture.appAnsweredTapPing(pingSentAt: now, lastPong: now.addingTimeInterval(-5)))
    }

    func testStartsOnlyForASilentAppThatHasNotClaimedTheSession() {
        XCTAssertTrue(InKeyboardEarlyCapture.shouldStartCapture(mayTakeColdTap: true, appAnsweredTapPing: false, sessionOwner: nil))
        XCTAssertFalse(InKeyboardEarlyCapture.shouldStartCapture(mayTakeColdTap: true, appAnsweredTapPing: true, sessionOwner: nil))
        XCTAssertFalse(InKeyboardEarlyCapture.shouldStartCapture(mayTakeColdTap: true, appAnsweredTapPing: false, sessionOwner: .app))
        XCTAssertFalse(InKeyboardEarlyCapture.shouldStartCapture(mayTakeColdTap: false, appAnsweredTapPing: false, sessionOwner: nil))
    }

    /// Device, 2026-11-23 12:55:37. The app is warm and records, the keyboard's last
    /// pong is 60.8 s old. Before: the stale pong read as "app cold", the keyboard opened
    /// its microphone at the tap, the app's engine was interrupted, the route said
    /// `inKeyboard` while the claim said `owner=app`, and nobody recorded. Now the app's
    /// claim (and its answer to this tap's ping) keeps the keyboard's microphone closed
    /// and the route agrees with the claim.
    func testAppOwnerWithAStalePongGetsNoKeyboardSessionAndNoInKeyboardRoute() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("stale-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let pingSentAt = now
        let stalePong = now.addingTimeInterval(-60.81)
        XCTAssertEqual(DictationSessionClaim.claim("S1", as: .app, in: directory), .app)
        let owner = DictationSessionClaim.current("S1", in: directory)

        // Even if the app's pong is lost, its claim alone keeps the microphone closed.
        let answered = InKeyboardEarlyCapture.appAnsweredTapPing(pingSentAt: pingSentAt, lastPong: stalePong)
        XCTAssertFalse(answered)
        XCTAssertFalse(InKeyboardEarlyCapture.shouldStartCapture(mayTakeColdTap: true, appAnsweredTapPing: answered, sessionOwner: owner))

        // The keyboard's status may still read "requested" at the end of the wait.
        let route = InKeyboardDictationRoute.decide(settingEnabled: true, appAnswered: false, systemMajorVersion: 26,
                                                    localeInstalled: true, sessionOwner: owner)
        XCTAssertEqual(route, .appIsRecording)
        XCTAssertEqual(InKeyboardEarlyCapture.resolve(route: route, claimOwner: owner), .drop)
    }

    /// Device, 2026-11-23 10:32:01. The app answered a ping when the keyboard appeared,
    /// then Pierre killed it. Before: the early capture stayed off on that old pong, and
    /// the tap opened the app. Now the tap's own ping goes unanswered, the keyboard opens
    /// its microphone after `tapPingWindow`, and the end of the wait routes in the
    /// keyboard, Full Access taken from the tap when iOS has torn the controller down.
    func testAppKilledAfterAnEarlierPongIsTakenInTheKeyboard() {
        let pongWhenTheKeyboardAppeared = now.addingTimeInterval(-8)
        let answered = InKeyboardEarlyCapture.appAnsweredTapPing(pingSentAt: now, lastPong: pongWhenTheKeyboardAppeared)
        XCTAssertFalse(answered)
        XCTAssertTrue(InKeyboardEarlyCapture.shouldStartCapture(mayTakeColdTap: true, appAnsweredTapPing: answered, sessionOwner: nil))
        let route = InKeyboardDictationRoute.decide(
            settingEnabled: true, appAnswered: false, systemMajorVersion: 26, localeInstalled: true,
            hasFullAccess: InKeyboardDictationRoute.fullAccess(current: nil, atTap: true), sessionOwner: nil
        )
        XCTAssertEqual(route, .inKeyboard)
        XCTAssertEqual(InKeyboardEarlyCapture.resolve(route: route, claimOwner: .keyboard), .keep)
    }

    func testFullAccessFallsBackToTheTapOnlyWhenTheControllerIsGone() {
        XCTAssertTrue(InKeyboardDictationRoute.fullAccess(current: nil, atTap: true))
        XCTAssertFalse(InKeyboardDictationRoute.fullAccess(current: false, atTap: true))
        XCTAssertFalse(InKeyboardDictationRoute.fullAccess(current: nil, atTap: nil))
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
        XCTAssertTrue(InKeyboardEarlyCapture.shouldStartCapture(mayTakeColdTap: true, appAnsweredTapPing: false, sessionOwner: nil))
        XCTAssertEqual(DictationSessionClaim.claim("S9", as: .app, in: directory), .app)
        let owner = DictationSessionClaim.claim("S9", as: .keyboard, in: directory)
        XCTAssertEqual(InKeyboardEarlyCapture.resolve(route: .inKeyboard, claimOwner: owner), .drop)
    }
}
