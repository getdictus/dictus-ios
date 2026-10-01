// DictusCore/Sources/DictusCore/DriftRetry/DriftRetryClip.swift
// The nine clips one span is re-decoded from, and what is kept of each (#623).
import Foundation

/// One re-decode of a span: a standalone clip of real audio around it.
///
/// WHY nine of them: the measurement that closed #623's track 1 found one window's output
/// chaotic. The same 7.8 s of a clean reading, with only its left context changed, came out
/// empty, as English, or correct. A single re-decode is another roll of the same dice; nine
/// boundaries give the selector something to choose from.
struct DriftRetryClip: Equatable {

    /// First sample of the clip, in call time, on the 80 ms grid.
    let start: Int

    /// One past the last sample of the clip, in call time.
    let end: Int

    /// Candidate tokens emitted before this encoder frame (call time) belong to the left
    /// context and are dropped; `nil` when the clip starts at the span. In the bench this
    /// was FluidAudio's `emitTokensAfterFrame`, which is internal. The decoder updates its
    /// state on a suppressed token exactly as on an emitted one, so filtering after the
    /// fact keeps the same tokens. The step-0 parity run checked that on every file.
    let emitFromFrame: Int?

    /// The nine clips of `span`, in grid order: left context outer, right context inner.
    ///
    /// The v2 edge rule: a span that ends at the end of the call has no audio to its right,
    /// so the three right contexts would give the same clip three times. Instead its clip
    /// end is trimmed by 0, 0.24 or 0.48 s. On the iPhone-like Lecture1 that brought back
    /// an aside every v1 clip had lost.
    static func grid(for span: DriftSpan, totalSamples: Int) -> [DriftRetryClip] {
        let rate = Double(DriftRetryParameters.sampleRate)
        let frame = DriftRetryParameters.samplesPerFrame
        var clips: [DriftRetryClip] = []
        for left in DriftRetryParameters.leftContexts {
            for right in DriftRetryParameters.rightContexts {
                let start = max(0, span.start - Int(left * rate) / frame * frame)
                var end = min(totalSamples, span.end + Int(right * rate))
                if span.end >= totalSamples {
                    let trim = right < 0.5 ? 0.0 : (right < 1.0 ? 0.24 : 0.48)
                    end = max(span.start + DriftRetryParameters.sampleRate / 2, totalSamples - Int(trim * rate) / frame * frame)
                }
                let startFrame = start / frame
                let emitFrom = start < span.start
                    ? max(startFrame, span.start / frame - DriftRetryParameters.edgeToleranceFrames)
                    : nil
                clips.append(DriftRetryClip(start: start, end: end, emitFromFrame: emitFrom))
            }
        }
        return clips
    }

    /// The clip's samples, zero-padded up to the shortest clip FluidAudio accepts.
    func samples(from callSamples: [Float]) -> [Float] {
        var clip = Array(callSamples[start..<min(end, callSamples.count)])
        if clip.count < DriftRetryParameters.minimumClipSamples {
            clip += [Float](repeating: 0, count: DriftRetryParameters.minimumClipSamples - clip.count)
        }
        return clip
    }

    /// What a re-decode contributes to `span`: its tokens moved to call time, the left
    /// context's dropped, then the whole words from 0.32 s before the span to 0.32 s after
    /// it, minus a leading punctuation piece (the previous sentence's full stop).
    func candidate(from timings: [DriftRetryTokenTiming], span: DriftSpan) -> [DriftRetryPiece] {
        let clipStartFrame = start / DriftRetryParameters.samplesPerFrame
        let pieces = timings
            .map { DriftRetryPiece(retry: $0, clipStartFrame: clipStartFrame) }
            .filter { piece in emitFromFrame.map { piece.frame >= $0 } ?? true }
        let tolerance = DriftRetryParameters.edgeToleranceFrames
        let frame = DriftRetryParameters.samplesPerFrame
        let range = DriftRetrySplice.wordRange(
            in: pieces, fromFrame: span.start / frame - tolerance, toFrame: (span.end + frame - 1) / frame + tolerance)
        var kept = Array(pieces[range])
        while let first = kept.first, first.isPunctuation { kept.removeFirst() }
        return kept
    }
}
