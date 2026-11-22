// DictusCore/Sources/DictusCore/TextCorrection/FrequencyProvider.swift
// Protocol that abstracts the dictionary backend used by autocorrect helpers.
import Foundation

/// Abstracts the dictionary backend so autocorrect helpers (`AccentExpander`,
/// `ContractionExpander`) can be unit-tested without the C++ trie bridge.
///
/// Production: `AOSPTrieEngine` adapts the AOSP trie via this protocol.
/// Tests: a stub provider returns controlled frequencies for golden inputs.
///
/// WHY this exists:
/// The autocorrect algorithms (accent restoration, contraction split,
/// override lookup) are pure logic that depends only on per-word frequency and
/// existence checks. Decoupling them from `AOSPTrieBridge` lets the regression
/// tests live in `DictusCoreTests` without dragging the C++ bridge into the
/// test bundle.
public protocol FrequencyProvider {
    /// Whether the underlying dictionary is loaded and ready for lookups.
    /// Algorithms early-return when false.
    var isReady: Bool { get }

    /// Returns the frequency of `word` in the dictionary, or 0 if not present.
    func frequency(of word: String) -> UInt16

    /// Returns true if `word` exists in the dictionary.
    /// Used as a fallback when frequency is 0 but the word may still be valid.
    func wordExists(_ word: String) -> Bool

    /// The scale `frequency(of:)` answers on.
    var frequencyScale: FrequencyScale { get }
}

/// The scale a `FrequencyProvider` stores frequencies on, and the way back to the
/// corpus count that a ratio between two words needs (#994).
public enum FrequencyScale: Equatable, Sendable {
    /// The value is the corpus count.
    case corpusCount
    /// The value is `65535 * ln(1 + count) / ln(1 + maxCount)`, truncated: what
    /// `tools/dict_builder.py` writes into each trie node, with `maxCount` in the
    /// dictionary header. A 28x ratio between two counts is about 1.3x between their
    /// stored values, but the log is invertible: the count comes back within 0.03 %.
    case logNormalized(maxCount: UInt32)

    /// The corpus count a stored frequency stands for.
    public func corpusCount(fromStored stored: UInt16) -> Double {
        switch self {
        case .corpusCount:
            return Double(stored)
        case .logNormalized(let maxCount):
            return exp(Double(stored) / 65535 * log(1 + Double(maxCount))) - 1
        }
    }
}

public extension FrequencyProvider {

    /// The corpus count of `word`, 0 when the dictionary does not have it.
    func corpusCount(of word: String) -> Double {
        frequencyScale.corpusCount(fromStored: frequency(of: word))
    }

    /// Whether the dictionary already knows `word`, asked exactly the way the
    /// corrector asks it (#287): lowercased, and for a contraction only the part
    /// after the last apostrophe — "j'ai" is stored in the trie as "ai", and
    /// `TextPredictionEngine.spellCheck` splits the same way before its
    /// `already-valid` skip.
    ///
    /// WHY this lives on the protocol rather than at either call site: the two
    /// users of it are the word-boundary learning gate in the keyboard extension
    /// and the duplicate prune in `UserDictionary`, and a word must mean the same
    /// thing to both — a gate that refuses to learn "j'ai" while the prune keeps
    /// it would leave entries no reader can reach.
    func knowsWord(_ word: String) -> Bool {
        let lowered = word.lowercased()
        guard let apostrophe = lowered.lastIndex(of: "'") else {
            return wordExists(lowered)
        }
        let afterApostrophe = String(lowered[lowered.index(after: apostrophe)...])
        guard !afterApostrophe.isEmpty else { return false }
        return wordExists(afterApostrophe)
    }
}
