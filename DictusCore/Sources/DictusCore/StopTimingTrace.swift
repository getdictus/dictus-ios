// DictusCore/Sources/DictusCore/StopTimingTrace.swift
// Millisecond trace from the keyboard's stop tap to the start of transcription (#862).
import Foundation

/// One stop tap, and the clock every step after it is measured against.
///
/// WHY a wall-clock epoch rather than a monotonic clock: the steps run in two processes,
/// the keyboard extension and DictusApp, and the trace has to put them on one axis. The
/// monotonic clocks are per process; the wall clock is the one both read the same way on
/// the same device. The tap time crosses the process boundary through the App Group,
/// next to the `stopRequested` flag it travels with.
///
/// WHY the log line carries `sinceTapMs` and not just its own timestamp: the log's
/// timestamps are to the second, and the whole stop path fits inside one of them.
public struct StopTimingTrace: Equatable, Sendable {
    /// The keyboard's dictation session id, the one its probes already print.
    public let sessionID: String
    /// When the stop was tapped, seconds since 1970.
    public let tapEpoch: TimeInterval

    public init(sessionID: String, tapEpoch: TimeInterval) {
        self.sessionID = sessionID
        self.tapEpoch = tapEpoch
    }

    /// A trace for a tap happening now.
    public static func tapped(sessionID: String, at now: Date = Date()) -> StopTimingTrace {
        StopTimingTrace(sessionID: sessionID, tapEpoch: now.timeIntervalSince1970)
    }

    /// Milliseconds from the tap to `now`, truncated.
    ///
    /// Not clamped at zero: a negative value means the wall clock moved between the two
    /// reads, and hiding that would make a wrong number look right.
    public func sinceTapMs(at now: Date = Date()) -> Int {
        Int(((now.timeIntervalSince1970 - tapEpoch) * 1000).rounded(.towardZero))
    }

    /// The log event for `step`, measured at `now`.
    public func event(_ step: String, at now: Date = Date()) -> LogEvent {
        .stopTiming(step: step, sinceTapMs: sinceTapMs(at: now), sessionID: sessionID)
    }

    /// Write the step's line to the persistent log.
    public func log(_ step: String) {
        PersistentLog.log(event(step))
    }

    // MARK: - App Group hand-off

    /// Store the trace for the other process. Written before the stop flag, so the app
    /// that reads the flag finds the tap beside it.
    public func write(to defaults: UserDefaults) {
        defaults.set(tapEpoch, forKey: SharedKeys.stopTapEpoch)
        defaults.set(sessionID, forKey: SharedKeys.stopTapSessionID)
    }

    /// Read and remove the stored trace, so a later stop that never wrote one cannot be
    /// measured against this tap. Nil when there is none.
    public static func take(from defaults: UserDefaults) -> StopTimingTrace? {
        defer {
            defaults.removeObject(forKey: SharedKeys.stopTapEpoch)
            defaults.removeObject(forKey: SharedKeys.stopTapSessionID)
        }
        guard defaults.object(forKey: SharedKeys.stopTapEpoch) != nil,
              let sessionID = defaults.string(forKey: SharedKeys.stopTapSessionID) else { return nil }
        return StopTimingTrace(sessionID: sessionID, tapEpoch: defaults.double(forKey: SharedKeys.stopTapEpoch))
    }
}
