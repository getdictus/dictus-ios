// DictusCore/Sources/DictusCore/VoiceNotes/VoiceNoteChunker.swift
// Where to cut a long voice note so it can be transcribed, and reported on, in parts (#620).
import Foundation

/// Splits a decoded voice note into chunks cut at its quietest moments.
///
/// ### Why Dictus cuts at all, when every engine already chunks internally
///
/// The #620 spike is right that no engine needs it: Parakeet windows at 15 s,
/// Whisper uses `.vad`, Nemotron takes the whole buffer. What the engines do not give
/// is **progress**, and the decision is to drive the Live Activity with it — a ten
/// minute note is a minute of silence on the Dynamic Island otherwise. A chunk is
/// also the unit at which a dictation can take the engine back (see
/// `EngineAccessGate`): the queue yields between chunks, so a dictation started
/// mid-note waits at most for one chunk, never for the whole note.
///
/// ### Why at the quietest point, and why 45 seconds
///
/// A cut through a word costs that word in both halves. Cutting at the lowest-energy
/// 100 ms frame inside the last ten seconds of each window puts the boundary in a
/// pause whenever the speaker pauses at all, which in a voice message is every few
/// seconds. 45 s keeps a ten-minute note at about thirteen progress steps while
/// leaving each chunk long enough that Whisper's own 30 s windows and VAD still
/// work as they do on a dictation.
public enum VoiceNoteChunker {

    /// The longest a chunk is cut at, in seconds, unless the tail rule extends it.
    public static let targetSeconds: TimeInterval = 45
    /// How far back from the target the cut may move to land in a pause.
    public static let searchWindowSeconds: TimeInterval = 10
    /// A tail shorter than this is merged into the chunk before it rather than sent
    /// to an engine on its own: a two-second scrap is a hallucination risk for
    /// Whisper and buys no progress step worth having.
    public static let minimumTailSeconds: TimeInterval = 10
    /// The energy frame the quiet point is chosen on.
    static let frameSeconds: TimeInterval = 0.1

    /// The ranges, in sample indices, that cover `samples` end to end without
    /// overlap. A note no longer than the target is one range.
    public static func ranges(for samples: [Float],
                              sampleRate: Double = SharedAudioDecoder.sampleRate,
                              target: TimeInterval = targetSeconds,
                              searchWindow: TimeInterval = searchWindowSeconds,
                              minimumTail: TimeInterval = minimumTailSeconds) -> [Range<Int>] {
        let total = samples.count
        guard total > 0 else { return [] }
        let targetLength = Int(target * sampleRate)
        let minimumTailLength = Int(minimumTail * sampleRate)
        guard total > targetLength + minimumTailLength else { return [0..<total] }

        let frameLength = max(1, Int(frameSeconds * sampleRate))
        let windowLength = Int(searchWindow * sampleRate)
        var ranges: [Range<Int>] = []
        var start = 0

        while total - start > targetLength + minimumTailLength {
            let windowEnd = start + targetLength
            let windowStart = max(start + frameLength, windowEnd - windowLength)
            let cut = quietestFrameCentre(in: samples, from: windowStart, to: windowEnd, frameLength: frameLength)
            ranges.append(start..<cut)
            start = cut
        }
        ranges.append(start..<total)
        return ranges
    }

    /// The centre of the lowest-energy frame in `[from, to)`. Ties go to the latest
    /// frame, which keeps chunks as long as the window allows.
    static func quietestFrameCentre(in samples: [Float], from: Int, to: Int, frameLength: Int) -> Int {
        var bestEnergy = Float.greatestFiniteMagnitude
        var bestCentre = to
        var frameStart = from
        while frameStart + frameLength <= to {
            var energy: Float = 0
            for index in frameStart..<(frameStart + frameLength) {
                energy += samples[index] * samples[index]
            }
            if energy <= bestEnergy {
                bestEnergy = energy
                bestCentre = frameStart + frameLength / 2
            }
            frameStart += frameLength
        }
        return bestCentre
    }
}
