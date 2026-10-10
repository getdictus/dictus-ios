// DictusCore/Sources/DictusCore/AdoptedDownloadWatchdog.swift
// When a transfer handed back by a previous process has stopped being worth waiting for (#690).
import Foundation

/// Where a model download task came from, as far as the process holding it knows.
public enum DownloadTaskOrigin: Sendable, Equatable {
    /// Handed back by `URLSession.getAllTasks` when the background session was recreated
    /// after a relaunch: a previous process asked for it, this one inherited it.
    case adoptedFromPreviousProcess
    /// Created by this process with `downloadTask(with:)`.
    case createdByThisProcess
}

/// Decides whether a download task that a previous process left behind, and that has
/// stopped delivering bytes, should be cancelled so its chunk can be asked for again.
///
/// WHY THIS EXISTS (issue #690). After iOS kills Dictus — on the Full Access change in
/// onboarding, measured three times on device on 2026-10-09 — the relaunch recreates the
/// background session and adopts the task the system kept. That task then delivered
/// nothing at all, with the app in the foreground and the network up: 90 s in one run,
/// 3 min 25 s in another, and no error either. The session's `timeoutIntervalForRequest`
/// is 30 s, so a task URLSession considered *running* would have failed with a timeout
/// long before; the adopted task was not running, and nothing in the process resumes or
/// replaces it. Its chunk sits in the run's in-flight set, so nothing asks for it again.
///
/// WHY NOT `DownloadStallPolicy`. That predicate exists for the opposite situation — no
/// route at all — and stays silent by design when the network is up. A wedged adopted
/// task with a working network is exactly what it was written not to report.
///
/// WHAT SEPARATES THIS FROM THE WALL-CLOCK TIMEOUT #449 REMOVED. Three clauses, all of
/// which have to hold:
///
/// 1. **The task was adopted.** Only a task inherited from a previous process is watched.
///    The task that replaces it is created here, so it is never watched in turn, which is
///    what rules out a cancel-and-reissue loop.
/// 2. **The app is in the foreground.** A backgrounded transfer runs under iOS's
///    throttle, and long silences there are normal; acting on them is the false alarm
///    #449 removed.
/// 3. **No byte for `silenceLimit` seconds**, measured from the later of the last byte
///    (or the adoption, when none has arrived) and the moment the app reached the
///    foreground. Same latest-onset rule as `DownloadStallPolicy`: the silence must be
///    observed in full while somebody can see it, never satisfied retroactively by time
///    spent in another app.
public enum AdoptedDownloadWatchdog {

    /// Seconds an adopted task may go without a byte, in the foreground, before it is
    /// cancelled and its chunk asked for again.
    ///
    /// WHY 10. The only legitimate silence on a healthy foreground task is its start —
    /// connection, TLS, the redirect to the CDN — and after the force-quit of the run-2
    /// reproduction a whole 32 MB chunk landed in 3 s. Ten clears that start with room to
    /// spare and, with a 2 s watcher tick, puts the bar back in motion inside the ~15 s
    /// the issue's acceptance allows. A false positive costs the chunk in flight (up to
    /// 32 MB) once; it corrupts nothing, because the chunk is re-issued from the manifest.
    public static let silenceLimit: TimeInterval = 10

    /// Whether the task should be cancelled as of `now`.
    ///
    /// - Parameters:
    ///   - origin: where the task came from. Only `.adoptedFromPreviousProcess` is ever
    ///     cancelled.
    ///   - lastByteAt: when the task last delivered a byte in this process, or when it was
    ///     adopted if it has delivered none.
    ///   - foregroundSince: when the app last reached the foreground, `nil` when it is
    ///     backgrounded or has not been observed yet — which must answer the same way.
    ///   - limit: how long the silence must last.
    public static func shouldCancel(
        now: Date,
        origin: DownloadTaskOrigin,
        lastByteAt: Date,
        foregroundSince: Date?,
        limit: TimeInterval = silenceLimit
    ) -> Bool {
        guard origin == .adoptedFromPreviousProcess, let foregroundSince else { return false }
        let silenceStart = max(lastByteAt, foregroundSince)
        return now >= silenceStart.addingTimeInterval(max(0, limit))
    }
}
