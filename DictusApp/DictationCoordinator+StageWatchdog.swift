// DictusApp/DictationCoordinator+StageWatchdog.swift
// The watchdog that ends a post-recording stage that never hands over (#267), and its
// re-arm after a suspension (#851).
//
// WHY a file of its own: DictationCoordinator.swift sits at the file-length budget of
// #146, the reason `DictationCoordinator+WarmEngineTimeout.swift` exists. Moved from
// there; #851 adds the stage start to `startStageWatchdog` and the two methods at the end.
import Foundation
import DictusCore

extension DictationCoordinator {

    /// Length of the recording being transcribed, read by the transcription watchdog
    /// before A14 (#963). Static because the coordinator is a singleton (`shared`), and
    /// an extension can only add stored properties that way; kept here, not in
    /// DictationCoordinator.swift, which sits at the #146 file-length budget.
    private static var transcriptionAudioSeconds: TimeInterval = 0

    /// Enters `.transcribing` for a recording of `audioSeconds`, so the stage watchdog
    /// armed by `updateStatus` is sized for it (#963).
    func enterTranscription(audioSeconds: TimeInterval) {
        Self.transcriptionAudioSeconds = audioSeconds
        updateStatus(.transcribing)
    }

    /// How long a post-recording stage may run before it is declared stuck.
    /// Nil for statuses no stage watchdog covers.
    ///
    /// WHY 30s for transcription: WhisperKit transcription of a typical dictation
    /// (<60s audio) should complete in under 10s even on older devices. 30s provides
    /// generous margin while still catching genuinely stuck transcriptions. Before A14,
    /// where Parakeet runs on the CPU, it grows with the recording (#963):
    /// `DeviceCapabilities.transcriptionWatchdogTimeout(audioSeconds:)`.
    ///
    /// WHY 60s for the LLM stage (#267) and not the same 30s: generation time scales
    /// with the output, which is exactly why this stage was split out, and the cost
    /// of firing early is higher here than during transcription -- the transcript
    /// already exists and the recovery below throws it away with the rest of the
    /// session. The number is a last-resort unfreeze, not a latency budget.
    func stageWatchdogTimeout(for status: DictationStatus) -> TimeInterval? {
        switch status {
        case .transcribing:
            return DeviceCapabilities.current()
                .transcriptionWatchdogTimeout(audioSeconds: Self.transcriptionAudioSeconds)
        case .processing:
            return 60
        case .idle, .requested, .recording, .ready, .failed:
            return nil
        }
    }

    /// Log source for a fired stage watchdog. `appTranscription` is unchanged from
    /// before #267 so log lines written by older builds keep meaning what they meant.
    private func stageWatchdogSource(for status: DictationStatus) -> String {
        status == .processing ? "appProcessing" : "appTranscription"
    }

    /// - Parameter stageStartedAt: when the stage began. Kept across re-arms so
    ///   `StageWatchdogPolicy`'s ceiling counts the whole stage (#851).
    func startStageWatchdog(for status: DictationStatus, stageStartedAt: Date = Date()) {
        stopStageWatchdog()
        guard let timeout = stageWatchdogTimeout(for: status) else { return }
        let armedAt = Date()
        stageWatchdog = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                guard self.status == status else { return }
                if self.shouldDeferStageWatchdog(for: status) {
                    self.startStageWatchdog(for: status, stageStartedAt: stageStartedAt)
                    return
                }
                if self.rearmStageWatchdogIfSuspended(
                    status, timeout: timeout, armedAt: armedAt, stageStartedAt: stageStartedAt
                ) { return }
                PersistentLog.log(.watchdogReset(
                    source: self.stageWatchdogSource(for: status),
                    staleState: status.rawValue
                ))
                self.endStuckStage()
            }
        }
        stageWatchdogStageStart = stageStartedAt
    }

    /// End a stage that never handed over.
    func endStuckStage() {
        cancelDictation()
    }

    func stopStageWatchdog() {
        stageWatchdog?.invalidate()
        stageWatchdog = nil
    }

    /// The stage watchdog fired: re-arm it, and return true, when it fired late because
    /// iOS suspended the app rather than because the stage is stuck (#851).
    private func rearmStageWatchdogIfSuspended(
        _ status: DictationStatus, timeout: TimeInterval, armedAt: Date, stageStartedAt: Date
    ) -> Bool {
        let sinceArm = Date().timeIntervalSince(armedAt)
        let sinceStart = Date().timeIntervalSince(stageStartedAt)
        let decision = StageWatchdogPolicy.decide(
            armedFor: timeout, elapsedSinceArm: sinceArm, elapsedSinceStageStart: sinceStart
        )
        guard decision == .rearm else { return false }
        PersistentLog.log(.stageWatchdogRearmed(
            status: status.rawValue, lateBySeconds: Int(sinceArm - timeout), sinceStageStartSeconds: Int(sinceStart)
        ))
        startStageWatchdog(for: status, stageStartedAt: stageStartedAt)
        return true
    }

    /// Back in the foreground during a stage: give the watchdog its full delay again.
    /// The time the app spent suspended is not time the stage spent stuck. The stage
    /// start is kept, so the ceiling still counts the whole stage.
    func restartStageWatchdogAfterSuspension() {
        guard stageWatchdogTimeout(for: status) != nil else { return }
        startStageWatchdog(for: status, stageStartedAt: stageWatchdogStageStart)
    }
}

#if DEBUG
extension DictationCoordinator {

    private static var injectedFailureApplied = false

    /// `-DictusDebugInjectDictationFailure engineError` (or `stuckTranscription`) on the
    /// launch line plays out the end of a keyboard dictation that failed, for a
    /// simulator run of #933 that records nothing and downloads no model:
    /// `xcrun simctl launch <udid> com.pivi.dictus -DictusDebugInjectDictationFailure engineError`.
    ///
    /// - `engineError`: the transcription threw, as Whisper Turbo does on the iPad Pro M4
    ///   (#931), through the same `handleError` the catch in `stopDictation` calls.
    /// - `stuckTranscription`: a 19 s recording whose transcription never came back,
    ///   ended by the stage watchdog's own ending, `endStuckStage`.
    ///
    /// Debug only: nothing of it is compiled into a TestFlight or App Store build.
    func applyInjectedFailureArgument() {
        let argument = "DictusDebugInjectDictationFailure"
        // Called at every activation: once per launch is the injection.
        guard !Self.injectedFailureApplied,
              let mode = UserDefaults.standard.string(forKey: argument) else { return }
        Self.injectedFailureApplied = true
        PersistentLog.log(.dictationFailed(error: "injected \(mode) (\(argument))"))
        switch mode {
        case "engineError":
            let coreML = NSError(domain: "com.apple.CoreML", code: 0, userInfo: [
                NSLocalizedDescriptionKey: "Unable to compute the asynchronous prediction using ML Program"
            ])
            handleError(DictationFailureMessage.userFacing(for: coreML))
        case "stuckTranscription":
            enterTranscription(audioSeconds: 19)
            endStuckStage()
        default:
            break
        }
    }
}
#endif
