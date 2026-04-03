// DictusKeyboard/TextPrediction/TextPredictionEngine.swift
// Core prediction logic: word completions, spell-checking, and accent suggestions.
import UIKit
import DictusCore

/// Provides word completions, spell-checking, and accent suggestions for the keyboard.
///
/// WHY a class (not struct):
/// UITextChecker is a reference type (NSObject subclass) and maintains internal state
/// for its learned words dictionary. Using a class avoids copy-on-write issues and
/// ensures a single UITextChecker instance is reused throughout the keyboard session.
///
/// WHY UITextChecker:
/// Apple's built-in spell checker and word completion engine. It uses the system
/// dictionary which is already installed on every iOS device -- no additional data
/// download needed. We combine its completions with our FrequencyDictionary to
/// rank results by word frequency (most common words first).
class TextPredictionEngine {

    private let textChecker = UITextChecker()
    private var frequencyDict = FrequencyDictionary()
    private let aospTrieEngine = AOSPTrieEngine()
    private var language: String = "fr"

    init() {
        // Verify language is available in UITextChecker
        let available = UITextChecker.availableLanguages
        if !available.contains(where: { $0.hasPrefix(language) }) {
            print("[TextPredictionEngine] Warning: '\(language)' not in available languages: \(available)")
        }
        frequencyDict.load(language: language)
        aospTrieEngine.load(language: language)
    }

    /// Updates the active language for completions and spell-checking.
    /// Reloads the frequency dictionary for the new language.
    ///
    /// WHY reload on language change:
    /// We only keep one language's frequency data in memory at a time
    /// to stay within the keyboard extension's ~50MB memory budget.
    func setLanguage(_ lang: String) {
        language = lang
        let available = UITextChecker.availableLanguages
        if !available.contains(where: { $0.hasPrefix(lang) }) {
            print("[TextPredictionEngine] Warning: '\(lang)' not in available languages: \(available)")
        }
        frequencyDict.load(language: lang)
        aospTrieEngine.load(language: lang)
    }

    /// Returns up to 3 word completions for a partial word, ranked by frequency.
    ///
    /// HOW IT WORKS:
    /// 1. UITextChecker.completions() returns all possible completions from the system dictionary
    /// 2. We sort those completions by our frequency dictionary (lower rank = more common = first)
    /// 3. We return only the top 3 to fill the suggestion bar's 3 slots
    ///
    /// WHY frequency-based ranking:
    /// UITextChecker returns completions in alphabetical order by default. Ranking by
    /// word frequency ensures "les" appears before "lesparre" when typing "le".
    func suggestions(for partialWord: String) -> [String] {
        guard !partialWord.isEmpty else { return [] }

        let nsString = partialWord as NSString
        let range = NSRange(location: 0, length: nsString.length)

        guard let completions = textChecker.completions(
            forPartialWordRange: range,
            in: partialWord,
            language: language
        ) else {
            return []
        }

        let ranked = completions.sorted { frequencyDict.rank(of: $0) > frequencyDict.rank(of: $1) }
        return Array(ranked.prefix(3))
    }

    /// Returns the best correction and alternatives for a misspelled word.
    /// Returns nil if the word is correctly spelled or is a user-learned word.
    ///
    /// WHY two-pass lookup:
    /// Pass 1: Check UserDictionary first. Words the user has learned (via rejection
    /// or repetition) are always considered correct -- no trie lookup needed. This
    /// prevents the trie from "correcting" names, slang, or jargon the user has taught.
    /// Pass 2: Delegate to AOSPTrieEngine for proximity-weighted, accent-aware correction
    /// against the 100K+ word binary trie dictionary.
    ///
    /// WHY AOSPTrieEngine instead of SymSpell:
    /// The trie walks candidates during lookup with keyboard proximity scoring,
    /// supporting 100K+ words in ~0.4 MiB per language via mmap. SymSpell pre-generated
    /// all edit-distance deletes, using 15 MiB for just 10K words.
    func spellCheck(_ word: String) -> (correction: String, alternatives: [String])? {
        guard !word.isEmpty else { return nil }

        // French overrides bypass everything — "ca" is never valid French.
        // Must check before UserDictionary, otherwise typing "ca" twice
        // would "learn" it and block the ça correction permanently.
        if let result = aospTrieEngine.frenchOverride(for: word) {
            return result
        }

        // Two-pass lookup: user dictionary first (learned words are always "correct").
        // Extract the word part after any apostrophe for user dict check, matching
        // the same apostrophe handling that AOSPTrieEngine uses internally.
        let lowered = word.lowercased()
        let wordToCheck: String
        if let apoIndex = lowered.lastIndex(of: "'") {
            wordToCheck = String(lowered[lowered.index(after: apoIndex)...])
        } else {
            wordToCheck = lowered
        }
        if UserDictionary.shared.isLearned(wordToCheck) {
            return nil  // User-learned word: no correction needed
        }

        // Pass 2: trie spell check (proximity-weighted, accent-aware)
        return aospTrieEngine.spellCheck(word)
    }

    /// No-op: user words are handled by the two-pass lookup in spellCheck().
    /// The mmap'd trie is read-only; user words live in UserDictionary (App Group).
    func injectUserWord(_ word: String) {
        // No-op: UserDictionary.shared is checked before trie in spellCheck()
    }
}
