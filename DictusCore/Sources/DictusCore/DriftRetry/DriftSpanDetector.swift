// DictusCore/Sources/DictusCore/DriftRetry/DriftSpanDetector.swift
// Which stretches of a Parakeet transcript to re-decode (#623).
import Foundation

/// A stretch of the call to re-decode, in samples, `start` and `end` on the 80 ms grid
/// (`end` may also be the last sample of the call).
struct DriftSpan: Equatable {
    var start: Int
    var end: Int
}

/// Finds the spans of a first pass worth a retry, from its own token confidences and the
/// signal energy. Reads no reference and no language: the detector has to work on the very
/// output it distrusts.
///
/// Two kinds of region, then the same edge treatment for both:
/// - **confidence**: a drift into pseudo-English comes out at a low token confidence. A
///   sliding window of words whose mean is low marks them.
/// - **gap**: a drift also drops words outright. A long stretch with no word that still
///   holds speech energy is content the decoder skipped.
enum DriftSpanDetector {

    /// One word of the first pass: a word-start piece and every continuation after it,
    /// punctuation pieces excluded.
    struct Word: Equatable {
        let start: Double
        let end: Double

        /// The minimum over its pieces: one bad piece makes the word suspect.
        let confidence: Float
    }

    struct Region: Equatable {
        var start: Double
        var end: Double
    }

    static func words(of pieces: [DriftRetryPiece]) -> [Word] {
        var words: [Word] = []
        var index = 0
        while index < pieces.count {
            if pieces[index].isPunctuation { index += 1; continue }
            var last = index
            while last + 1 < pieces.count && !pieces[last + 1].isPunctuation && !pieces[last + 1].isWordStart {
                last += 1
            }
            let confidence = pieces[index...last].map(\.confidence).min() ?? 0
            let end = pieces[last].time + Double(max(1, pieces[last].durationFrames)) * DriftRetryParameters.secondsPerFrame
            words.append(Word(start: pieces[index].time, end: end, confidence: confidence))
            index = last + 1
        }
        return words
    }

    /// The spans to re-decode, sorted, none longer than `maximumSpanSeconds`.
    static func spans(pieces: [DriftRetryPiece], energy: SpeechEnergyProfile, totalSamples: Int) -> [DriftSpan] {
        let duration = Double(totalSamples) / Double(DriftRetryParameters.sampleRate)
        let regions = regions(words: words(of: pieces), energy: energy, duration: duration)
        return split(snapped(regions, energy: energy, totalSamples: totalSamples), energy: energy)
    }

    /// Confidence and gap regions, sorted and merged when closer than `mergeSeconds`.
    static func regions(words: [Word], energy: SpeechEnergyProfile, duration: Double) -> [Region] {
        var regions = confidenceRegions(words: words) + gapRegions(words: words, energy: energy, duration: duration)
        regions.sort { $0.start < $1.start }
        var merged: [Region] = []
        for region in regions {
            if var last = merged.last, region.start <= last.end + DriftRetryParameters.mergeSeconds {
                last.end = max(last.end, region.end)
                merged[merged.count - 1] = last
            } else {
                merged.append(region)
            }
        }
        return merged
    }

    static func confidenceRegions(words: [Word]) -> [Region] {
        let minimum = DriftRetryParameters.minimumRegionWords
        guard words.count >= minimum else { return [] }
        let window = min(DriftRetryParameters.windowWords, words.count)
        var marked = [Bool](repeating: false, count: words.count)
        for first in 0...(words.count - window) {
            let mean = words[first..<(first + window)].map(\.confidence).reduce(0, +) / Float(window)
            if mean < DriftRetryParameters.windowMeanConfidenceThreshold {
                for index in first..<(first + window) { marked[index] = true }
            }
        }
        var regions: [Region] = []
        var index = 0
        while index < words.count {
            guard marked[index] else { index += 1; continue }
            var last = index
            while last + 1 < words.count && marked[last + 1] { last += 1 }
            if last - index + 1 >= minimum { regions.append(Region(start: words[index].start, end: words[last].end)) }
            index = last + 1
        }
        return regions
    }

    /// Word-free stretches, the call's two edges included, that hold speech energy.
    static func gapRegions(words: [Word], energy: SpeechEnergyProfile, duration: Double) -> [Region] {
        var stretches: [(Double, Double)] = []
        var previousEnd = 0.0
        for word in words {
            stretches.append((previousEnd, word.start))
            previousEnd = word.end
        }
        stretches.append((previousEnd, duration))
        return stretches.compactMap { start, end in
            guard end - start >= DriftRetryParameters.gapSeconds else { return nil }
            let speech = energy.speechFrameCount(
                fromSeconds: start, toSeconds: end, margin: DriftRetryParameters.gapEdgeMarginSeconds)
            return speech >= DriftRetryParameters.gapSpeechFrames ? Region(start: start, end: end) : nil
        }
    }

    /// Each region widened outward to a pause (or the quietest nearby frame), moved onto the
    /// encoder grid, and merged with any span it now overlaps.
    static func snapped(_ regions: [Region], energy: SpeechEnergyProfile, totalSamples: Int) -> [DriftSpan] {
        let duration = Double(totalSamples) / Double(DriftRetryParameters.sampleRate)
        let snap = DriftRetryParameters.snapSeconds, fallback = DriftRetryParameters.snapFallbackSeconds
        var spans: [DriftSpan] = []
        for region in regions {
            let start = energy.cutPoint(
                low: max(0, region.start - snap), high: region.start, preferred: region.start,
                fallbackLow: max(0, region.start - fallback), fallbackHigh: region.start)
            var end = energy.cutPoint(
                low: region.end, high: min(duration, region.end + snap), preferred: region.end,
                fallbackLow: region.end, fallbackHigh: min(duration, region.end + fallback))
            // A region that reaches the end of the call keeps the end of the call: nothing
            // past it to snap to.
            if region.end >= duration - 0.01 || end >= totalSamples - DriftRetryParameters.samplesPerFrame {
                end = totalSamples
            }
            let alignedStart = SpeechEnergyProfile.alignedToEncoderFrame(start)
            spans.append(DriftSpan(
                start: alignedStart <= totalSamples ? alignedStart : start,
                end: end == totalSamples ? totalSamples : min(totalSamples, SpeechEnergyProfile.alignedToEncoderFrame(end))))
        }
        var merged: [DriftSpan] = []
        for span in spans.sorted(by: { $0.start < $1.start }) {
            if var last = merged.last, span.start <= last.end {
                last.end = max(last.end, span.end)
                merged[merged.count - 1] = last
            } else {
                merged.append(span)
            }
        }
        return merged
    }

    /// Spans over `maximumSpanSeconds` cut at the pause nearest their middle, again until
    /// none is, never leaving a piece under `minimumPieceSeconds`.
    static func split(_ spans: [DriftSpan], energy: SpeechEnergyProfile) -> [DriftSpan] {
        let rate = Double(DriftRetryParameters.sampleRate)
        let piece = DriftRetryParameters.minimumPieceSeconds
        var result: [DriftSpan] = []
        var pending = Array(spans.reversed())
        while let span = pending.popLast() {
            let startSeconds = Double(span.start) / rate, endSeconds = Double(span.end) / rate
            guard endSeconds - startSeconds > DriftRetryParameters.maximumSpanSeconds else {
                result.append(span)
                continue
            }
            let cut = SpeechEnergyProfile.alignedToEncoderFrame(energy.cutPoint(
                low: startSeconds + piece, high: endSeconds - piece, preferred: (startSeconds + endSeconds) / 2,
                fallbackLow: startSeconds + piece, fallbackHigh: endSeconds - piece))
            pending.append(DriftSpan(start: cut, end: span.end))
            pending.append(DriftSpan(start: span.start, end: cut))
        }
        return result.sorted { $0.start < $1.start }
    }
}
