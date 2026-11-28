// DictusCore/Sources/DictusCore/LanguageDetection/LanguageEvidenceSource.swift
// What one language's dictionary answers when detection asks about a typed word (#1009).
import Foundation

/// One language's dictionary, as the language vote and the keep rule question it.
///
/// Production: the keyboard's trie and n-grams for that language. Tests: a stub.
/// Same split as `FrequencyProvider`: the decisions are pure logic over these answers,
/// so they are tested here without the C++ trie.
public protocol LanguageEvidenceSource {
    var language: SupportedLanguage { get }

    /// The word's log-frequency in nats below the language's most frequent word (0 for
    /// that word, negative for every other), or nil when the dictionary does not have it.
    /// See `TrieFrequencyScale` for why the stored frequency cannot be used as is.
    func logFrequency(of word: String) -> Double?

    /// The dictionary word reached by adding accents (`tres` → `très`), if any.
    func accentExpansion(_ word: String) -> String?

    /// The contraction reached by inserting an apostrophe (`cest` → `c'est`), if any.
    func contractionExpansion(_ word: String) -> String?

    /// The dictionary's own correction of `word` (overrides, then edit distance), if any.
    func correction(of word: String) -> String?

    /// How strongly the n-grams expect `word` after `previous`, from 0 to 1.
    func bigram(_ word: String, after previous: String) -> Double
}

/// Turns the trie's stored frequency into nats below the language's most frequent word.
///
/// WHY the stored value is not comparable across languages: `tools/dict_builder.py`
/// stores `65535 · ln(1 + count) / ln(1 + topCount)`, normalised by each corpus's own top
/// count. The French counts are subtitles (top word 2.9 million), the English counts
/// Google Books (top word 23 billion), so an English word reads about 0.15 higher than a
/// French word of the same rank. Measured in #1007: compared raw, `projet` and `client`
/// vote English. Nats below the top word put both languages on one scale.
public struct TrieFrequencyScale: Sendable {
    private let logOfTopCount: Double

    /// `topCount`: the highest count in the corpus the trie was built from.
    public init(topCount: Double) {
        logOfTopCount = log(1 + topCount)
    }

    public func logFrequency(stored: UInt16) -> Double {
        (Double(stored) / 65535 - 1) * logOfTopCount
    }
}
