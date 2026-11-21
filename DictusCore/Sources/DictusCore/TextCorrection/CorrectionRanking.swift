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
/// - **Close readings are settled, not kept** (#997 device test). When the runner-up
///   costs about the same to reach as the best candidate (within `ambiguousCost`) and
///   scores within `ambiguousScore` of it, the close readings are every candidate that
///   does. A typed word that is not a
///   dictionary word is a typo, and Apple's keyboard corrects `sats` to `sais` on the
///   device although `sans` is as close, so the close reading most often seen after the previous word
///   wins, then the most frequent one: `zrreve` gives `arrive` over `arrête`. The typed
///   word is kept, and the readings only offered, in two cases:
///   - three readings or more, once accents are dropped: `irning` is `irving`,
///     `inning` or `ironing`, and picking one is a guess against two others;
///   - the pick does not score `plausibleScore`: `decalee` is `déclaré` at -0.01, a
///     long way to reach for a rare word, which says the typed word is no worse a
///     reading than it. A typed word scores 0, as it has no frequency and costs nothing.
///   A runner-up that is much cheaper or much dearer to reach is not a close reading:
///   `bookes` gives `booked` (0.40) over `books` (1.00).
/// - **Total order.** Ties fall to the cheaper candidate, then to the word itself.
///
/// The constants were fitted on the #954 bench runs (fr, en, en-typos) and checked on
/// the runs they were not fitted on. `plausibleScore` and `maxCloseReadings` were set on
/// the words those runs keep and on the typos of the #997 device test.
/// `docs/keyboard-measurement.md` says how to rerun them.
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
    /// How much a pick among close readings must score to replace the typed word,
    /// which scores 0.
    public static let plausibleScore = 0.15
    /// More close readings than this, accents dropped, and none is picked.
    public static let maxCloseReadings = 2

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
        let scored = scoredWithContext(candidates)
        guard !scored.isEmpty else { return Decision(replacement: nil, ranked: []) }

        let ranked = scored.map(\.candidate.word)
        let close = closeReadings(scored)
        guard close.count > 1 else { return Decision(replacement: ranked[0], ranked: ranked) }

        let readings = Set(close.map { folded($0.candidate.word) })
        guard readings.count <= maxCloseReadings,
              let pick = close.min(by: isBetterPick),
              pick.score >= plausibleScore
        else { return Decision(replacement: nil, ranked: ranked) }
        return Decision(replacement: pick.candidate.word, ranked: ranked)
    }

    /// The best candidate and every other one as easy to reach and about as likely, when
    /// the runner-up is one of them; empty otherwise. A clear winner stays a clear winner
    /// however many rarer neighbours sit near the runner-up: `rins` gives `runs`, whose
    /// runner-up `find` is a whole key further, although `rims`, `ribs` and `fins` are as
    /// close as `runs` (#997 review).
    private static func closeReadings(_ scored: [Scored]) -> [Scored] {
        guard scored.count > 1, isClose(scored[1], to: scored[0]) else { return [] }
        return scored.filter { isClose($0, to: scored[0]) }
    }

    private static func isClose(_ candidate: Scored, to best: Scored) -> Bool {
        abs(candidate.candidate.cost - best.candidate.cost) <= ambiguousCost
            && best.score - candidate.score < ambiguousScore
    }

    /// Between close readings: the one seen after the previous word, then the more
    /// frequent, then the cheaper, then the word itself.
    private static func isBetterPick(_ lhs: Scored, _ rhs: Scored) -> Bool {
        let l = lhs.candidate, r = rhs.candidate
        if l.context != r.context { return l.context > r.context }
        if l.frequency != r.frequency { return l.frequency > r.frequency }
        if l.cost != r.cost { return l.cost < r.cost }
        return l.word < r.word
    }

    private static func folded(_ word: String) -> String {
        word.folding(options: .diacriticInsensitive, locale: nil)
    }

    private typealias Scored = (candidate: CorrectionCandidate, score: Double)

    /// Every candidate with its score, best first, context added where it may lift.
    private static func scoredWithContext(_ candidates: [CorrectionCandidate]) -> [Scored] {
        let withoutContext = sorted(candidates.map { ($0, priorScore($0)) })
        guard let anchor = withoutContext.first?.candidate else { return [] }
        return sorted(withoutContext.map { candidate, score in
            guard candidate.context > 0, candidate.cost <= anchor.cost + contextWindow else {
                return (candidate, score)
            }
            return (candidate, score + contextWeight * Double(candidate.context) / 65535)
        })
    }

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

    /// The accented spellings to suggest when the accent pass should leave `typed`
    /// alone, because two of them are close readings: `reserve` is `réserve` or
    /// `réservé`. Unlike in `decide`, neither is picked by frequency: the letters typed
    /// are right for both, and the accent meant is a matter of grammar (`avons réservé`)
    /// that the n-gram data does not hold. nil when one spelling is clearly the more
    /// likely, and the accent pass may write it.
    ///
    /// - Parameters:
    ///   - typed: the word as typed, lowercased, without any apostrophe prefix.
    ///   - candidates: the trie's candidates for it. Only those spelled with the same
    ///     letters once accents are dropped take part.
    public static func ambiguousAccentSpellings(typed: String, candidates: [CorrectionCandidate]) -> [String]? {
        let letters = folded(typed)
        let spellings = candidates.filter { $0.word != typed && folded($0.word) == letters }
        let close = closeReadings(scoredWithContext(spellings))
        return close.count > 1 ? close.prefix(2).map(\.candidate.word) : nil
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
