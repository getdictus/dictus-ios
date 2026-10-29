// DictusCore/Sources/DictusCore/InterruptedDictationPolicy.swift
// What a dictation does when an audio interruption cuts it (#851).
// Testable in isolation -- the coordinator supplies the status and the captured audio.

import Foundation

/// What stopped the engine under the dictation. Both arrive as the same
/// `dictusAudioSessionInterrupted` post; the engine says which one it was.
public enum DictationInterruptionCause: String, Equatable, Sendable {
    /// An `AVAudioSession` interruption `.began`: a call, Siri, another app.
    case interruption
    /// `mediaServicesWereReset`: the audio server died and the engine was replaced.
    case mediaServicesReset
}

/// The dictation's answer to an interruption. The raw value is the log token.
public enum InterruptedDictationDecision: String, Equatable, Sendable {
    /// Stop as if the user had tapped stop, and transcribe what was captured.
    case transcribeCaptured
    /// Too little was captured to transcribe: the "no words" notice of a stop tapped a
    /// beat early, not a failure.
    case discardTooShort
    /// The audio was already collected; the transcription does not need the microphone.
    case letTranscriptionFinish
    /// Nothing to keep: the dictation fails, as every interruption did before #851.
    case fail
}

public enum InterruptedDictationPolicy {

    /// The decision for a dictation in `status` when an interruption arrives.
    ///
    /// WHY the recording is never resumed, only ended: `InterruptionResumePolicy`
    /// skips a recording on purpose (#353). Restarting the microphone after a call,
    /// behind the user's back, is the one thing worse than losing the audio.
    ///
    /// WHY a media services reset still fails: the reset replaces the engine under a
    /// tap that may be mid-write, and no device log has shown what the buffer holds
    /// afterwards. The reset is rare; the call is not. Only the measured case changes.
    ///
    /// - Parameters:
    ///   - capturedSeconds: the audio the engine holds, in seconds.
    ///   - minimum: the shortest clip a stop transcribes (the coordinator's
    ///     `minimumRecordingDuration`); a clip of exactly `minimum` is transcribed.
    public static func decide(
        status: DictationStatus,
        cause: DictationInterruptionCause,
        capturedSeconds: Double,
        minimum: Double
    ) -> InterruptedDictationDecision {
        guard cause == .interruption else { return .fail }
        switch status {
        case .recording:
            return capturedSeconds >= minimum ? .transcribeCaptured : .discardTooShort
        case .transcribing, .processing:
            return .letTranscriptionFinish
        case .idle, .requested, .ready, .failed:
            return .fail
        }
    }
}
