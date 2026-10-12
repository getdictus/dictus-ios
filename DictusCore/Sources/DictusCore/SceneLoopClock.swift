// DictusCore/Sources/DictusCore/SceneLoopClock.swift
// The pausable clock that drives a drawn, looping scene (#679).
import Foundation

/// Where a looping scene is in its loop, with pauses (#679, #649 decision 14).
///
/// WHY PAUSABLE: a scene stops when the app leaves the foreground, as the intro's videos
/// do, and picks up where it stopped on return. A clock read from the wall time alone
/// would jump ahead by the time spent away, and the scene would come back mid-gesture.
///
/// WHY A TYPE OF ITS OWN AND NOT `IntroDwellTimer`: that one counts down to a page turn
/// and stops at zero; a scene counts up forever and wraps. The two share the
/// pause/resume bookkeeping and nothing else.
///
/// Times are seconds on any monotonic clock the caller picks; the type never reads one,
/// which keeps it testable.
public struct SceneLoopClock: Equatable, Sendable {
    /// One pass of the scene, in seconds.
    public let loopSeconds: Double
    /// Time played before the last pause.
    private var accumulated: Double
    /// When the current running stretch started, or nil while paused.
    private var runningSince: Double?

    /// A paused clock at `startSeconds` into a loop of `loopSeconds`.
    public init(loopSeconds: Double, startSeconds: Double = 0) {
        self.loopSeconds = loopSeconds
        self.accumulated = max(0, startSeconds)
    }

    /// Whether time is currently counting.
    public var isRunning: Bool { runningSince != nil }

    /// Starts counting at `now`. No effect when already running.
    public mutating func resume(at now: Double) {
        guard runningSince == nil else { return }
        runningSince = now
    }

    /// Stops counting at `now`, keeping the time played so far. No effect when paused.
    public mutating func pause(at now: Double) {
        guard let start = runningSince else { return }
        accumulated += max(0, now - start)
        runningSince = nil
    }

    /// Where the scene is in its loop at `now`: in `0 ..< loopSeconds`.
    public func loopTime(at now: Double) -> Double {
        guard loopSeconds > 0 else { return 0 }
        let running = runningSince.map { max(0, now - $0) } ?? 0
        return (accumulated + running).truncatingRemainder(dividingBy: loopSeconds)
    }
}
