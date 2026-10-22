// DictusApp/DictationCoordinator+SessionActivation.swift
// A cold start whose audio session refused to activate: retry it, or fail with "tap again" (#775).
//
// WHY a file of its own: DictationCoordinator.swift sits at the file-length budget of #146,
// the same reason `DictationCoordinator+ModelLoad.swift` exists. The engine is passed in
// rather than exposed, and the rest is `mayReport` and the App Group defaults.
import Foundation
import DictusCore

extension DictationCoordinator {

    /// Make sure the audio session is active before a cold start reaches the engine.
    ///
    /// The rule is `AudioSessionActivationPolicy`; this runs it. A start whose first
    /// activation worked returns at once and logs nothing extra.
    ///
    /// - Parameters:
    ///   - firstActivation: how `configureAudioSession()` went in `startDictation`.
    ///   - engine: the coordinator's engine, which owns the session and its loss flag.
    ///   - session: the dictation's generation, so an abandoned start stops retrying.
    ///   - origin: a keyboard start is only resumed after a media-services reset while the
    ///     keyboard still shows `requested`; past that, nobody is waiting for it.
    /// - Returns: `true` to go on and start the engine, `false` to drop the start silently
    ///   (the session was abandoned or its task cancelled, or the keyboard stopped waiting).
    /// - Throws: the last activation error when the policy gives up, so the caller's catch
    ///   logs it and shows "Dictation could not start. Tap the microphone again."
    func activateSessionForColdStart(
        after firstActivation: Result<Void, Error>,
        engine: UnifiedAudioEngine,
        session: Int,
        origin: DictationOrigin
    ) async throws -> Bool {
        // The cold start's own abandonment check, moved in here so the coordinator's class
        // body stays inside its #146 length budget.
        guard mayReport(session, "cold start") else { return false }

        var lastError: Error?
        if case .failure(let error) = firstActivation { lastError = error }
        var failedAttempts = lastError == nil ? 0 : 1
        var hasWaitedForReset = false

        while true {
            let decision = AudioSessionActivationPolicy.decide(
                activated: lastError == nil,
                failedAttempts: failedAttempts,
                mediaServicesLost: engine.mediaServicesLost,
                hasWaitedForReset: hasWaitedForReset
            )

            switch decision {
            case .startRecording:
                if failedAttempts > 0 {
                    logActivation("sessionActivationRecovered",
                                  "failedAttempts=\(failedAttempts) afterReset=\(hasWaitedForReset)")
                }
                return true

            case .fail:
                // `.fail` is only decided for a failed activation, so `lastError` is set.
                throw lastError ?? AudioEngineError.sessionActivationFailed(step: .setActive, status: "unknown")

            case .retryActivation(let delayMs):
                logActivation("sessionActivationRetry", "failedAttempts=\(failedAttempts) delayMs=\(delayMs)")
                guard await sleepUnlessCancelled(milliseconds: delayMs) else { return false }

            case .waitForMediaServicesReset(let timeoutMs):
                let started = Date()
                while engine.mediaServicesLost && Date().timeIntervalSince(started) * 1000 < Double(timeoutMs) {
                    guard await sleepUnlessCancelled(milliseconds: 50) else { return false }
                }
                hasWaitedForReset = true
                let waitedMs = Int(Date().timeIntervalSince(started) * 1000)
                logActivation("sessionActivationWaitedForReset",
                              "waitedMs=\(waitedMs) timeoutMs=\(timeoutMs) reset=\(!engine.mediaServicesLost)")

                // The keyboard may have given up during the wait. Starting now would record
                // for a dictation nobody is looking at.
                let keyboardStatus = defaults.string(forKey: SharedKeys.dictationStatus) ?? "nil"
                if origin == .keyboard && keyboardStatus != DictationStatus.requested.rawValue {
                    logActivation("sessionActivationDropped", "keyboardStatus=\(keyboardStatus)")
                    return false
                }
            }

            guard mayReport(session, "session activation retry") else { return false }
            do {
                try engine.configureAudioSession()
                lastError = nil
            } catch {
                lastError = error
                failedAttempts += 1
            }
        }
    }

    /// Sleep, or return `false` when the start's task was cancelled during the pause.
    ///
    /// WHY not `try await Task.sleep` (Titus on PR #777): its `CancellationError` reached the
    /// caller's catch and was logged as `dictationFailed`. A cancel here is the user stopping
    /// or a newer start replacing this one, so it is logged as a cancel and the start is
    /// dropped silently, like any other abandoned one, before it can reach the engine.
    private func sleepUnlessCancelled(milliseconds: Int) async -> Bool {
        try? await Task.sleep(nanoseconds: UInt64(milliseconds) * 1_000_000)
        guard Task.isCancelled else { return true }
        logActivation("sessionActivationCancelled", "duringSleepMs=\(milliseconds)")
        return false
    }

    private func logActivation(_ action: String, _ details: String) {
        PersistentLog.log(.diagnosticProbe(
            component: "DictationCoordinator",
            instanceID: "coldStart",
            action: action,
            details: details
        ))
    }
}
