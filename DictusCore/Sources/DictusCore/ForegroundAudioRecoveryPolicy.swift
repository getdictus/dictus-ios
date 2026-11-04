// DictusCore/Sources/DictusCore/ForegroundAudioRecoveryPolicy.swift
// A cold start whose audio session is recovering needs DictusApp in the foreground (#853).
import Foundation

/// Keeps DictusApp in the foreground while a cold start's audio session is recovering, and
/// refuses to start the engine once it has left (issue #853).
///
/// ### What the device capture shows
///
/// iPhone, iOS 27.0.1, 2026-10-28, twice in one day, both the first tap after an hour idle:
/// the first `setCategory` threw `'msrv'`, the audio server reset ~2.8 s later, and #775's
/// wait recovered the session (`sessionActivationRecovered afterReset=true`). But the
/// auto-return had already opened the host app at its 250 ms ceiling (`via=ceiling`), or the
/// user had swiped back by hand, so the engine was started from the background and iOS
/// refused it: `engine.start failed … 2003329396` (`'what'`, the error of #73). The second
/// tap brought DictusApp back to the foreground and recorded.
///
/// So the reset wait works and the start loses the race against the foreground. Two rules:
///
/// - **Hold the return.** A start whose session is recovering cannot finish inside the
///   250 ms ceiling, and returning anyway hands it to the background, where it cannot
///   succeed. Held until recording, a failure, or `recoveryHoldCeilingMilliseconds`.
/// - **Never start from outside the foreground after a recovery.** When the session comes
///   back after DictusApp has left (a manual swipe during the wait), `engine.start()` can
///   only fail. The start fails at once with "tap again", which is true: the microphone is
///   not missing, the second tap works.
///
/// An ordinary cold start (the first activation worked, the server is up) is untouched by
/// both: it returns at the current ceiling and starts from wherever it is, as before.
public enum ForegroundAudioRecoveryPolicy {

    /// How long the return may wait for recording to have actually started, on an ordinary
    /// cold start.
    ///
    /// **A ceiling, not a wait.** It was sized for the window in which a freshly foregrounded
    /// app may still call `open()`, believed to be about 300 ms, past which iOS would refuse
    /// with "Application is neither visible nor entitled". That window is not measured in
    /// this repository: a simulator under load returned fine at 305 ms, and nothing has
    /// probed further. 250 ms keeps margin under it.
    ///
    /// Do not raise it to "make the wait more reliable": every millisecond added is borrowed
    /// from the only thing that makes the feature work, and a return that never happens is a
    /// worse failure than a dictation missing its first syllable. If a capture keeps
    /// showing `recState=idle waitedMs=250`, the answer is not a longer ceiling, it is that
    /// the engine cannot start inside the window at all, and the fix moves to starting it
    /// sooner rather than waiting for it longer.
    ///
    /// The one exception is a session that is recovering (#853), and it does not touch this
    /// number: see `recoveryHoldCeilingMilliseconds`.
    public static let recordingWaitCeilingMilliseconds = 250

    /// Margin for the engine start itself, after the session is up. A healthy cold start
    /// reaches `.recording` in well under this; it is margin, not a measurement.
    public static let engineStartMarginMilliseconds = 750

    /// How long the return is held, from the hand-off, while the session recovers.
    ///
    /// The sum of every budget a recovering start can spend before `.recording`: the single
    /// activation retry, the full media-services reset wait, the route wait #515's start makes
    /// after an empty route, and the engine start. 5000 ms today, well inside the keyboard's
    /// 15 s cold-start grace.
    ///
    /// WHY holding past the ~300 ms `open()` window is still a gain if that window is real:
    /// the alternative is the capture's outcome, a dictation lost for certain. Held, the user
    /// arrives back recording; if iOS refuses the late open, the recording is still running
    /// and the overlay's swipe-back is the floor, as for any host without a scheme. The
    /// `hostReturn` outcome line (`returned` / `open-failed`) after `via=recording` is what
    /// will measure it.
    public static let recoveryHoldCeilingMilliseconds =
        AudioSessionActivationPolicy.retryDelayMilliseconds
        + AudioSessionActivationPolicy.mediaServicesResetTimeoutMilliseconds
        + AudioStartReadinessPolicy.inputRouteWaitMilliseconds
        + engineStartMarginMilliseconds

    /// What the return does when its ordinary ceiling is reached without `.recording`.
    public enum ReturnDecision: Equatable, Sendable {
        /// Open the host app now, as before #853.
        case openNow
        /// Keep DictusApp in the foreground until recording, a failure, or this many
        /// milliseconds after the hand-off, whichever comes first.
        case hold(untilMilliseconds: Int)
    }

    /// Whether a cold start's audio session has to recover before the engine can start: its
    /// own activation was refused (`'msrv'`, `'!int'`, any code), or the audio server is
    /// known to be down.
    ///
    /// This is exactly when `AudioSessionActivationRun` does more than return at once: it
    /// decides on the same two inputs, first thing, with no await before.
    ///
    /// WHY any refusal and not only `'msrv'`: whatever the code, the run then retries and may
    /// wait for a reset, and none of that can end in a started engine from the background.
    public static func sessionNeedsRecovery(
        after firstActivation: Result<Void, Error>,
        mediaServicesLost: Bool
    ) -> Bool {
        if case .failure = firstActivation { return true }
        return mediaServicesLost
    }

    /// - Parameter sessionNeedsRecovery: sampled when the ordinary ceiling is reached, so a
    ///   loss that arrived after the hand-off still counts.
    public static func returnAtCeiling(sessionNeedsRecovery: Bool) -> ReturnDecision {
        sessionNeedsRecovery ? .hold(untilMilliseconds: recoveryHoldCeilingMilliseconds) : .openNow
    }

    /// Whether a cold start may call `engine.start()` now that its session is active.
    ///
    /// - Parameters:
    ///   - afterRecovery: whether this start's session had to recover (`sessionNeedsRecovery`).
    ///   - appState: DictusApp's state at that moment.
    ///
    /// Only a recovered start is gated. An ordinary one keeps today's behavior, including
    /// #311's last-chance start from the background, which this issue has no evidence about.
    /// `.inactive` is refused with `.background`: iOS refuses the start from either
    /// (`AUIOClient_StartIO`, #73), and a manual swipe passes through `.inactive` first.
    public static func mayStartEngine(afterRecovery: Bool, appState: AppScenePhaseMarker) -> Bool {
        !afterRecovery || appState == .active
    }
}
