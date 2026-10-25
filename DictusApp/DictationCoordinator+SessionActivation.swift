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
    /// The rule is `AudioSessionActivationPolicy` and the loop is `AudioSessionActivationRun`,
    /// both in DictusCore where they are tested; this hands them the engine, the session
    /// generation and the keyboard's status. A start whose first activation worked returns at
    /// once and logs nothing extra.
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

        let run = AudioSessionActivationRun(
            activate: { try engine.configureAudioSession() },
            mediaServicesLost: { engine.mediaServicesLost },
            mediaServicesResetCount: { engine.mediaServicesResetCount },
            sleep: { await self.sleepUnlessCancelled(milliseconds: $0) },
            isStillWanted: { self.mayReport(session, $0) },
            reasonToDropAfterWait: {
                // The keyboard may have given up during the wait.
                let keyboardStatus = self.defaults.string(forKey: SharedKeys.dictationStatus) ?? "nil"
                guard origin == .keyboard && keyboardStatus != DictationStatus.requested.rawValue else { return nil }
                return "keyboardStatus=\(keyboardStatus)"
            },
            log: { self.logActivation($0, $1) }
        )
        return try await run.run(after: firstActivation)
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
