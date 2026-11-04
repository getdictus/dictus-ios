import XCTest
@testable import DictusCore

/// The Live Activity across an audio interruption (#353, device batch 7eaf771b):
/// paused rather than ended, because iOS refuses to request one from the background.
final class LiveActivityInterruptionPolicyTests: XCTestCase {

    // MARK: - .began

    func testStandbyPillIsPausedNotEnded() {
        XCTAssertEqual(LiveActivityInterruptionPolicy.atBegan(hasActivity: true, phase: .standby), .pause)
    }

    func testDictationActivityIsLeftToTheDictation() {
        // #851: the coordinator transcribes what was captured, or fails and ends the pill.
        for phase: LiveActivityStateMachine.Phase in [.recording, .transcribing, .processing] {
            XCTAssertEqual(LiveActivityInterruptionPolicy.atBegan(hasActivity: true, phase: phase), .none, "\(phase)")
        }
    }

    func testFinishedDictationActivityEnds() {
        for phase: LiveActivityStateMachine.Phase in [.ready, .failed] {
            XCTAssertEqual(LiveActivityInterruptionPolicy.atBegan(hasActivity: true, phase: phase), .end, "\(phase)")
        }
    }

    func testNoActivityNothingToPause() {
        XCTAssertEqual(LiveActivityInterruptionPolicy.atBegan(hasActivity: false, phase: .idle), .none)
    }

    // MARK: - .ended

    func testPausedPillResumesOverAWarmEngine() {
        XCTAssertEqual(LiveActivityInterruptionPolicy.atEnded(isPaused: true, hasActivity: true, engineWarm: true), .resume)
    }

    func testPausedPillEndsOverAColdEngine() {
        // shouldResume=false, a refused restart, an expired window: the engine is cold.
        XCTAssertEqual(LiveActivityInterruptionPolicy.atEnded(isPaused: true, hasActivity: true, engineWarm: false), .end)
    }

    func testNothingIsEverRequestedWithoutAPausedActivity() {
        for warm in [true, false] {
            XCTAssertEqual(LiveActivityInterruptionPolicy.atEnded(isPaused: false, hasActivity: false, engineWarm: warm), .none)
            XCTAssertEqual(LiveActivityInterruptionPolicy.atEnded(isPaused: false, hasActivity: true, engineWarm: warm), .none)
        }
    }

    func testPauseFlagWithoutAnActivityDoesNothing() {
        XCTAssertEqual(LiveActivityInterruptionPolicy.atEnded(isPaused: true, hasActivity: false, engineWarm: true), .none)
    }

    // MARK: - Content

    // The attributes are iOS-only (ActivityKit); `swift test` on the Mac skips these.
    #if os(iOS)
    func testPausedContentReadsAsPausedOnlyInStandby() {
        XCTAssertTrue(DictusLiveActivityAttributes.ContentState(phase: .standby, paused: true).isPaused)
        XCTAssertFalse(DictusLiveActivityAttributes.ContentState(phase: .standby).isPaused)
        XCTAssertFalse(DictusLiveActivityAttributes.ContentState(phase: .recording, paused: true).isPaused)
    }

    func testContentFromABuildWithoutTheFlagStillDecodes() throws {
        let json = Data(#"{"phase":"standby","waveformLevels":[]}"#.utf8)
        let state = try JSONDecoder().decode(DictusLiveActivityAttributes.ContentState.self, from: json)
        XCTAssertFalse(state.isPaused)
    }
    #endif
}
