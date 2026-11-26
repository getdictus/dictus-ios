// DictusApp/Audio/UnifiedAudioEngine+PostRoll.swift
// The audio a stop keeps after its tap (#1085): the wait, and the buffer clock it reads.
//
// WHY a file of its own: UnifiedAudioEngine.swift sits at the file_length budget of #146.
// The bookkeeping the wait reads (`lastAccumulatedBufferEndEpoch`, `accumulatedBufferCount`,
// `recordingEpoch`) stays in the main file, next to the sample gate that writes it, and is
// `private(set)` so only that file changes it.
@preconcurrency import AVFoundation
import DictusCore

extension UnifiedAudioEngine {
    /// Keep recording through `postRoll`, then collect (#1085): the end of the last word the
    /// user was still saying at the tap, and the tap buffer in flight at that moment.
    ///
    /// Nil when the wait was abandoned (a cancel, or another collection): the samples are
    /// not this stop's any more, and the caller must not report anything from them.
    ///
    /// WHY `isRecording` stays true through the wait: it is the gate the tap's main-thread
    /// dispatch reads, so every buffer up to the deadline is accumulated, and the one in
    /// flight at the tap with them. The stop sound plays after this returns, so it is
    /// never recorded.
    func collectSamples(after postRoll: StopPostRoll, sessionID: String) async -> [Float]? {
        let epoch = recordingEpoch
        let buffersAtStop = accumulatedBufferCount
        let outcome = await postRoll.wait(
            lastBufferEndEpoch: { self.lastAccumulatedBufferEndEpoch },
            inputLive: { self.isRecording },
            isStillThisRecording: { self.recordingEpoch == epoch }
        )
        PersistentLog.log(postRoll.event(
            lastBufferEndEpoch: lastAccumulatedBufferEndEpoch,
            buffers: accumulatedBufferCount - buffersAtStop,
            outcome: outcome,
            sessionID: sessionID
        ))
        guard case .ended = outcome else { return nil }
        return collectSamples()
    }

    /// When the buffer's last sample was captured, on the wall clock the keyboard's stop tap
    /// is stamped with (`StopTimingTrace`), so a post-roll can measure its audio against
    /// the tap (#1085).
    ///
    /// The tap's `AVAudioTime` carries the host time of the buffer's first sample; the
    /// offset between it and the host clock now moves it onto the wall clock. A buffer
    /// without a valid host time is stamped with its arrival, which is later than its
    /// audio by the input latency: the post-roll then ends a few ms early, never late.
    nonisolated static func wallClockEnd(
        of buffer: AVAudioPCMBuffer, at time: AVAudioTime, now: TimeInterval
    ) -> TimeInterval {
        guard time.isHostTimeValid, buffer.format.sampleRate > 0 else { return now }
        let startHostSeconds = AVAudioTime.seconds(forHostTime: time.hostTime)
        let nowHostSeconds = AVAudioTime.seconds(forHostTime: mach_absolute_time())
        return now - (nowHostSeconds - startHostSeconds) + Double(buffer.frameLength) / buffer.format.sampleRate
    }
}
