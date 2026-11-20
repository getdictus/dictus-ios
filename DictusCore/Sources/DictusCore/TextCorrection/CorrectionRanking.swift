// DictusCore/Sources/DictusCore/TextCorrection/CorrectionRanking.swift
// Decides whether an unknown typed word is replaced, and by which candidate (#993).
import Foundation

/// A dictionary word the trie offers for an unknown typed word.
public struct CorrectionCandidate: Equatable, Sendable {
    /// The dictionary word, lowercased, without any apostrophe prefix.
    public let word: String
    /// Weighted edit cost from the typed word, as the trie scores it: about 0.4 for a
    /// neighbouring key, 0.15 for a missing accent, 0.7 for two swapped letters, 1.0 for
    /// a letter too many or too few.
    public let cost: Double
    /// The trie's frequency, log-normalized to 0...65535.
    public let frequency: UInt16
    /// The bigram score of this word after the previous word, 0 when the n-gram data
    /// has no such pair or there is no previous word.
    public let context: UInt16

    public init(word: String, cost: Double, frequency: UInt16, context: UInt16 = 0) {
        self.word = word
        self.cost = cost
        self.frequency = frequency
        self.context = context
    }
}

/// Ranks the trie's candidates for an unknown word and says whether the best one is
/// sure enough to replace what was typed (#993).
///
/// Before this, the first of the trie's top five won whatever it was, and the bigram
/// rerank broke its ties in `Dictionary` order. So `boue` became `blue` or `bone`,
/// and `meef` became `meer` or `meet`, depending on the process's hash seed.
///
/// The score is the candidate's frequency minus what it costs to reach from the
/// typed word, both on the trie's scales:
///
///     score = frequency / 65535 - costWeight * cost
///
/// Three rules sit on top of it:
/// - **Context only between near neighbours.** A bigram after the previous word adds
///   to a candidate's score only when that candidate costs at most `contextWindow`
///   more than the winner without context, one more neighbouring-key slip. So
///   `an boue` gives `hour` (0.85) over `blue` (0.41), and `vers lidi` still gives
///   `midi` (0.40), not the far more frequent `lui` (1.40) that the bigram favours.
///   The window is anchored on that winner, not on the cheapest candidate: a rare
///   cheap word (`if` for German `ic`) must not shut `wenn ich` out.
/// - **Keep the typed word when two readings are equally good.** When the runner-up
///   costs about the same to reach (within `ambiguousCost`) and scores within
///   `ambiguousScore`, nothing says which one was meant: `reùion` is `région` or
///   `réunion`, `irning` is `irving` or `inning`. Replacing would be a coin toss, so the
///   word stays as typed. A runner-up that is much cheaper or much dearer to reach does
///   not make the choice ambiguous: `bookes` gives `booked` (0.40) over `books` (1.00).
/// - **Total order.** Ties fall to the cheaper candidate, then to the word itself.
///
/// The constants were fitted on the #954 bench runs (fr, en, en-typos) and checked on
/// the runs they were not fitted on. `docs/keyboard-measurement.md` says how to rerun
/// them.
public enum CorrectionRanking {

    /// What one unit of edit cost is worth in normalized frequency.
    public static let costWeight = 0.35
    /// How much a full-scale bigram score adds to a candidate's score.
    public static let contextWeight = 0.5
    /// How much dearer than the cheapest candidate a candidate may be and still be
    /// lifted by context.
    public static let contextWindow = 0.5
    /// Two candidates closer than this in cost are equally easy to have mistyped.
    public static let ambiguousCost = 0.25
    /// Two such candidates closer than this in score are equally likely.
    public static let ambiguousScore = 0.12

    public struct Decision: Equatable, Sendable {
        /// The word to write instead of the typed one, or nil to keep what was typed.
        public let replacement: String?
        /// Every candidate, best first.
        public let ranked: [String]
    }

    public static func decide(_ candidates: [CorrectionCandidate]) -> Decision {
        let withoutContext = sorted(candidates.map { ($0, priorScore($0)) })
        guard let anchor = withoutContext.first?.candidate else {
            return Decision(replacement: nil, ranked: [])
        }

        let scored = sorted(withoutContext.map { candidate, score in
            guard candidate.context > 0, candidate.cost <= anchor.cost + contextWindow else {
                return (candidate, score)
            }
            return (candidate, score + contextWeight * Double(candidate.context) / 65535)
        })

        let ranked = scored.map(\.candidate.word)
        if scored.count > 1 {
            let best = scored[0], runnerUp = scored[1]
            let ambiguous = abs(best.candidate.cost - runnerUp.candidate.cost) <= ambiguousCost
                && best.score - runnerUp.score < ambiguousScore
            if ambiguous { return Decision(replacement: nil, ranked: ranked) }
        }
        return Decision(replacement: ranked[0], ranked: ranked)
    }

    private typealias Scored = (candidate: CorrectionCandidate, score: Double)

    private static func priorScore(_ candidate: CorrectionCandidate) -> Double {
        Double(candidate.frequency) / 65535 - costWeight * candidate.cost
    }

    private static func sorted(_ scored: [Scored]) -> [Scored] {
        scored.sorted { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            if lhs.candidate.cost != rhs.candidate.cost { return lhs.candidate.cost < rhs.candidate.cost }
            return lhs.candidate.word < rhs.candidate.word
        }
    }

    /// Whether the accent pass should leave `typed` alone because two accented
    /// spellings of its letters are equally likely: `reserve` is `réserve` or
    /// `réservé`, and picking one is the same coin toss as in `decide`.
    ///
    /// - Parameters:
    ///   - typed: the word as typed, lowercased, without any apostrophe prefix.
    ///   - candidates: the trie's candidates for it. Only those spelled with the same
    ///     letters once accents are dropped take part.
    public static func accentSpellingIsAmbiguous(typed: String, candidates: [CorrectionCandidate]) -> Bool {
        let letters = typed.folding(options: .diacriticInsensitive, locale: nil)
        let spellings = candidates.filter {
            $0.word != typed && $0.word.folding(options: .diacriticInsensitive, locale: nil) == letters
        }
        return spellings.count > 1 && decide(spellings).replacement == nil
    }
}
