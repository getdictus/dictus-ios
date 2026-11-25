// DictusCore/Sources/DictusCore/TrailingSilence.swift
// Cuts the room noise recorded after the last spoken word before Whisper hears it (#932).
//
// A dictation ends when the user reaches the stop button, so the recording ends with a
// few seconds of room. WhisperKit decodes that tail as a window of its own: its seek loop
// opens a new window whenever more than `windowClipTime` (1 s) of audio is left after the
// last segment, and its VAD chunking gives a long recording's tail a chunk of its own.
// On a window with no words Whisper writes the line its training subtitles end on:
// "Vielen Dank.", "Merci.", "Thank you.", "* Ruhige Musik *". Measured with
// tools/closing-phrase-bench on dictus-test-voices: with a tail recorded, Turbo invented
// an ending on 14 decodes of 100 and Small on 23; with this cut, on none. Parakeet
// invents none without it, and the cut raises its error rate, so it is not applied
// there (docs/research/932-invented-closing-phrases).
import Foundation

public enum TrailingSilence {

    /// Audio kept after the last frame that reads as speech. Below `windowClipTime`, so
    /// the tail can never open a window of its own, and long enough for a final
    /// consonant that decays under the threshold.
    public static let defaultKeptAfterSpeech: TimeInterval = 0.5

    /// Never send less than this. WhisperKit runs no window at all on a buffer of 1 s or
    /// less (see `WarmInferenceAudio`), so a short "Oui" cut to its own 0.8 s would come
    /// back empty. At 1.5 s, the audio left after a word that ends past 0.5 s is under
    /// `windowClipTime` and opens no second window either.
    public static let minimumKept: TimeInterval = 1.5

    /// 50 ms analysis frames.
    static let frameSeconds = 0.05

    /// The number of leading samples to send to the engine: everything up to the end
    /// of the last frame that reads as speech, plus `keptAfterSpeech`, and never under
    /// `minimumKept`. Returns
    /// `samples.count` when nothing reads as speech, so an all-silent buffer still
    /// reaches the engine's own no-speech path.
    ///
    /// A frame reads as speech when its level is within 20 dB of the recording's loud
    /// frames (95th percentile), or 10 dB above its quiet ones (10th percentile),
    /// whichever is lower, and never lower than 40 dB under the loud frames. Relative,
    /// because a quiet microphone and a loud one differ by more than any fixed level:
    /// iPhone pauses measured between -76 and -44 dBFS in dictus-asr-audio. In a room
    /// whose noise is within 20 dB of the voice nothing is cut, which is the behaviour
    /// before #932.
    public static func speechEndSampleCount(
        in samples: [Float],
        sampleRate: Int = 16_000,
        keptAfterSpeech: TimeInterval = defaultKeptAfterSpeech
    ) -> Int {
        let frameLength = Int(Double(sampleRate) * frameSeconds)
        let frameCount = samples.count / frameLength
        guard frameCount > 0 else { return samples.count }

        let levels: [Double] = (0..<frameCount).map { frame in
            var energy: Double = 0
            for sample in samples[(frame * frameLength)..<((frame + 1) * frameLength)] {
                energy += Double(sample) * Double(sample)
            }
            return 10 * log10(energy / Double(frameLength) + 1e-12)
        }
        let sorted = levels.sorted()
        let loud = sorted[Int(Double(frameCount - 1) * 0.95)]
        let quiet = sorted[Int(Double(frameCount - 1) * 0.10)]
        let threshold = max(loud - 40, min(quiet + 10, loud - 20))

        guard let lastSpeechFrame = levels.lastIndex(where: { $0 >= threshold }) else {
            return samples.count
        }
        let end = (lastSpeechFrame + 1) * frameLength + Int(keptAfterSpeech * Double(sampleRate))
        return min(samples.count, max(end, Int(minimumKept * Double(sampleRate))))
    }

    /// `samples` without the silence after the last spoken word.
    public static func trimmed(_ samples: [Float], sampleRate: Int = 16_000) -> [Float] {
        Array(samples.prefix(speechEndSampleCount(in: samples, sampleRate: sampleRate)))
    }
}
