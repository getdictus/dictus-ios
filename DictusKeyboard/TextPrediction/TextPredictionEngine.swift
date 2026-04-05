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

    /// Predict next words based on context (1-2 previous words).
    /// Falls back to top frequent words when no n-gram match exists.
    ///
    /// WHY fallback to frequency:
    /// When the user types a word not in the n-gram model (rare word, name, etc.),
    /// showing the most common words is better than an empty suggestion bar.
    /// These are the words most likely to follow any context.
    func predictNextWords(after words: [String]) -> [String] {
        let predictions = aospTrieEngine.predictNextWords(after: words)
        if predictions.isEmpty {
            return frequencyDict.topWords(count: 3)
        }
        return predictions
    }

    /// Spell check with n-gram context boosting.
    /// When previousWord is provided, candidates are reranked using bigram frequency.
    /// Example: spellCheck("sui", previousWord: "je") boosts "suis" because
    /// bigram "je suis" has very high frequency.
    ///
    /// WHY context-aware: Without context, "sui" might correct to "sur" or "suc"
    /// (shorter edit distance). With "je" as context, "suis" gets a massive boost
    /// from the bigram "je suis", making it the clear winner.
    func spellCheck(_ word: String, previousWord: String?) -> (correction: String, alternatives: [String])? {
        // First, get standard spell check result (existing logic)
        let result = spellCheck(word)

        // If no previous word context or n-grams not loaded, return standard result
        guard let prev = previousWord, !prev.isEmpty, aospTrieEngine.ngramsLoaded else {
            return result
        }

        // If standard spell check found corrections, rerank with n-gram boost
        if let result = result {
            let candidates = [result.correction] + result.alternatives

            let scored: [(String, UInt16)] = candidates.map { candidate in
                let lowerCandidate = candidate.lowercased()
                let wordPart: String
                if let apoIdx = lowerCandidate.lastIndex(of: "'") {
                    wordPart = String(lowerCandidate[lowerCandidate.index(after: apoIdx)...])
                } else {
                    wordPart = lowerCandidate
                }
                let ngramScore = aospTrieEngine.bigramScore(for: wordPart, after: prev.lowercased())
                return (candidate, ngramScore)
            }

            let reranked = scored.sorted { $0.1 > $1.1 }
            let newCorrection = reranked[0].0
            let newAlternatives = reranked.dropFirst().map { $0.0 }
            return (newCorrection, Array(newAlternatives.prefix(2)))
        }

        // Word is valid (spellCheck returned nil), but n-gram context might suggest
        // a better word. Example: "sui" is valid (rare) but after "je", "suis" has
        // a much higher bigram score → suggest "suis" as correction.
        let lowered = word.lowercased()
        let wordToCheck: String
        let prefix: String?
        if let apoIdx = lowered.lastIndex(of: "'") {
            wordToCheck = String(lowered[lowered.index(after: apoIdx)...])
            prefix = String(lowered[...apoIdx])
        } else {
            wordToCheck = lowered
            prefix = nil
        }

        let nearby = aospTrieEngine.nearbyWords(for: wordToCheck)
        guard !nearby.isEmpty else { return nil }

        let prevLower = prev.lowercased()
        let inputScore = aospTrieEngine.bigramScore(for: wordToCheck, after: prevLower)

        // Score nearby words, keep only those with n-gram support
        let scored = nearby.compactMap { candidate -> (String, UInt16)? in
            let score = aospTrieEngine.bigramScore(for: candidate, after: prevLower)
            return score > 0 ? (candidate, score) : nil
        }

        // Pick the best candidate — must beat the input word's score
        guard let best = scored.max(by: { $0.1 < $1.1 }), best.1 > inputScore else {
            return nil
        }

        // Restore apostrophe prefix and case
        let isCapitalized = word.first?.isUppercase == true
        let fullCorrection = prefix != nil ? (prefix! + best.0) : best.0
        let correction = isCapitalized ? fullCorrection.capitalized : fullCorrection

        let alternatives = scored.filter { $0.0 != best.0 }
            .sorted { $0.1 > $1.1 }
            .prefix(2)
            .map { candidate -> String in
                let full = prefix != nil ? (prefix! + candidate.0) : candidate.0
                return isCapitalized ? full.capitalized : full
            }

        return (correction, Array(alternatives))
    }

    /// No-op: user words are handled by the two-pass lookup in spellCheck().
    /// The mmap'd trie is read-only; user words live in UserDictionary (App Group).
    func injectUserWord(_ word: String) {
        // No-op: UserDictionary.shared is checked before trie in spellCheck()
    }
}
