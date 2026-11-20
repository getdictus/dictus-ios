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
    /// How much dearer than the winner without context a candidate may be and still
    /// be lifted by context.
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

        /// What the bar and the space bar get from this decision: the replacement, or,
        /// when the typed word is kept, the best two candidates as suggestions only.
        /// nil when there is no candidate at all.
        public var proposal: CorrectionProposal? {
            if let replacement {
                return .autocorrect(replacement, alternatives: Array(ranked.filter { $0 != replacement }.prefix(2)))
            }
            return ranked.isEmpty ? nil : .suggest(Array(ranked.prefix(2)))
        }
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
}

/// What the corrector proposes for the word being typed (#993).
public enum CorrectionProposal: Equatable, Sendable {
    /// Written in place of the typed word on space, and shown in the bar's bold slot.
    case autocorrect(String, alternatives: [String])
    /// Shown in the bar for a tap, never written on space: the corrector keeps the
    /// typed word because no candidate is sure enough, as Apple's keyboard does.
    case suggest([String])

    /// The correction the space bar applies, or nil for a suggestion.
    public var autocorrection: (correction: String, alternatives: [String])? {
        guard case let .autocorrect(correction, alternatives) = self else { return nil }
        return (correction, alternatives)
    }

    /// The same proposal with every word passed through `transform`, the casing and
    /// apostrophe prefix the caller restores.
    public func mapWords(_ transform: (String) -> String) -> CorrectionProposal {
        switch self {
        case let .autocorrect(correction, alternatives):
            return .autocorrect(transform(correction), alternatives: alternatives.map(transform))
        case let .suggest(words):
            return .suggest(words.map(transform))
        }
    }

    /// The bar row for a suggestion: the typed word first, which keeps it on a tap,
    /// then up to two candidates. No slot is the one space applies. nil for an
    /// autocorrection, whose row `LearnedWordCompletions.correctionsRow` builds.
    public func suggestionRow(typedWord: String) -> [String]? {
        guard case let .suggest(words) = self else { return nil }
        let offered = words.filter { $0 != typedWord }.prefix(2)
        return offered.isEmpty ? nil : [typedWord] + offered
    }
}
