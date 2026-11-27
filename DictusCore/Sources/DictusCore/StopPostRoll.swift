// DictusCore/Sources/DictusCore/StopPostRoll.swift
// The audio a dictation keeps after the stop tap, and when it holds enough of it (#1085).
import Foundation

/// The recording goes on for `margin` after the stop tap, and ends at the first tap buffer
/// that reaches past that point.
///
/// WHY (#1085): the user taps stop while still saying the last word. The samples used to be
/// collected 9 to 39 ms after the tap, and the tap buffer being filled at that moment (85 to
/// 100 ms of audio) arrived after the collection and was dropped. Apple's engine drops the
/// whole last word once about 125 to 150 ms of it are missing (measured on the Mac, the
/// issue's table). 300 ms after the tap covers that with room for a slow tap.
///
/// WHY the end of the buffers and not a sleep: a sleep says how long the app waited, not how
/// much audio it holds. A buffer that ends past the deadline is the proof that every sample
/// up to the deadline has been accumulated, including the one in flight at the tap.
///
/// WHY a give-up time: buffers stop arriving when the engine dies, and the stop must not wait
/// for audio that cannot come. An interruption that takes the input is seen directly
/// (`inputStopped`) and ends the wait at once.
public struct StopPostRoll: Equatable, Sendable {
    /// Audio kept after the tap.
    public static let margin: TimeInterval = 0.3
    /// How long past the deadline the stop waits for the buffer that crosses it. One tap
    /// buffer is 4096 frames: 85 ms at 48 kHz, 256 ms on a 16 kHz Bluetooth route.
    public static let grace: TimeInterval = 0.4

    /// The stop tap, seconds since 1970 (the keyboard's wall clock, `StopTimingTrace`).
    public let tapEpoch: TimeInterval
    /// The post-roll is over once a buffer ends at or after this.
    public let deadlineEpoch: TimeInterval
    /// The post-roll is over at this time whatever has arrived.
    public let giveUpEpoch: TimeInterval

    /// - Parameter startEpoch: when the app began waiting. A tap the app heard late (a busy
    ///   main thread) can have a deadline already behind it; the grace counts from now then.
    public init(tapEpoch: TimeInterval, startEpoch: TimeInterval,
                margin: TimeInterval = StopPostRoll.margin, grace: TimeInterval = StopPostRoll.grace) {
        self.tapEpoch = tapEpoch
        deadlineEpoch = tapEpoch + margin
        giveUpEpoch = max(deadlineEpoch, startEpoch) + grace
    }

    /// How a post-roll ended.
    public enum End: String, Sendable {
        /// A buffer reached the deadline: the full margin is kept.
        case deadline
        /// No buffer reached it in time: whatever arrived is kept.
        case timeout
        /// The input stopped first (an interruption): whatever arrived is kept.
        case inputStopped
    }

    /// Nil while the post-roll should go on.
    public func end(lastBufferEndEpoch: TimeInterval?, inputLive: Bool, now: TimeInterval) -> End? {
        if let last = lastBufferEndEpoch, last >= deadlineEpoch { return .deadline }
        if !inputLive { return .inputStopped }
        if now >= giveUpEpoch { return .timeout }
        return nil
    }

    /// Milliseconds of audio kept after the tap, truncated. Negative when the last buffer ends
    /// before the tap, nil when no buffer arrived at all.
    public func keptAfterTapMs(lastBufferEndEpoch: TimeInterval?) -> Int? {
        lastBufferEndEpoch.map { Int((($0 - tapEpoch) * 1000).rounded(.towardZero)) }
    }

    /// What `wait` saw.
    public enum Outcome: Equatable, Sendable {
        case ended(End)
        /// The recording was collected, cancelled or replaced while waiting. The caller
        /// must not collect: the samples are no longer this stop's.
        case abandoned
    }

    /// Wait until the post-roll is over, polling every `sleep`.
    ///
    /// WHY polling: the samples are appended on the main thread by the tap's dispatch, the
    /// same thread this runs on. A 10 ms poll reads them between appends with no lock and no
    /// continuation to resume exactly once, and costs at most 10 ms of latency.
    ///
    /// - Parameters:
    ///   - lastBufferEndEpoch: the end of the newest buffer accumulated, seconds since 1970.
    ///   - inputLive: false once the engine stopped accumulating (an interruption's teardown).
    ///   - isStillThisRecording: false once anything else collected or replaced the recording.
    @MainActor
    public func wait(
        lastBufferEndEpoch: () -> TimeInterval?,
        inputLive: () -> Bool,
        isStillThisRecording: () -> Bool,
        now: () -> TimeInterval = { Date().timeIntervalSince1970 },
        sleep: () async -> Void = { try? await Task.sleep(nanoseconds: 10_000_000) }
    ) async -> Outcome {
        while true {
            guard isStillThisRecording(), !Task.isCancelled else { return .abandoned }
            if let end = end(lastBufferEndEpoch: lastBufferEndEpoch(), inputLive: inputLive(), now: now()) {
                return .ended(end)
            }
            await sleep()
        }
    }

    /// The log line: `stopTiming step=postRoll keptAfterTapMs=<n> buffers=<n> ended=<end> sessionID=<id>`.
    /// `ended` is an `End`, or `abandoned`.
    public func event(lastBufferEndEpoch: TimeInterval?, buffers: Int, outcome: Outcome, sessionID: String) -> LogEvent {
        let ended: String
        switch outcome {
        case .ended(let end): ended = end.rawValue
        case .abandoned: ended = "abandoned"
        }
        return .stopPostRoll(
            keptAfterTapMs: keptAfterTapMs(lastBufferEndEpoch: lastBufferEndEpoch),
            buffers: buffers,
            ended: ended,
            sessionID: sessionID
        )
    }
}
