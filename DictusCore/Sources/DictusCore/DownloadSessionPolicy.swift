// DictusCore/Sources/DictusCore/DownloadSessionPolicy.swift
// Which of the two URLSessions a model download chunk goes to (#707).
import Foundation

/// The two sessions a model download chunk can be fetched on.
///
/// The raw values are what the log prints in `session=`, short on purpose: they appear on
/// every task state line.
public enum DownloadSessionKind: String, Sendable, Equatable, Hashable {
    /// `URLSessionConfiguration.background`: survives suspension and process death, and is
    /// the primary path. Its transfers are run by `nsurlsessiond`, not by the app.
    case background = "bg"
    /// `URLSessionConfiguration.default`: runs inside the app's process, so it only moves
    /// while the app is awake, but it does not depend on `nsurlsessiond` and its
    /// `timeoutIntervalForRequest` is a real idle timeout.
    case foreground = "fg"
}

/// Routes a model download chunk to one of the two sessions, and says when the chunks
/// already on the foreground session must go back to the background one.
///
/// WHY TWO SESSIONS (issue #707). The service had a single background session. When
/// `nsurlsessiond` stopped delivering to it after a relaunch — measured twice on device on
/// iOS 27.0.1 on 2026-10-11 — the task the #690 watchdog re-issued went to the same
/// silent session and stalled exactly like the one it replaced: 26 s in the foreground,
/// then 20 min in the background, until the app came back and the whole model landed in
/// 1.5 minutes. A default session is the one place a replacement can go that the stall
/// cannot follow, and while the app is active, it costs nothing a background session would
/// have saved.
///
/// WHY THE BACKGROUND SESSION STAYS PRIMARY. A default session's tasks stop when the app
/// is suspended, and #449 exists because a foreground-only download made a user who left
/// Dictus pay for it. So the foreground session is a fallback, engaged by the silent-task
/// watchdog and nothing else, and released the moment the app enters the background, when
/// its chunks are handed back.
///
/// WHY THE FALLBACK HOLDS FOR THE WHOLE FOREGROUND STAY, and not for the one chunk the
/// watchdog moved. The triage on #707 established that the stall is the session's: in the
/// second capture, two tasks created fresh after the relaunch were as silent as the
/// adopted one. Sending the next chunk back to that session would make every chunk wait
/// out the 30 s silence limit before being moved — about 15 chunks for Parakeet's 445 MB
/// encoder, so several minutes of frozen bar. The background session gets its next chance
/// at the next foreground stay, where the same watchdog moves it again if it is still
/// silent.
public enum DownloadSessionPolicy {

    /// The session a chunk about to be requested goes to.
    ///
    /// - Parameters:
    ///   - appInForeground: whether the app is in the foreground right now. `false` when
    ///     unknown — the background session is the one that is right in both cases.
    ///   - fallbackEngaged: whether the silent-task watchdog has moved a chunk off the
    ///     background session during this foreground stay.
    public static func session(
        appInForeground: Bool,
        fallbackEngaged: Bool
    ) -> DownloadSessionKind {
        appInForeground && fallbackEngaged ? .foreground : .background
    }

    /// Whether a task must be cancelled and its chunk re-issued on the background session
    /// because the app is leaving the foreground.
    ///
    /// Only a foreground-session task is handed back: its process is about to be
    /// suspended, and with it the transfer. What it has received is lost — a download
    /// task's bytes are only revealed when it finishes — so a hand-off re-pays at most one
    /// chunk per task in flight, 64 MB at two chunks in flight. Left alone, the task would
    /// lose the same bytes anyway and then time out on the user's return.
    public static func shouldHandBack(taskOn session: DownloadSessionKind) -> Bool {
        session == .foreground
    }
}
