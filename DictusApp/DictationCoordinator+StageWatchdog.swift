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

    /// How long a post-recording stage may run before it is declared stuck.
    /// Nil for statuses no stage watchdog covers.
    ///
    /// WHY 30s for transcription: WhisperKit transcription of a typical dictation
    /// (<60s audio) should complete in under 10s even on older devices. 30s provides
    /// generous margin while still catching genuinely stuck transcriptions.
    ///
    /// WHY 60s for the LLM stage (#267) and not the same 30s: generation time scales
    /// with the output, which is exactly why this stage was split out, and the cost
    /// of firing early is higher here than during transcription -- the transcript
    /// already exists and the recovery below throws it away with the rest of the
    /// session. The number is a last-resort unfreeze, not a latency budget.
    func stageWatchdogTimeout(for status: DictationStatus) -> TimeInterval? {
        switch status {
        case .transcribing:
            return 30
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
                self.cancelDictation()
            }
        }
        stageWatchdogStageStart = stageStartedAt
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
