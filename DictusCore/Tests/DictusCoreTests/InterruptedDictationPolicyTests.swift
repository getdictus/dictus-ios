import XCTest
@testable import DictusCore

/// A dictation cut by a call keeps what was said (#851): one case per row of the
/// decision table, plus the guarantee that the recording itself is never resumed.
final class InterruptedDictationPolicyTests: XCTestCase {

    private let minimum = 0.5

    private func decide(
        _ status: DictationStatus,
        seconds: Double = 10,
        cause: DictationInterruptionCause = .interruption
    ) -> InterruptedDictationDecision {
        InterruptedDictationPolicy.decide(status: status, cause: cause, capturedSeconds: seconds, minimum: minimum)
    }

    // MARK: - Recording

    func testRecordingWithSpeechIsTranscribed() {
        XCTAssertEqual(decide(.recording, seconds: 31.62), .transcribeCaptured)
    }

    func testRecordingOfExactlyTheMinimumIsTranscribed() {
        XCTAssertEqual(decide(.recording, seconds: 0.5), .transcribeCaptured)
    }

    func testRecordingUnderTheMinimumIsTheNoWordsNoticeNotAFailure() {
        XCTAssertEqual(decide(.recording, seconds: 0.3), .discardTooShort)
        XCTAssertEqual(decide(.recording, seconds: 0), .discardTooShort)
    }

    // MARK: - After the recording

    func testTranscriptionAlreadyRunningIsLeftToFinish() {
        XCTAssertEqual(decide(.transcribing, seconds: 0), .letTranscriptionFinish)
    }

    func testLLMStageAlreadyRunningIsLeftToFinish() {
        XCTAssertEqual(decide(.processing, seconds: 0), .letTranscriptionFinish)
    }

    // MARK: - Nothing to keep

    func testRequestedBeforeTheEngineStartedStillFails() {
        XCTAssertEqual(decide(.requested, seconds: 0), .fail)
    }

    func testStatusesWithNoDictationInFlightFail() {
        for status: DictationStatus in [.idle, .ready, .failed] {
            XCTAssertEqual(decide(status), .fail, "\(status)")
        }
    }

    func testMediaServicesResetStillFailsWhateverWasCaptured() {
        for status in DictationStatus.allCases {
            XCTAssertEqual(decide(status, seconds: 30, cause: .mediaServicesReset), .fail, "\(status)")
        }
    }

    // MARK: - Never resumed

    func testInterruptedRecordingIsStillNeverResumed() {
        // #851 keeps the audio; it does not change #353's refusal to restart a recording.
        XCTAssertEqual(
            InterruptionResumePolicy.plan(shouldResume: true, interrupted: .recording, engineAlreadyRunning: false, now: Date()),
            .skip(.wasRecording)
        )
    }

    // MARK: - Log line

    func testRecordingInterruptedLogLine() {
        let event = LogEvent.recordingInterrupted(status: "recording", samples: 505_916, decision: .transcribeCaptured)
        XCTAssertEqual(event.name, "recordingInterrupted")
        XCTAssertEqual(event.message, "status=recording samples=505916 seconds=31.62 decision=transcribeCaptured")
        XCTAssertEqual(event.level, .warning)
        XCTAssertEqual(event.subsystem, .dictation)
    }
}
