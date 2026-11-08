// DictusApp/Onboarding/ChecklistAudioSession.swift
// The silent audio session the checklist's Picture in Picture borrows, and gives back (#682).
import AVFoundation
import DictusCore

/// Borrows the app's audio session for the checklist's Picture in Picture, without
/// disturbing recording.
///
/// WHY A SESSION AT ALL (#649 decision 10): Picture in Picture is a playback feature;
/// Apple requires a playback-capable audio session for it, and the app's
/// `UIBackgroundModes` `audio` entry (already there for background recording) is what lets
/// it keep running behind the Picture in Picture window. The checklist plays no sound, so
/// the session is `.playback` with `.mixWithOthers`: whatever the user is listening to
/// keeps playing, at full volume.
///
/// WHY IT IS CHECKED AGAINST THE RECORDING SESSION: `AVAudioSession` is one object for the
/// whole app, and the dictation engine owns it (`.playAndRecord`, activated at launch by
/// `DictationCoordinator`, kept warm between recordings). The rules:
/// - **A running engine is never touched.** If the engine is warm or recording, its
///   `.playAndRecord` session is already playback-capable; the checklist uses it as it is.
/// - **Recording always wins.** `UnifiedAudioEngine.configureAudioSession()` re-asserts
///   `.playAndRecord` whenever the category is not its own, so a dictation started while
///   the session is borrowed takes it back.
/// - **The session is given back the way the app had it**: the borrowed session is
///   deactivated (other apps are told they may resume), then the engine's own
///   configuration runs, which is exactly what the app does at launch. Skipped if the
///   engine already took it back.
@MainActor
final class ChecklistAudioSession {
    /// Whether this borrowed the session and still holds it.
    private(set) var isBorrowed = false

    /// Switches the session to a silent, mixable `.playback`, unless the engine is running.
    ///
    /// - Returns: what happened, for the log.
    func borrow(engineIsRunning: Bool) -> String {
        guard !isBorrowed else { return "alreadyBorrowed" }
        let session = AVAudioSession.sharedInstance()
        guard !engineIsRunning else {
            return "keptEngineSession category=\(session.category.rawValue)"
        }
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            isBorrowed = true
            return "borrowedPlayback"
        } catch {
            return "borrowFailed error=\(error.localizedDescription)"
        }
    }

    /// Gives the session back to the engine. Call from the foreground: activating
    /// `.playAndRecord` is refused in the background.
    ///
    /// - Parameter restoreEngineSession: the engine's own configuration
    ///   (`DictationCoordinator.configureAudioSessionForWarmUp`).
    /// - Returns: what happened, for the log, or nil when nothing was borrowed.
    func giveBack(restoreEngineSession: () throws -> Void) -> String? {
        guard isBorrowed else { return nil }
        isBorrowed = false
        let session = AVAudioSession.sharedInstance()
        // A dictation started meanwhile has already re-asserted `.playAndRecord`; the
        // session is the engine's again and must not be deactivated under it.
        guard session.category == .playback else {
            return "engineReclaimed category=\(session.category.rawValue)"
        }
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
        do {
            try restoreEngineSession()
            return "restoredEngineSession"
        } catch {
            return "restoreFailed error=\(error.localizedDescription)"
        }
    }
}
