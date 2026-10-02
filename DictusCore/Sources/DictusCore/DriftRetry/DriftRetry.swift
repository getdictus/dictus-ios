// DictusCore/Sources/DictusCore/DriftRetry/DriftRetry.swift
// Parakeet's targeted same-model retry of the spans it drifted on (#623).
//
// WHY THIS EXISTS: Parakeet v3 has no language token. On hard French audio it falls back on
// English, its dominant training language, mid-dictation and with no English in the audio
// (#552). The English it produces is phonetic nonsense, so nothing downstream can repair it.
// But the same model, re-run on the same audio with different boundaries, often gets the
// span right: the outcome of one window is chaotic, not fixed. So the first pass is kept as
// it is, the spans it is unsure of are re-decoded nine ways, and a re-decode replaces the
// first pass only where it is more confident.
//
// Measured offline on the Mac (bench "RC v2"): `moi` 23.36 → 9.35 % WER, 18 → 1 English
// words; `sample2` 39 → 1 English words. No clean recording with an exact reference got
// worse, and most trigger nothing at all: byte-identical, at no extra encoder run. The iPhone
// cost is NOT measured: each triggered span costs nine extra decodes, and on FluidAudio
// 0.15.8 an empty one can cost more (its empty-decode recovery re-runs the window).
import Foundation

/// What the retry did to one call.
public struct DriftRetryOutcome: Equatable, Sendable {

    /// The transcript to use. The first pass's own text, byte for byte, whenever no
    /// re-decode won.
    public let text: String

    /// Spans re-decoded. Zero on a dictation the detector trusts, which is the clean case.
    public let spans: Int

    /// Spans where a re-decode replaced the first pass.
    public let wins: Int
}

public enum DriftRetryError: Error, Equatable {

    /// The first pass's tokens do not rebuild its text. Everything the retry does is
    /// positioned by those tokens, so it refuses to run rather than splice by a wrong map.
    /// The bench checked this on every call and never saw it; it is a guard, not a path.
    case firstPassTokensDoNotMatchText
}

public enum DriftRetry {

    /// Transcribes one clip of 16 kHz mono audio on a FRESH decoder state and returns its
    /// tokens, timed from the clip's first sample. DictusApp supplies it; FluidAudio stays
    /// out of DictusCore.
    public typealias ClipDecoder = (_ clip: [Float]) async throws -> [DriftRetryTokenTiming]

    /// Runs the retry over one engine call.
    ///
    /// - Parameters:
    ///   - samples: The audio the first pass transcribed, 16 kHz mono.
    ///   - firstPassText: The first pass's text, returned unchanged when nothing wins.
    ///   - firstPassTimings: The first pass's tokens, as FluidAudio timed them.
    ///   - decode: Re-decodes one clip. Called nine times per span, one at a time.
    /// - Throws: `DriftRetryError.firstPassTokensDoNotMatchText` before any work, whatever
    ///   `decode` throws, and `CancellationError` between spans when the task is cancelled.
    ///   The caller decides what a failed retry means; it has the first pass either way.
    public static func run(samples: [Float], firstPassText: String, firstPassTimings: [DriftRetryTokenTiming],
                           decode: ClipDecoder) async throws -> DriftRetryOutcome {
        let firstPass = firstPassTimings.map { DriftRetryPiece(firstPass: $0) }
        // Missing timings on a non-empty transcript would read as one long word-free gap,
        // full of speech energy: the whole dictation re-decoded and replaced.
        guard DriftRetryText.text(of: firstPass) == firstPassText.trimmingCharacters(in: .whitespaces) else {
            throw DriftRetryError.firstPassTokensDoNotMatchText
        }
        let energy = SpeechEnergyProfile(samples: samples)
        let spans = DriftSpanDetector.spans(pieces: firstPass, energy: energy, totalSamples: samples.count)
        guard !spans.isEmpty else { return DriftRetryOutcome(text: firstPassText, spans: 0, wins: 0) }

        var choices: [DriftRetryChoice] = []
        for span in spans {
            try Task.checkCancellation()
            let range = DriftRetrySplice.firstPassRange(of: span, in: firstPass)
            let original = Array(firstPass[range])
            var candidates: [[DriftRetryPiece]] = []
            var endTrimmed: Set<Int> = []
            for clip in DriftRetryClip.grid(for: span, totalSamples: samples.count) {
                let timings = try await decode(clip.samples(from: samples))
                if clip.endTrimmed { endTrimmed.insert(candidates.count) }
                candidates.append(clip.candidate(from: timings, span: span))
            }
            if let winner = DriftRetrySelection.winner(candidates: candidates, firstPass: original, endTrimmed: endTrimmed) {
                choices.append(DriftRetryChoice(range: range, pieces: candidates[winner], keepsFirstPass: false))
            } else {
                choices.append(DriftRetryChoice(range: range, pieces: original, keepsFirstPass: true))
            }
        }

        let wins = choices.filter { !$0.keepsFirstPass }.count
        guard wins > 0 else { return DriftRetryOutcome(text: firstPassText, spans: spans.count, wins: 0) }
        let spliced = DriftRetrySplice.splice(firstPass: firstPass, choices: choices)
        return DriftRetryOutcome(text: DriftRetryText.text(of: spliced), spans: spans.count, wins: wins)
    }
}
