import XCTest
@testable import DictusCore

/// Coverage for the condition that decides both the swipe-back overlay and the
/// auto-return (issues #23, #567).
///
/// These tests exist because the gates themselves live in `DictusApp.handleIncomingURL`,
/// which `swift test` cannot reach: it is a SwiftUI `App`, it reads a live
/// `AVAudioEngine` through `DictationCoordinator.shared`, and it only runs on a device
/// with a keyboard extension attached. The rule *behind* the gates is three booleans in
/// and one case out, and it is where #567 lived, so it is the part worth pinning down.
///
/// What they do not cover, and what only the device protocol on the PR can: that both
/// gates in `DictusApp.swift` actually read `owesReturnToHost`.
final class HostForegroundDebtTests: XCTestCase {

    // MARK: - The three cases

    func testAKeyboardURLOnAProcessThatHasNeverBeenActiveIsAColdStart() {
        // `isEngineRunning` is irrelevant here and both values must agree: a process
        // that has never been foreground has no engine worth asking about.
        for isEngineRunning in [true, false] {
            XCTAssertEqual(
                HostForegroundDebt.resolve(
                    isFromKeyboard: true,
                    hasBeenActive: false,
                    isEngineRunning: isEngineRunning
                ),
                .coldStart,
                "isEngineRunning=\(isEngineRunning) should not change a cold start"
            )
        }
    }

    func testAWarmProcessWithADeadEngineIsAnEngineDeadRestart() {
        // The #567 path, and the common one: `releaseWarmState` (#106) stops the engine
        // after ten idle minutes, so this is what the first keyboard tap of a session
        // looks like.
        XCTAssertEqual(
            HostForegroundDebt.resolve(
                isFromKeyboard: true,
                hasBeenActive: true,
                isEngineRunning: false
            ),
            .engineDead
        )
    }

    func testAGenuinelyWarmKeyboardStartOwesNothing() {
        // The existing rationale, unchanged by #567: the app never took the foreground
        // away, so returning would yank a user who is deliberately looking at Dictus.
        XCTAssertEqual(
            HostForegroundDebt.resolve(
                isFromKeyboard: true,
                hasBeenActive: true,
                isEngineRunning: true
            ),
            .nothingOwed
        )
    }

    func testANonKeyboardURLNeverOwesAnything() {
        // The widget's `dictus://dictate` carries no `source=keyboard`. Its dictation
        // completes in the app, and there is no host app to send anyone back to.
        for hasBeenActive in [true, false] {
            for isEngineRunning in [true, false] {
                XCTAssertEqual(
                    HostForegroundDebt.resolve(
                        isFromKeyboard: false,
                        hasBeenActive: hasBeenActive,
                        isEngineRunning: isEngineRunning
                    ),
                    .nothingOwed,
                    "hasBeenActive=\(hasBeenActive) isEngineRunning=\(isEngineRunning)"
                )
            }
        }
    }

    // MARK: - The condition both gates consume

    func testTheReturnIsOwedOnExactlyTheTwoCasesThatTookTheForeground() {
        // This is #567's fourth acceptance criterion expressed as an assertion: the
        // overlay and the return read this one property, so anything true here is true
        // for both gates by construction. A cold start returning while an engine-dead
        // restart did not is the defect; it is now unrepresentable.
        XCTAssertTrue(HostForegroundDebt.coldStart.owesReturnToHost)
        XCTAssertTrue(HostForegroundDebt.engineDead.owesReturnToHost)
        XCTAssertFalse(HostForegroundDebt.nothingOwed.owesReturnToHost)
    }

    func testEveryCaseIsClassifiedByOwesReturnToHost() {
        // Guards the test above against a case added later and named in neither list,
        // which would leave it unclassified while both still passed.
        XCTAssertEqual(HostForegroundDebt.allCases.count, 3)
    }

    // MARK: - Log contract

    func testTheTwoOwedCasesKeepTheLogStringsCapturesAreGreppedFor() {
        // `coldStartFlagSet context=` values predate this type and device capture
        // protocols are written against them. Renaming either silently invalidates
        // every one of those protocols.
        XCTAssertEqual(HostForegroundDebt.coldStart.logContext, "first launch")
        XCTAssertEqual(HostForegroundDebt.engineDead.logContext, "engine dead")
    }
}
