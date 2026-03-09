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
    private var language: String = "fr"

    init() {
        // Verify language is available in UITextChecker
        let available = UITextChecker.availableLanguages
        if !available.contains(where: { $0.hasPrefix(language) }) {
            print("[TextPredictionEngine] Warning: '\(language)' not in available languages: \(available)")
        }
        frequencyDict.load(language: language)
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

        let ranked = completions.sorted { frequencyDict.rank(of: $0) < frequencyDict.rank(of: $1) }
        return Array(ranked.prefix(3))
    }

    /// Returns the best correction for a misspelled word, or nil if correctly spelled.
    ///
    /// HOW IT WORKS:
    /// 1. Check if the word is misspelled using UITextChecker.rangeOfMisspelledWord()
    /// 2. If not misspelled (location == NSNotFound), return nil
    /// 3. If misspelled, get guesses and rank them by frequency
    /// 4. Return the most common guess (lowest frequency rank)
    ///
    /// WHY re-rank guesses:
    /// UITextChecker.guesses() returns corrections ordered by edit distance. But the
    /// closest edit-distance match isn't always the most likely intended word. Ranking
    /// by frequency picks "les" over "lez" for a typo of "lrs".
    func spellCheck(_ word: String) -> String? {
        guard !word.isEmpty else { return nil }

        let nsString = word as NSString
        let range = NSRange(location: 0, length: nsString.length)

        let misspelled = textChecker.rangeOfMisspelledWord(
            in: word,
            range: range,
            startingAt: 0,
            wrap: false,
            language: language
        )

        // Word is correctly spelled
        guard misspelled.location != NSNotFound else { return nil }

        guard let guesses = textChecker.guesses(
            forWordRange: misspelled,
            in: word,
            language: language
        ), !guesses.isEmpty else {
            return nil
        }

        // Re-rank guesses by frequency and return the most common
        let ranked = guesses.sorted { frequencyDict.rank(of: $0) < frequencyDict.rank(of: $1) }
        return ranked.first
    }

    /// Returns accent variants for single-character vowel input, or nil if not a vowel.
    ///
    /// WHY this feature:
    /// On a mobile keyboard, typing accented characters requires long-press or special keys.
    /// When the user types a single vowel (e.g., "e"), the suggestion bar can show the most
    /// common accented variants (e-acute, e-grave, e-circumflex) for quick one-tap insertion.
    ///
    /// FORMAT: [original, variant1, variant2] -- max 3 slots for the suggestion bar.
    /// Case is preserved: typing "E" returns ["E", "E-acute", "E-grave"].
    func accentSuggestions(for partialWord: String) -> [String]? {
        guard partialWord.count == 1 else { return nil }

        let lowered = partialWord.lowercased()
        guard let variants = AccentedCharacters.mappings[lowered] else { return nil }

        let isUppercase = partialWord == partialWord.uppercased() && partialWord != partialWord.lowercased()

        // Build array: [original char, variant1, variant2] -- max 3 slots
        var result = [partialWord]
        for variant in variants.prefix(2) {
            result.append(isUppercase ? variant.uppercased() : variant)
        }

        return result
    }
}
