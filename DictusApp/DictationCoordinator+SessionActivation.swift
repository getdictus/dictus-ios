// DictusApp/DictationCoordinator+SessionActivation.swift
// A cold start whose audio session refused to activate: retry it, or fail with "tap again" (#775).
//
// WHY a file of its own: DictationCoordinator.swift sits at the file-length budget of #146,
// the same reason `DictationCoordinator+ModelLoad.swift` exists. The engine is passed in
// rather than exposed, and the rest is `mayReport` and the App Group defaults.
import Foundation
import UIKit
import DictusCore

extension DictationCoordinator {

    /// Backing store for `isRecoveringAudioSession`. Static because an extension cannot add a
    /// stored property, and the coordinator is a process-wide singleton (`shared`), so one
    /// value per process is one value per coordinator. It lives here rather than as an
    /// `@Published` in the class body because that body sits exactly at its #146 budget.
    private static var recoveringAudioSession = false

    /// A cold start's audio session refused to activate, or the audio server is down, and the
    /// start is recovering it (#853). While it is, the return to the host app holds the
    /// foreground (`returnToHostApp`) and the swipe-back overlay says the microphone is being
    /// prepared. Publishes through `objectWillChange` like an `@Published` would, so the
    /// overlay, which observes the coordinator, redraws on a change.
    var isRecoveringAudioSession: Bool {
        get { Self.recoveringAudioSession }
        set {
            guard newValue != Self.recoveringAudioSession else { return }
            objectWillChange.send()
            Self.recoveringAudioSession = newValue
        }
    }

    /// `startDictation`'s own activation, which also says whether a cold start will have to
    /// recover its session (#853).
    ///
    /// Raised here, not only in `activateSessionForColdStart`, because a URL launch first runs
    /// this from `.inactive` and parks the start until `didBecomeActive`. The host return's
    /// 250 ms ceiling lands in between (measured: `via=ceiling` before the retry's own
    /// activation line), so this first refusal is all it has to go on. A warm engine never
    /// recovers: its running engine means the session is up.
    func activateSessionAtStart(engine: UnifiedAudioEngine) -> Result<Void, Error> {
        let activation = Result { try engine.configureAudioSession() }
        isRecoveringAudioSession = !engine.isEngineRunning
            && ForegroundAudioRecoveryPolicy.sessionNeedsRecovery(
                after: activation, mediaServicesLost: engine.mediaServicesLost)
        return activation
    }

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
    ///   logs it and shows "Dictation could not start. Tap the microphone again." Also
    ///   `ColdStartOutsideForegroundError`, with the same sentence, when the session came back
    ///   only after DictusApp had left the foreground (#853).
    func activateSessionForColdStart(
        after firstActivation: Result<Void, Error>,
        engine: UnifiedAudioEngine,
        session: Int,
        origin: DictationOrigin
    ) async throws -> Bool {
        // Whatever happens below, the recovery is over when this returns (#853). Cleared
        // before the caller's catch reports a failure, and on an abandoned start too.
        defer { isRecoveringAudioSession = false }

        // The cold start's own abandonment check, moved in here so the coordinator's class
        // body stays inside its #146 length budget.
        guard mayReport(session, "cold start") else { return false }

        // Sampled before the run, on the same two inputs its first decision reads with no
        // await in between: this is whether the run will do anything but return at once.
        // Re-read rather than trusted from `activateSessionAtStart`, since a loss can have
        // been posted during the microphone-permission await.
        let needsRecovery = ForegroundAudioRecoveryPolicy.sessionNeedsRecovery(
            after: firstActivation, mediaServicesLost: engine.mediaServicesLost)
        isRecoveringAudioSession = needsRecovery

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
        guard try await run.run(after: firstActivation) else { return false }

        // The reset can land after DictusApp has left the foreground: a manual swipe during
        // the wait, or a host return that was not held (#853). iOS then refuses
        // `engine.start()` with `2003329396`, measured twice on 2026-10-28, and the start
        // failed on a CoreAudio error the user could do nothing with. Refused here with
        // "tap again" instead, which is what works: the second tap brings the app forward.
        let appState = UIApplication.shared.applicationState.sceneMarker
        guard ForegroundAudioRecoveryPolicy.mayStartEngine(afterRecovery: needsRecovery, appState: appState) else {
            logActivation("engineStartSkipped", "appState=\(appState.rawValue) reason=recoveredOutsideForeground")
            throw ColdStartOutsideForegroundError(appState: appState.rawValue)
        }
        return true
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

/// A cold start whose audio session recovered after DictusApp left the foreground, so
/// `engine.start()` was not attempted (#853). Thrown into the cold start's own catch, which
/// logs it and reports it through `DictationFailureMessage` like any other failure.
struct ColdStartOutsideForegroundError: DiagnosableError {
    /// `active`, `inactive` or `background`, as `AppScenePhaseMarker` spells it.
    let appState: String

    /// The #311 sentence, deliberately: from the user's side this is the same event, a cold
    /// start that could not run because the app was no longer in front. The microphone is
    /// not missing, and the second tap works.
    var errorDescription: String? {
        String(localized: "Dictation could not start. Tap the microphone again.")
    }

    var diagnosticDescription: String {
        "audio session recovered with the app \(appState), engine.start not attempted (#853)"
    }
}

extension UIApplication.State {
    /// This state as the log and `ForegroundAudioRecoveryPolicy` spell it (#853).
    var sceneMarker: AppScenePhaseMarker {
        switch self {
        case .active: return .active
        case .inactive: return .inactive
        case .background: return .background
        @unknown default: return .unknown
        }
    }
}
