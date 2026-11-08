// DictusCore/Sources/DictusCore/SilentDownloadTaskWatchdog.swift
// When a background-session transfer has stopped being worth waiting for (#690, #707).
import Foundation

/// Where a model download task came from, as far as the process holding it knows.
///
/// No longer part of any decision (#707: the watchdog watches adopted and new tasks
/// alike). Kept because the log names it: `origin=adopted` against `origin=new` is what
/// told #707 that the stall belongs to the session, not to the inherited task.
public enum DownloadTaskOrigin: String, Sendable, Equatable {
    /// Handed back by `URLSession.getAllTasks` when the background session was recreated
    /// after a relaunch: a previous process asked for it, this one inherited it.
    case adoptedFromPreviousProcess = "adopted"
    /// Created by this process with `downloadTask(with:)`.
    case createdByThisProcess = "new"
}

/// Decides whether a background-session download task that has stopped delivering bytes
/// should be cancelled so its chunk can be asked for again on the foreground session.
///
/// WHY THIS EXISTS (issues #690 and #707). After a relaunch, `nsurlsessiond` sometimes
/// delivers nothing at all to the background session, with the app in the foreground and
/// the network up. #690 first saw it on adopted tasks (90 s, then 3 min 25 s on device on
/// 2026-10-09) and watched only those. #707's two captures on 2026-10-11 moved the
/// diagnosis: the replacement task the watchdog created stalled the same way, for 26 s in
/// the foreground and 20 min in the background, and in the second capture two tasks this
/// process had just created (`origin=new`) sat `running` with `received=0B`. The stall is
/// the session's, not the task's, so every task on the background session is watched.
///
/// WHY NOT `DownloadStallPolicy`. That predicate exists for the opposite situation — no
/// route at all — and stays silent by design when the network is up.
///
/// WHAT SEPARATES THIS FROM THE WALL-CLOCK TIMEOUT #449 REMOVED. Three clauses, all of
/// which have to hold:
///
/// 1. **The task is on the background session.** A task on the foreground session is
///    never cancelled here: that session has a real idle timeout, so a stall there fails
///    with `NSURLErrorTimedOut` and goes through the normal retry path. This is what keeps
///    the watchdog from looping: what it moves, it never watches again.
/// 2. **The app is in the foreground.** A backgrounded transfer runs under iOS's
///    throttle, and long silences there are normal; acting on them is the false alarm
///    #449 removed.
/// 3. **No byte for `silenceLimit` seconds**, measured from the later of the last byte
///    (or the task's creation or adoption, when none has arrived) and the moment the app
///    reached the foreground. Same latest-onset rule as `DownloadStallPolicy`: the silence
///    must be observed in full while somebody can see it, never satisfied retroactively by
///    time spent in another app.
public enum SilentDownloadTaskWatchdog {

    /// Seconds a background-session task may go without a byte, in the foreground, before
    /// it is cancelled and its chunk moved to the foreground session.
    ///
    /// WHY 30, AND NOT #690'S 10. #690 watched adopted tasks only, whose clock starts at
    /// adoption, and argued 10 s from a chunk landing in 3 s after a force-quit. #707's
    /// triage widens the watch to every task this process creates, and a brand new task
    /// has a legitimately silent start (connection, TLS, the redirect to the CDN) that a
    /// slow network can stretch well past ten seconds. Thirty is the value the triage
    /// fixed, and the same as the background session's own `timeoutIntervalForRequest`:
    /// a task URLSession still considers running is failed by URLSession first, and the
    /// watchdog only ever acts on the wedge that timeout never sees. A false positive costs
    /// the chunk in flight (up to 32 MB) once; it corrupts nothing.
    public static let silenceLimit: TimeInterval = 30

    /// Whether the task should be cancelled and its chunk moved, as of `now`.
    ///
    /// - Parameters:
    ///   - session: which session holds the task. Only `.background` is ever cancelled.
    ///   - lastByteAt: when the task last delivered a byte in this process, or when it was
    ///     created or adopted if it has delivered none.
    ///   - foregroundSince: when the app last reached the foreground, `nil` when it is
    ///     backgrounded or has not been observed yet — which must answer the same way.
    ///   - limit: how long the silence must last.
    public static func shouldCancel(
        now: Date,
        session: DownloadSessionKind,
        lastByteAt: Date,
        foregroundSince: Date?,
        limit: TimeInterval = silenceLimit
    ) -> Bool {
        guard session == .background, let foregroundSince else { return false }
        let silenceStart = max(lastByteAt, foregroundSince)
        return now >= silenceStart.addingTimeInterval(max(0, limit))
    }
}
