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
    private let symSpellEngine = SymSpellEngine()
    private var language: String = "fr"

    init() {
        // Verify language is available in UITextChecker
        let available = UITextChecker.availableLanguages
        if !available.contains(where: { $0.hasPrefix(language) }) {
            print("[TextPredictionEngine] Warning: '\(language)' not in available languages: \(available)")
        }
        frequencyDict.load(language: language)
        symSpellEngine.load(language: language)
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
        symSpellEngine.load(language: lang)
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
    /// Returns nil if the word is correctly spelled (exists in SymSpell dictionary).
    ///
    /// WHY SymSpell instead of UITextChecker:
    /// SymSpell returns corrections ranked by frequency (most common word first),
    /// while UITextChecker returns guesses ordered by edit distance. Frequency-ranked
    /// corrections pick "bonjour" over "bonsoir" for a typo of "bonour".
    /// UITextChecker is still used for word completions in suggestions(for:).
    func spellCheck(_ word: String) -> (correction: String, alternatives: [String])? {
        guard !word.isEmpty else { return nil }
        return symSpellEngine.spellCheck(word)
    }
}
