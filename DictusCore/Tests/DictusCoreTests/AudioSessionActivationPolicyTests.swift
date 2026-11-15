import XCTest
@testable import DictusCore

/// Coverage for the session-activation rule of a dictation start (issue #775).
///
/// `configureAudioSession` and the start it gates are `@MainActor` and talk to a live
/// `AVAudioSession`; a refused activation needs the audio server to misbehave, which only
/// a device produces. The decision is the part that can be pinned here.
final class AudioSessionActivationPolicyTests: XCTestCase {

    // MARK: - The ordinary start

    func testAnActivatedSessionStartsRecording() {
        XCTAssertEqual(
            AudioSessionActivationPolicy.decide(
                activated: true, failedAttempts: 0, mediaServicesLost: false, hasWaitedForReset: false),
            .startRecording
        )
    }

    /// A retry that worked starts like any other.
    func testARetryThatActivatedStartsRecording() {
        XCTAssertEqual(
            AudioSessionActivationPolicy.decide(
                activated: true, failedAttempts: 1, mediaServicesLost: false, hasWaitedForReset: false),
            .startRecording
        )
    }

    // MARK: - The 2026-10-22 capture

    /// The first tap: activation failed, no loss observed. Before #775 this went straight to
    /// the route wait and the engine rebuild. Now it activates once more.
    func testAFirstFailedActivationRetriesInsteadOfStarting() {
        XCTAssertEqual(
            AudioSessionActivationPolicy.decide(
                activated: false, failedAttempts: 1, mediaServicesLost: false, hasWaitedForReset: false),
            .retryActivation(afterMilliseconds: AudioSessionActivationPolicy.retryDelayMilliseconds)
        )
    }

    /// The retry failed too, with no loss observed: wait for a reset before giving up. The
    /// capture's reset came one second after the failure, with no loss line before it.
    func testASecondFailedActivationWaitsForAReset() {
        XCTAssertEqual(
            AudioSessionActivationPolicy.decide(
                activated: false, failedAttempts: 2, mediaServicesLost: false, hasWaitedForReset: false),
            .waitForMediaServicesReset(
                timeoutMilliseconds: AudioSessionActivationPolicy.mediaServicesResetTimeoutMilliseconds)
        )
    }

    /// No failed activation ever reaches `.startRecording`, whatever the counters say.
    func testAFailedActivationNeverStartsRecording() {
        for attempts in 0...4 {
            for lost in [false, true] {
                for waited in [false, true] {
                    XCTAssertNotEqual(
                        AudioSessionActivationPolicy.decide(
                            activated: false, failedAttempts: attempts,
                            mediaServicesLost: lost, hasWaitedForReset: waited),
                        .startRecording,
                        "attempts=\(attempts) lost=\(lost) waited=\(waited)"
                    )
                }
            }
        }
    }

    // MARK: - The lost → reset window

    /// The audio server is down: retrying now would fail for the same reason, so wait for it.
    func testALostAudioServerWaitsForTheReset() {
        XCTAssertEqual(
            AudioSessionActivationPolicy.decide(
                activated: false, failedAttempts: 1, mediaServicesLost: true, hasWaitedForReset: false),
            .waitForMediaServicesReset(
                timeoutMilliseconds: AudioSessionActivationPolicy.mediaServicesResetTimeoutMilliseconds)
        )
    }

    /// A loss observed after the ordinary retry still gets its wait: the retry was spent
    /// against a dead server, which is the case the wait exists for.
    func testALossSeenAfterTheRetryStillWaitsOnce() {
        XCTAssertEqual(
            AudioSessionActivationPolicy.decide(
                activated: false, failedAttempts: 2, mediaServicesLost: true, hasWaitedForReset: false),
            .waitForMediaServicesReset(
                timeoutMilliseconds: AudioSessionActivationPolicy.mediaServicesResetTimeoutMilliseconds)
        )
    }

    /// The first activation worked, then the server was lost during the permission await
    /// (CodeRabbit on PR #777). That activation is stale: wait for the reset.
    func testALossAfterASuccessfulActivationStillWaitsForTheReset() {
        XCTAssertEqual(
            AudioSessionActivationPolicy.decide(
                activated: true, failedAttempts: 0, mediaServicesLost: true, hasWaitedForReset: false),
            .waitForMediaServicesReset(
                timeoutMilliseconds: AudioSessionActivationPolicy.mediaServicesResetTimeoutMilliseconds)
        )
    }

    /// The reset came and the activation after it worked: start.
    func testAnActivationAfterTheResetStartsRecording() {
        XCTAssertEqual(
            AudioSessionActivationPolicy.decide(
                activated: true, failedAttempts: 1, mediaServicesLost: false, hasWaitedForReset: true),
            .startRecording
        )
    }

    /// The reset came, and the activation after it failed: that was the one retry.
    func testAFailureAfterTheResetFails() {
        XCTAssertEqual(
            AudioSessionActivationPolicy.decide(
                activated: false, failedAttempts: 2, mediaServicesLost: false, hasWaitedForReset: true),
            .fail
        )
    }

    /// The wait timed out with the server still down: no second wait.
    func testAResetThatNeverCameFails() {
        XCTAssertEqual(
            AudioSessionActivationPolicy.decide(
                activated: false, failedAttempts: 2, mediaServicesLost: true, hasWaitedForReset: true),
            .fail
        )
    }

    /// A loss iOS never followed with a reset leaves the flag raised. Once the wait is
    /// spent, an activation that worked is the evidence: start, never "tap again" (#775).
    func testAnActivationAfterAResetThatNeverCameStartsRecording() {
        XCTAssertEqual(
            AudioSessionActivationPolicy.decide(
                activated: true, failedAttempts: 0, mediaServicesLost: true, hasWaitedForReset: true),
            .startRecording
        )
    }

    /// The wait is bounded inside the keyboard's 15 s cold-start grace, so a parked start
    /// is resolved by the app before the keyboard's watchdog gives up on it.
    func testTheWorstCaseWaitFitsTheKeyboardGrace() {
        let worstCase = AudioSessionActivationPolicy.retryDelayMilliseconds
            + AudioSessionActivationPolicy.mediaServicesResetTimeoutMilliseconds
        XCTAssertLessThan(worstCase, 15_000)
    }

    // MARK: - A reset that outlasts the wait (#899)

    /// The 2026-11-04 capture: the reset wait ran out, the activation after it was refused,
    /// and the keyboard was still on `requested`. Keep waiting for the reset, once.
    func testAKeyboardStillWaitingAwaitsALateReset() {
        XCTAssertEqual(
            AudioSessionActivationPolicy.decide(
                activated: false, failedAttempts: 3, mediaServicesLost: true, hasWaitedForReset: true,
                resetSeen: false, keyboardStillWaiting: true, hasAwaitedLateReset: false),
            .awaitLateMediaServicesReset(
                timeoutMilliseconds: AudioSessionActivationPolicy.lateMediaServicesResetTimeoutMilliseconds)
        )
    }

    /// Nobody is waiting (an in-app start, a keyboard that gave up, DictusApp in the
    /// background): the #775 rule, "tap again" at once.
    func testNobodyWaitingFailsAsBefore() {
        XCTAssertEqual(
            AudioSessionActivationPolicy.decide(
                activated: false, failedAttempts: 3, mediaServicesLost: false, hasWaitedForReset: true,
                resetSeen: false, keyboardStillWaiting: false, hasAwaitedLateReset: false),
            .fail
        )
    }

    /// The reset came during the wait and the session still refused: waiting longer cannot fix it.
    func testARefusalAfterAResetStillFails() {
        XCTAssertEqual(
            AudioSessionActivationPolicy.decide(
                activated: false, failedAttempts: 3, mediaServicesLost: false, hasWaitedForReset: true,
                resetSeen: true, keyboardStillWaiting: true, hasAwaitedLateReset: false),
            .fail
        )
    }

    /// One late wait per start, never a second: the retry is bounded, not a loop.
    func testTheLateWaitIsSpentOnlyOnce() {
        XCTAssertEqual(
            AudioSessionActivationPolicy.decide(
                activated: false, failedAttempts: 4, mediaServicesLost: true, hasWaitedForReset: true,
                resetSeen: false, keyboardStillWaiting: true, hasAwaitedLateReset: true),
            .fail
        )
    }

    /// The retry after a late reset that activates starts the engine.
    func testTheActivationAfterALateResetStartsRecording() {
        XCTAssertEqual(
            AudioSessionActivationPolicy.decide(
                activated: true, failedAttempts: 3, mediaServicesLost: false, hasWaitedForReset: true,
                resetSeen: true, keyboardStillWaiting: true, hasAwaitedLateReset: true),
            .startRecording
        )
    }

    /// Before the first reset wait has been spent, a waiting keyboard changes nothing: the
    /// warm path and the #775 / #853 recoveries take the same steps as before.
    func testAWaitingKeyboardDoesNotChangeTheStepsBeforeTheWait() {
        for attempts in 0...2 {
            for lost in [false, true] {
                for activated in [false, true] {
                    XCTAssertEqual(
                        AudioSessionActivationPolicy.decide(
                            activated: activated, failedAttempts: attempts, mediaServicesLost: lost,
                            hasWaitedForReset: false, keyboardStillWaiting: true),
                        AudioSessionActivationPolicy.decide(
                            activated: activated, failedAttempts: attempts, mediaServicesLost: lost,
                            hasWaitedForReset: false),
                        "activated=\(activated) attempts=\(attempts) lost=\(lost)"
                    )
                }
            }
        }
    }

    /// Both waits and the retry still fit the keyboard's 15 s cold-start grace.
    func testTheWorstCaseWithTheLateWaitFitsTheKeyboardGrace() {
        let worstCase = AudioSessionActivationPolicy.retryDelayMilliseconds
            + AudioSessionActivationPolicy.mediaServicesResetTimeoutMilliseconds
            + AudioSessionActivationPolicy.lateMediaServicesResetTimeoutMilliseconds
        XCTAssertLessThan(worstCase, 15_000)
    }

    // MARK: - The status in the log

    /// `AVAudioSessionErrorCodeCannotInterruptOthers`, the code #515's capture carried.
    func testAPrintableStatusCarriesItsFourCharacterCode() {
        XCTAssertEqual(AudioSessionActivationPolicy.statusDescription(560_557_684), "560557684 '!int'")
    }

    /// `AVAudioSessionErrorCodeMediaServicesFailed`.
    func testTheMediaServicesFailedStatusSpellsMsrv() {
        XCTAssertEqual(AudioSessionActivationPolicy.fourCharacterCode(1_836_282_486), "msrv")
    }

    func testANegativeStatusIsJustItsNumber() {
        XCTAssertEqual(AudioSessionActivationPolicy.statusDescription(-50), "-50")
    }

    func testANonPrintableStatusIsJustItsNumber() {
        XCTAssertNil(AudioSessionActivationPolicy.fourCharacterCode(1))
        XCTAssertEqual(AudioSessionActivationPolicy.statusDescription(1), "1")
    }
}
