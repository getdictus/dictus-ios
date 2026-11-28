// DictusKeyboard/TextPrediction/TrieLanguageEvidence.swift
// One language's trie and n-grams, as the bilingual check questions them (#1015).
import DictusCore
import Foundation

/// The answers `WordLanguageVote`, `BilingualKeepRule` and `BilingualCheck` need, read
/// off the trie an engine already has mounted: no second copy of the dictionary.
///
/// The bench of #1010 mounted a second trie per language for the same answers; it is
/// kept there for its `detect` policy, and this is what the keyboard uses.
struct TrieLanguageEvidence: LanguageEvidenceSource {
    let language: SupportedLanguage
    let trie: AOSPTrieEngine
    let scale: TrieFrequencyScale

    func logFrequency(of word: String) -> Double? {
        trie.wordExists(word) ? scale.logFrequency(stored: trie.wordFrequency(word)) : nil
    }

    /// The accented spelling #994's restoration picks, or the likelier of the two it
    /// only offers.
    func accentExpansion(_ word: String) -> String? {
        switch trie.accentRestoration(word, previousWord: nil) {
        case .keepTyped: return nil
        case .restore(let accented): return accented
        case .ambiguous(let spellings): return spellings.first
        }
    }

    func contractionExpansion(_ word: String) -> String? { trie.contractionExpansion(word) }

    func correction(of word: String) -> String? { trie.spellCheck(word)?.correction }

    func bigram(_ word: String, after previous: String) -> Double {
        Double(trie.bigramScore(for: word, after: previous)) / 65535
    }
}
