// DictusCore/Sources/DictusCore/DriftRetry/DriftRetryParameters.swift
// The measured numbers behind Parakeet's targeted same-model retry (#623).
import Foundation

/// Every parameter of the retry, in one place, as measured.
///
/// WHY constants and not settings: each value was chosen on the #552 recordings and frozen
/// before a held-out set was run, design "RC v2" in the maintainer's offline bench
/// (`dictus-bench/623-windows/retry/RESULTS.md`, section "Design"). That bench is the only
/// evidence the retry helps without hurting a clean dictation. A value changed here without
/// re-running it is a value nobody has measured.
enum DriftRetryParameters {

    // MARK: Audio geometry

    /// The whole dictation pipeline runs at 16 kHz mono.
    static let sampleRate = 16_000

    /// One Parakeet encoder frame: 1 280 samples, 80 ms. Token timestamps come in these.
    static let samplesPerFrame = 1_280

    /// `samplesPerFrame` in seconds.
    static let secondsPerFrame = 0.08

    /// FluidAudio refuses a clip shorter than this. A shorter re-decode clip is zero-padded
    /// up to it, as the bench did.
    static let minimumClipSamples = 16_000

    // MARK: Detector, confidence region

    /// Words per sliding confidence window.
    static let windowWords = 6

    /// A window whose mean word confidence is below this marks its words. Drifted segments
    /// had a median confidence of 0.705 in #623's track 1, clean ones 0.970.
    static let windowMeanConfidenceThreshold: Float = 0.80

    /// A run of marked words shorter than this is not a region. Also why a dictation of one
    /// or two words never triggers: #554 logged 0.512 on a one-word dictation.
    static let minimumRegionWords = 3

    // MARK: Detector, gap region (dropped content)

    /// A stretch without any word at least this long can be a gap region...
    static let gapSeconds = 2.0

    /// ...when it holds at least this many 10 ms frames at or above the speech gate. The
    /// first draft (80 frames) fired on French hesitations, which Parakeet does not write.
    static let gapSpeechFrames = 150

    /// Frames this close to either edge of a gap are not counted: they belong to the words
    /// on each side.
    static let gapEdgeMarginSeconds = 0.2

    // MARK: Region edges

    /// Regions closer than this merge into one.
    static let mergeSeconds = 0.5

    /// How far outward an edge looks for a pause.
    static let snapSeconds = 1.5

    /// Without a pause, how far outward it looks for the quietest 80 ms frame instead.
    static let snapFallbackSeconds = 0.6

    /// A pause is at least this long under the silence threshold.
    static let minimumPauseSeconds = 0.15

    /// A longer span is split, so that span plus both contexts stays inside Parakeet's
    /// 15 s window: one encoder run per re-decode.
    static let maximumSpanSeconds = 11.0

    /// A split never leaves a piece shorter than this.
    static let minimumPieceSeconds = 2.0

    // MARK: Re-decode

    /// Seconds of real audio before the span, one per re-decode row.
    static let leftContexts: [Double] = [0, 0.48, 1.44]

    /// Seconds of real audio after the span, one per re-decode column. Never 0: a clip that
    /// stops at the span's end cut its last word on the dev set.
    static let rightContexts: [Double] = [0.24, 0.72, 1.44]

    /// A re-decode times an edge word a few frames off the first pass, so a candidate keeps
    /// tokens from this many frames (0.32 s) before the span to as many after it.
    static let edgeToleranceFrames = 4

    // MARK: Splice

    /// Seam dedupe looks at most this many words on each side.
    static let maximumSeamDedupeWords = 3

    /// How many tokens across a seam the dedupe compares against.
    static let seamContextTokens = 12
}
