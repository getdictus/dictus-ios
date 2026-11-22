// DictusCore/Sources/DictusCore/TextCorrection/AccentRestoration.swift
// Decides which accented spelling of the typed letters to write, from corpus counts and context (#994).
import Foundation

/// Decides whether a word typed without its accents gets them back, from the corpus
/// counts of its spellings and the previous word (#994).
///
/// Each spelling's odds are its corpus count, times `participleContextOdds` when it is
/// a participle the previous word calls for (`ParticipleContext`). Then:
/// - **The typed word stays** unless the best accented spelling's odds are
///   `typedWordOdds` times its count. Without context `manana` gives `mañana` (275x)
///   and `numero` gives `número` (16x), but `publie` stays (`publié` is 3.6x) and so
///   does `esta` (`está` is 2.3x). After `est`, `arrive` gives `arrivé`: 0.41x the
///   count of `arrive`, times 100.
/// - **Two accented spellings within `ambiguousOdds`** of each other leave the typed
///   word, and both are offered: `reserve` is `réserve` (2182) or `réservé` (1372).
///   After `avons`, `réservé` is the clear choice.
///
/// The counts are the ones the dictionary was built from, recovered from the trie
/// (`FrequencyScale`). Before this, the rule compared the trie's log-scaled values,
/// where a 28x ratio is about 1.3x, so it almost never fired for a word that exists
/// without its accent.
public enum AccentRestoration {

    /// How much likelier than the typed word an accented spelling must be to replace it.
    /// The typed word is what the typist wrote, so it wins anything closer.
    public static let typedWordOdds = 10.0
    /// How much likelier a participle becomes after a word that calls for one: `est
    /// arrive` is nearly never meant, whatever the counts of `arrive` and `arrivé`.
    /// `il est calme` still stays, because `calmé` is 0.05x `calme`.
    public static let participleContextOdds = 100.0
    /// Two accented spellings closer than this are a coin toss.
    public static let ambiguousOdds = 3.0

    /// A spelling of the typed letters that the dictionary has.
    public struct Spelling: Equatable, Sendable {
        public let word: String
        /// Its count in the corpus the dictionary was built from.
        public let count: Double

        public init(word: String, count: Double) {
            self.word = word
            self.count = count
        }
    }

    public enum Decision: Equatable, Sendable {
        /// Leave what was typed: no accented spelling, or none likely enough.
        case keepTyped
        /// Write this accented spelling instead of the typed word.
        case restore(String)
        /// Leave what was typed and offer these two spellings, best first.
        case ambiguous([String])
    }

    /// - Parameters:
    ///   - typed: the typed word as the dictionary has it, nil when it is not a word.
    ///   - accented: the accented spellings the dictionary has.
    ///   - isExpectedParticiple: whether the previous word calls for this spelling.
    public static func decide(
        typed: Spelling?,
        accented: [Spelling],
        isExpectedParticiple: (Spelling) -> Bool = { _ in false }
    ) -> Decision {
        let ranked = accented
            .map { ($0, $0.count * (isExpectedParticiple($0) ? participleContextOdds : 1)) }
            .sorted { lhs, rhs in lhs.1 != rhs.1 ? lhs.1 > rhs.1 : lhs.0.word < rhs.0.word }
        guard let best = ranked.first else { return .keepTyped }
        if let typed, best.1 < typedWordOdds * typed.count { return .keepTyped }
        if ranked.count > 1, best.1 < ambiguousOdds * ranked[1].1 {
            return .ambiguous([best.0.word, ranked[1].0.word])
        }
        return .restore(best.0.word)
    }
}
