import XCTest
@testable import DictusCore

/// The return decision and the background-start refusal of a cold start whose audio session
/// is recovering (issue #853).
///
/// The hold itself rides `UIApplication.open` and a live coordinator, and the reset it waits
/// for only happens on a device. What can be pinned here is the decision: which starts hold
/// the foreground, for how long, and which may reach `engine.start()`.
final class ForegroundAudioRecoveryPolicyTests: XCTestCase {

    /// `AVAudioSessionErrorCodeMediaServicesFailed` (`'msrv'`), the code both of the
    /// 2026-10-28 failures carried on their first `setCategory`.
    private static let mediaServicesFailed = NSError(
        domain: NSOSStatusErrorDomain, code: 1_836_282_486,
        userInfo: [NSLocalizedDescriptionKey: "Media services failed"])

    /// `AVAudioSessionErrorCodeCannotInterruptOthers`, the code #515's capture carried.
    private static let cannotInterruptOthers = NSError(
        domain: NSOSStatusErrorDomain, code: 560_557_684,
        userInfo: [NSLocalizedDescriptionKey: "Session activation failed"])

    private func refused(by error: NSError) -> Result<Void, Error> {
        .failure(AudioSessionActivationFailure(step: .setCategory, error: error))
    }

    // MARK: - The return decision

    /// The capture: the first activation refused with `'msrv'`. The return holds instead of
    /// opening the host app at 250 ms, which is what sent the start to the background.
    func testAnActivationRefusedWithMsrvHoldsTheReturn() {
        XCTAssertEqual(AudioSessionActivationPolicy.fourCharacterCode(Self.mediaServicesFailed.code), "msrv")
        let needsRecovery = ForegroundAudioRecoveryPolicy.sessionNeedsRecovery(
            after: refused(by: Self.mediaServicesFailed), mediaServicesLost: false)
        XCTAssertTrue(needsRecovery)
        XCTAssertEqual(
            ForegroundAudioRecoveryPolicy.returnAtCeiling(sessionNeedsRecovery: needsRecovery),
            .hold(untilMilliseconds: ForegroundAudioRecoveryPolicy.recoveryHoldCeilingMilliseconds)
        )
    }

    /// The common path: the activation worked and the server is up. The return opens at the
    /// ceiling it always had, with no added delay.
    func testAnActivationThatWorkedReturnsAtTheCurrentCeiling() {
        let needsRecovery = ForegroundAudioRecoveryPolicy.sessionNeedsRecovery(
            after: .success(()), mediaServicesLost: false)
        XCTAssertFalse(needsRecovery)
        XCTAssertEqual(
            ForegroundAudioRecoveryPolicy.returnAtCeiling(sessionNeedsRecovery: needsRecovery),
            .openNow
        )
        XCTAssertEqual(ForegroundAudioRecoveryPolicy.recordingWaitCeilingMilliseconds, 250)
    }

    /// Any refused activation holds, not only `'msrv'`: the run retries it and may wait for a
    /// reset, and neither can end in a started engine once the app has left.
    func testAnyRefusedActivationHoldsTheReturn() {
        XCTAssertTrue(ForegroundAudioRecoveryPolicy.sessionNeedsRecovery(
            after: refused(by: Self.cannotInterruptOthers), mediaServicesLost: false))
    }

    /// A loss announced after an activation that worked: the run waits for the reset all the
    /// same (`AudioSessionActivationPolicy` checks the loss first), so the return holds too.
    func testAKnownLossHoldsTheReturnEvenAfterAnActivationThatWorked() {
        XCTAssertTrue(ForegroundAudioRecoveryPolicy.sessionNeedsRecovery(
            after: .success(()), mediaServicesLost: true))
    }

    /// The hold must outlast everything a recovering start can spend before `.recording`,
    /// or the capture's race is only moved: the retry, the full reset wait, the route wait.
    func testTheHoldCoversTheWholeRecoveryBudget() {
        let budget = AudioSessionActivationPolicy.retryDelayMilliseconds
            + AudioSessionActivationPolicy.mediaServicesResetTimeoutMilliseconds
            + AudioStartReadinessPolicy.inputRouteWaitMilliseconds
        XCTAssertGreaterThan(ForegroundAudioRecoveryPolicy.recoveryHoldCeilingMilliseconds, budget)
        // The capture's reset came after 2727 ms and 2788 ms.
        XCTAssertGreaterThan(ForegroundAudioRecoveryPolicy.recoveryHoldCeilingMilliseconds, 2788)
    }

    /// And it must end well before the keyboard's 15 s cold-start grace gives up on the start.
    func testTheHoldEndsInsideTheKeyboardsColdStartGrace() {
        XCTAssertLessThan(ForegroundAudioRecoveryPolicy.recoveryHoldCeilingMilliseconds, 15_000)
    }

    // MARK: - Starting the engine after a recovery

    /// The capture's second half: the session came back with DictusApp in the background, and
    /// `engine.start()` was refused with `2003329396`. It is not attempted any more.
    func testARecoveredSessionDoesNotStartTheEngineFromTheBackground() {
        XCTAssertFalse(ForegroundAudioRecoveryPolicy.mayStartEngine(afterRecovery: true, appState: .background))
    }

    /// A manual swipe goes through `.inactive` first, and iOS refuses the start there too.
    func testARecoveredSessionDoesNotStartTheEngineWhileInactive() {
        XCTAssertFalse(ForegroundAudioRecoveryPolicy.mayStartEngine(afterRecovery: true, appState: .inactive))
        XCTAssertFalse(ForegroundAudioRecoveryPolicy.mayStartEngine(afterRecovery: true, appState: .unknown))
    }

    /// Held in the foreground, the recovered start goes on to record.
    func testARecoveredSessionStartsTheEngineInTheForeground() {
        XCTAssertTrue(ForegroundAudioRecoveryPolicy.mayStartEngine(afterRecovery: true, appState: .active))
    }

    /// An ordinary start is not gated, whatever the app state: #311's last-chance start from
    /// the background keeps the behavior it had.
    func testAnOrdinaryStartIsNeverGated() {
        for state in [AppScenePhaseMarker.active, .inactive, .background, .unknown] {
            XCTAssertTrue(ForegroundAudioRecoveryPolicy.mayStartEngine(afterRecovery: false, appState: state))
        }
    }
}
