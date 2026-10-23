import XCTest
@testable import DictusCore

final class MicrophoneLifecyclePolicyTests: XCTestCase {
    func testExistingInstallsRetainStandbyAndPreferenceCanBeChanged() throws {
        let suite = "MicrophoneLifecyclePolicyTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertEqual(MicrophoneLifecyclePolicy.mode(defaults: defaults), .standby)
        defaults.set(true, forKey: SharedKeys.releaseMicrophoneAfterDictation)
        XCTAssertEqual(MicrophoneLifecyclePolicy.mode(defaults: defaults), .releaseAfterDictation)
        defaults.set(false, forKey: SharedKeys.releaseMicrophoneAfterDictation)
        XCTAssertEqual(MicrophoneLifecyclePolicy.mode(defaults: defaults), .standby)
    }

    func testActiveWorkNeverReleasesTheMicrophone() {
        for status in [DictationStatus.requested, .recording, .transcribing, .processing] {
            XCTAssertFalse(MicrophoneLifecyclePolicy.shouldRelease(
                mode: .releaseAfterDictation, status: status, awaitingKeyboard: false))
        }
    }

    func testCompletedCancelledAndFailedDictationsRelease() {
        for status in [DictationStatus.idle, .ready, .failed] {
            XCTAssertTrue(MicrophoneLifecyclePolicy.shouldRelease(
                mode: .releaseAfterDictation, status: status, awaitingKeyboard: false))
        }
    }

    func testPendingKeyboardWorkRetainsBackgroundRuntime() {
        XCTAssertFalse(MicrophoneLifecyclePolicy.shouldRelease(
            mode: .releaseAfterDictation, status: .ready, awaitingKeyboard: true))
    }

    func testAnAbandonedRequestReleasesWithoutEndingActiveWork() {
        XCTAssertTrue(MicrophoneLifecyclePolicy.shouldRelease(
            mode: .releaseAfterDictation, status: .requested,
            awaitingKeyboard: false, abandonedRequest: true))
        XCTAssertFalse(MicrophoneLifecyclePolicy.shouldRelease(
            mode: .releaseAfterDictation, status: .recording,
            awaitingKeyboard: false, abandonedRequest: true))
    }

    func testStandbyBehaviorRemainsUnchanged() {
        for status in [DictationStatus.idle, .requested, .recording, .transcribing, .processing, .ready, .failed] {
            XCTAssertFalse(MicrophoneLifecyclePolicy.shouldRelease(
                mode: .standby, status: status, awaitingKeyboard: false))
        }
    }
    func testRestoringStandbyCannotTouchRequestedRecordingOrProcessing() {
        for status in [DictationStatus.requested, .recording, .transcribing, .processing] {
            XCTAssertFalse(MicrophoneLifecyclePolicy.canRestoreStandby(
                mode: .standby, status: status, awaitingKeyboard: false))
        }
    }

    func testKeyboardHandoffStillOwnsAudioAfterStatusBecomesReady() {
        XCTAssertFalse(MicrophoneLifecyclePolicy.canRestoreStandby(
            mode: .standby, status: .ready, awaitingKeyboard: true))
        XCTAssertTrue(MicrophoneLifecyclePolicy.canRestoreStandby(
            mode: .standby, status: .ready, awaitingKeyboard: false))
    }

    func testRestorationRequiresStandbyAndAllowsRetryAfterFailure() {
        XCTAssertFalse(MicrophoneLifecyclePolicy.canRestoreStandby(
            mode: .releaseAfterDictation, status: .idle, awaitingKeyboard: false))
        for status in [DictationStatus.idle, .ready, .failed] {
            XCTAssertTrue(MicrophoneLifecyclePolicy.canRestoreStandby(
                mode: .standby, status: status, awaitingKeyboard: false))
        }
    }
}
