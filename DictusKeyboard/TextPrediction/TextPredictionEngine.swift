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
    /// Uses two strategies to find context-appropriate corrections:
    /// 1. Rerank existing spell corrections using bigram scores
    /// 2. Check if n-gram predictions are close to the typed word (prediction-based)
    ///
    /// Strategy 2 is the key insight: instead of asking "what are the corrections for sui?"
    /// and hoping "suis" appears, we ask "what does the n-gram model predict after je?"
    /// and check if any prediction (like "suis") is close to what was typed ("sui").
    func spellCheck(_ word: String, previousWord: String?) -> (correction: String, alternatives: [String])? {
        let result = spellCheck(word)

        // If no previous word context or n-grams not loaded, return standard result
        guard let prev = previousWord, !prev.isEmpty, aospTrieEngine.ngramsLoaded else {
            return result
        }

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

        let prevLower = prev.lowercased()

        // Get n-gram predictions close to the typed word (edit distance exactly 1).
        // Only for words of 3+ characters — short words like "a", "à", "un" have too
        // many neighbors at distance 1-2, causing false corrections (e.g., "a" → "la").
        // Max distance 1 (not 2): distance 2 is too permissive even for longer words
        // (e.g., "suis" → "vais" at distance 2 would be a false correction).
        let closePredictions: [(String, UInt16)]
        if wordToCheck.count >= 3 {
            let predictions = aospTrieEngine.predictNextWords(after: [prevLower], maxResults: 8)
            closePredictions = predictions.compactMap { prediction in
                let dist = Self.editDistance(wordToCheck, prediction)
                guard dist == 1 else { return nil }
                let score = aospTrieEngine.bigramScore(for: prediction, after: prevLower)
                return score > 0 ? (prediction, score) : nil
            }
        } else {
            closePredictions = []
        }

        if let result = result {
            // Have base corrections — merge with close predictions and rerank
            var candidateSet: [String: UInt16] = [:]

            // Score existing corrections
            for candidate in [result.correction] + result.alternatives {
                let lowerCandidate = candidate.lowercased()
                let wordPart: String
                if let apoIdx = lowerCandidate.lastIndex(of: "'") {
                    wordPart = String(lowerCandidate[lowerCandidate.index(after: apoIdx)...])
                } else {
                    wordPart = lowerCandidate
                }
                candidateSet[candidate] = aospTrieEngine.bigramScore(for: wordPart, after: prevLower)
            }

            // Add close predictions (may introduce new candidates like "suis")
            let isCapitalized = word.first?.isUppercase == true
            for (prediction, score) in closePredictions {
                let full = prefix != nil ? (prefix! + prediction) : prediction
                let display = isCapitalized ? full.capitalized : full
                if let existing = candidateSet[display] {
                    candidateSet[display] = max(existing, score)
                } else {
                    candidateSet[display] = score
                }
            }

            let reranked = candidateSet.sorted { $0.value > $1.value }
            let newCorrection = reranked[0].key
            let newAlternatives = reranked.dropFirst().map { $0.key }
            return (newCorrection, Array(newAlternatives.prefix(2)))
        }

        // Word is valid (spellCheck returned nil). Check if any n-gram prediction
        // is close to the typed word. Example: "je sui" → prediction "suis" at
        // edit distance 1, with high bigram score → suggest as correction.
        guard !closePredictions.isEmpty else { return nil }

        let inputScore = aospTrieEngine.bigramScore(for: wordToCheck, after: prevLower)

        guard let best = closePredictions.max(by: { $0.1 < $1.1 }), best.1 > inputScore else {
            return nil
        }

        let isCapitalized = word.first?.isUppercase == true
        let fullCorrection = prefix != nil ? (prefix! + best.0) : best.0
        let correction = isCapitalized ? fullCorrection.capitalized : fullCorrection

        let alternatives = closePredictions.filter { $0.0 != best.0 }
            .sorted { $0.1 > $1.1 }
            .prefix(2)
            .map { candidate -> String in
                let full = prefix != nil ? (prefix! + candidate.0) : candidate.0
                return isCapitalized ? full.capitalized : full
            }

        return (correction, Array(alternatives))
    }

    /// Levenshtein edit distance between two strings. O(n*m) but strings are
    /// short (< 20 chars) so this is sub-microsecond.
    private static func editDistance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var dp = Array(0...b.count)
        for i in 1...a.count {
            var prev = dp[0]
            dp[0] = i
            for j in 1...b.count {
                let temp = dp[j]
                if a[i - 1] == b[j - 1] {
                    dp[j] = prev
                } else {
                    dp[j] = min(prev, dp[j], dp[j - 1]) + 1
                }
                prev = temp
            }
        }
        return dp[b.count]
    }

    /// No-op: user words are handled by the two-pass lookup in spellCheck().
    /// The mmap'd trie is read-only; user words live in UserDictionary (App Group).
    func injectUserWord(_ word: String) {
        // No-op: UserDictionary.shared is checked before trie in spellCheck()
    }
}
