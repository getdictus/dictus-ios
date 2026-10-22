// DictusCore/Sources/DictusCore/AudioSessionActivationPolicy.swift
// What a dictation start does when the audio session refused to activate (#775).
import Foundation

/// The `AVAudioSession` call that threw. Named in the log because the two fail for
/// different reasons, and a single catch around both is what made #515's capture ambiguous.
public enum AudioSessionActivationStep: String, Equatable, Sendable {
    case setCategory
    case setActive
}

/// What a dictation start does next, given how its last session activation went.
public enum AudioSessionActivationDecision: Equatable, Sendable {
    /// The session is active. Start the engine.
    case startRecording

    /// Activate again after `afterMilliseconds`.
    case retryActivation(afterMilliseconds: Int)

    /// The audio server is down (`mediaServicesWereLost`). Nothing can activate until it
    /// comes back, so wait for `mediaServicesWereReset` — at most `timeoutMilliseconds` —
    /// then activate once more.
    case waitForMediaServicesReset(timeoutMilliseconds: Int)

    /// Give up and tell the user to tap again. The hardware is not missing, so the
    /// "microphone is not available" sentence would be wrong.
    case fail
}

/// Decides how a dictation start handles a session that would not activate (issue #775).
///
/// ### What the device capture shows
///
/// iPhone16,2, iOS 27.0.1, 2026-10-22 09:18Z, the first tap after an overnight idle:
/// `setActive(true)` threw (the failure was swallowed by `try?`, so the log never said
/// why), the start went on to wait 1103 ms for a route, rebuilt the engine twice on a
/// `sr=0.0` node, and showed "The microphone is not available right now". The audio server
/// reset one second later and the second tap, five seconds after the first, recorded.
///
/// So the start must not treat a session it could not activate as an active one: waiting
/// for a route and rebuilding the engine (#515, #123) are remedies for an active session
/// whose input went away, and cannot bring back a session that never came up.
///
/// ### The rule
///
/// - The audio server is known to be down: wait for its reset, once, then activate again —
///   even when the last activation succeeded, since it may predate the loss.
/// - Activated: start — including after that wait, whether or not the reset came.
/// - Otherwise one more activation after a short pause, then fail with "tap again".
///
/// The retry after the reset is the one retry that start gets: a reset that arrives and
/// still leaves the session unable to activate is not something a second wait can fix.
public enum AudioSessionActivationPolicy {

    /// Pause before the single retry. Not measured: the capture shows the second tap
    /// working five seconds later, which bounds the useful wait from above, and the
    /// keyboard's cold-start grace (15 s) leaves room for it. Short, because a retry that
    /// succeeds should not be felt.
    public static let retryDelayMilliseconds = 250

    /// How long a start waits for `mediaServicesWereReset` after `mediaServicesWereLost`.
    /// The capture shows the reset one second after the failure; three gives it room and
    /// stays well inside the keyboard's 15 s cold-start grace.
    public static let mediaServicesResetTimeoutMilliseconds = 3000

    /// How many activations a start makes before giving up, outside a media-services loss.
    public static let maxActivationAttempts = 2

    /// - Parameters:
    ///   - activated: whether the last activation succeeded.
    ///   - failedAttempts: activations that have failed so far, this start.
    ///   - mediaServicesLost: whether `mediaServicesWereLost` has been observed with no
    ///     `mediaServicesWereReset` after it.
    ///   - hasWaitedForReset: whether this start has already waited for a reset.
    public static func decide(
        activated: Bool,
        failedAttempts: Int,
        mediaServicesLost: Bool,
        hasWaitedForReset: Bool
    ) -> AudioSessionActivationDecision {
        // Retrying against a dead audio server burns the retry for nothing: wait for it.
        // Checked before `activated` (CodeRabbit on PR #777): the first activation runs
        // before the microphone-permission await, so the server can be lost after it
        // succeeded, and `sessionConfigured` would then keep `startEngine` from repairing it.
        //
        // Once the wait is spent, the activation that followed it is the evidence: a flag
        // still raised then is one no reset ever cleared (a loss iOS never followed with a
        // reset), and failing on it would turn a working session into "tap again" (#775).
        if mediaServicesLost && !hasWaitedForReset {
            return .waitForMediaServicesReset(timeoutMilliseconds: mediaServicesResetTimeoutMilliseconds)
        }

        if activated { return .startRecording }

        // The reset came and the activation after it still failed. That was the retry.
        if hasWaitedForReset { return .fail }

        return failedAttempts < maxActivationAttempts
            ? .retryActivation(afterMilliseconds: retryDelayMilliseconds)
            : .fail
    }

    /// An error code as the log should show it: the number, plus its four-character code
    /// when the four bytes are printable — `560557684 '!int'`, the form Apple's headers
    /// and forums use, so the next reader can look it up without converting by hand.
    public static func statusDescription(_ code: Int) -> String {
        guard let fourCC = fourCharacterCode(code) else { return "\(code)" }
        return "\(code) '\(fourCC)'"
    }

    /// The four-character code an `OSStatus` spells, or `nil` when it spells none
    /// (negative codes like `-50`, small integers, non-printable bytes).
    public static func fourCharacterCode(_ code: Int) -> String? {
        guard code > 0, code <= Int(UInt32.max) else { return nil }
        let value = UInt32(code)
        let bytes = [24, 16, 8, 0].map { UInt8((value >> UInt32($0)) & 0xFF) }
        guard bytes.allSatisfy({ (0x20...0x7E).contains($0) }) else { return nil }
        return String(bytes: bytes, encoding: .ascii)
    }
}
