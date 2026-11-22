// DictusCore/Sources/DictusCore/TextCorrection/GluedWordSplit.swift
// Picks the split of a glued word and writes its halves with their accents (#499, #1006).
import Foundation

/// Picks which split of a glued word the split pass proposes, and writes its halves
/// the way the accent pass writes a word (#1006).
///
/// `TextPredictionEngine.trySplit` finds the candidates in the trie. The
/// choice and the writing live here, where `swift test` reaches them.
public enum GluedWordSplit {

    /// How much a bigram point weighs against the product of the halves' frequencies.
    public static let bigramWeight: UInt64 = 1000

    /// One way to cut the typed word in two.
    public struct Candidate: Equatable, Sendable {
        public let left: String
        public let right: String
        /// A key next to the spacebar sat between the halves and was dropped.
        public let usesBoundaryKey: Bool
        /// The bigram score of `right` after `left`.
        public let bigram: UInt16
        /// The bigram score of `left` after the previous word, 0 without one.
        public let contextBigram: UInt16
        /// The product of the two halves' stored frequencies.
        public let frequencyProduct: UInt64

        public init(
            left: String, right: String, usesBoundaryKey: Bool,
            bigram: UInt16, contextBigram: UInt16 = 0, frequencyProduct: UInt64
        ) {
            self.left = left
            self.right = right
            self.usesBoundaryKey = usesBoundaryKey
            self.bigram = bigram
            self.contextBigram = contextBigram
            self.frequencyProduct = frequencyProduct
        }

        public var hasBigram: Bool { bigram > 0 }

        /// 64 bits: two stored frequencies near 65535 already fill 32.
        var score: UInt64 {
            frequencyProduct + Self.weighted(bigram) + Self.weighted(contextBigram)
        }

        private static func weighted(_ bigram: UInt16) -> UInt64 { UInt64(bigram) * bigramWeight }
    }

    /// The candidate to propose, nil when there is none.
    ///
    /// A bigram between the halves comes first: `donnequoi` is `donne quoi`, with
    /// one, and not `don quoi`, cut at the `n` next to the spacebar but without one.
    /// Then a dropped spacebar neighbour, the physical sign of a missed space. Then the
    /// score, then the text, so the answer never depends on the order of the candidates.
    public static func best(_ candidates: [Candidate]) -> Candidate? {
        candidates.min { lhs, rhs in
            if lhs.hasBigram != rhs.hasBigram { return lhs.hasBigram }
            if lhs.usesBoundaryKey != rhs.usesBoundaryKey { return lhs.usesBoundaryKey }
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return (lhs.left, lhs.right) < (rhs.left, rhs.right)
        }
    }

    /// The two halves as the accent pass writes them, separated by a space: `suis
    /// arrive` is written `suis arrivé`. The left half is read after `previousWord`,
    /// the right half after the left one. An ambiguous half stays as it was typed.
    /// - Parameter restore: the accent pass for one word after a previous one.
    public static func written(
        _ candidate: Candidate,
        previousWord: String?,
        restore: (String, String?) -> AccentRestoration.Decision
    ) -> String {
        let left = accented(candidate.left, after: previousWord, restore: restore)
        let right = accented(candidate.right, after: left, restore: restore)
        return "\(left) \(right)"
    }

    private static func accented(
        _ word: String,
        after previousWord: String?,
        restore: (String, String?) -> AccentRestoration.Decision
    ) -> String {
        if case .restore(let spelling) = restore(word, previousWord) { return spelling }
        return word
    }
}
