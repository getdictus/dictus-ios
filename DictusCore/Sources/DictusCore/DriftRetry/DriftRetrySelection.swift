// DictusCore/Sources/DictusCore/DriftRetry/DriftRetrySelection.swift
// Which of a span's re-decodes replaces the first pass, if any (#623).
import Foundation

enum DriftRetrySelection {

    /// The index of the winning candidate, or `nil` when the first pass keeps the span.
    ///
    /// The highest mean piece confidence among the candidates AND the first pass's own span;
    /// the first pass wins ties, and a candidate with no word has no score. Same signal as
    /// the detector: a wrong re-decode is typically empty or English at ~0.65–0.75, a right
    /// one sits at 0.95 and above.
    ///
    /// NOT a majority vote, though "the right reading recurs" sounds as plausible: measured,
    /// it put English back into a clean reading (Lecture1, 2 → 6 English words, WER up).
    ///
    /// A candidate decoded from an END-TRIMMED clip (the v2 edge rule, `endTrimmed`) must
    /// also reach the end of the first pass's span (PR #630 review). That clip lost the last
    /// 0.24 or 0.48 s of audio by construction, so a confident candidate that stops early
    /// there has dropped real words, and the splice would lose them. Every other candidate
    /// keeps the measured RC v2 rule: applied to all of them, the same check rejected
    /// re-decodes that rightly stop before a hallucinated tail (`mono` 62.56 → 65.79 % WER,
    /// 214 → 231 English words; Natural2's trailing `ol` restored).
    static func winner(candidates: [[DriftRetryPiece]], firstPass: [DriftRetryPiece],
                       endTrimmed: Set<Int> = []) -> Int? {
        var winner: Int?
        var best = DriftRetryText.meanConfidence(of: firstPass) ?? -1
        for (index, candidate) in candidates.enumerated() {
            guard let score = DriftRetryText.meanConfidence(of: candidate), score > best,
                  !endTrimmed.contains(index) || reachesEnd(candidate, of: firstPass) else { continue }
            best = score
            winner = index
        }
        return winner
    }

    /// The candidate's last word ends no more than `edgeToleranceFrames` before the first
    /// pass's last word does. Always true for a gap span, where the first pass has no word.
    static func reachesEnd(_ candidate: [DriftRetryPiece], of firstPass: [DriftRetryPiece]) -> Bool {
        guard let firstPassLast = firstPass.last(where: { !$0.isPunctuation }) else { return true }
        guard let candidateLast = candidate.last(where: { !$0.isPunctuation }) else { return false }
        let required = firstPassLast.frame + firstPassLast.durationFrames - DriftRetryParameters.edgeToleranceFrames
        return candidateLast.frame + candidateLast.durationFrames >= required
    }
}
