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
    static func winner(candidates: [[DriftRetryPiece]], firstPass: [DriftRetryPiece]) -> Int? {
        var winner: Int?
        var best = DriftRetryText.meanConfidence(of: firstPass) ?? -1
        for (index, candidate) in candidates.enumerated() {
            guard let score = DriftRetryText.meanConfidence(of: candidate), score > best else { continue }
            best = score
            winner = index
        }
        return winner
    }
}
