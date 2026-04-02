// DictusKeyboard/TextPrediction/SymSpellEngine.swift
// Wraps vendored SymSpell to provide frequency-ranked spell correction.
import Foundation

/// Wraps SymSpell for frequency-ranked spell correction.
///
/// WHY a wrapper:
/// Isolates SymSpell from the rest of the codebase. If the vendored library
/// changes or is replaced, only this file changes. Also handles JSON loading
/// (SymSpell natively expects TSV) and case restoration.
final class SymSpellEngine {

    private var symSpell: SymSpell?
    private var wordCount: Int = 0

    /// Loads a frequency dictionary for the given language.
    /// Expected JSON format: {"word": count, ...} where count is Int (higher = more common).
    /// Replaces any previously loaded dictionary.
    func load(language: String, bundle: Bundle = .main) {
        guard let url = bundle.url(forResource: "\(language)_frequency", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let dict = try? JSONDecoder().decode([String: Int].self, from: data) else {
            print("[SymSpellEngine] Failed to load \(language)_frequency.json")
            symSpell = nil
            wordCount = 0
            return
        }

        let ss = SymSpell(maxDictionaryEditDistance: 2, prefixLength: 7)
        for (word, count) in dict {
            ss.createDictionaryEntry(key: word.lowercased(), count: max(1, count))
        }
        symSpell = ss
        wordCount = dict.count
        print("[SymSpellEngine] Loaded \(dict.count) words for \(language)")
    }

    /// Returns the best correction and alternatives for a misspelled word.
    /// Returns nil if the word is correctly spelled (exists in dictionary as-is).
    ///
    /// Case restoration: if input starts with uppercase, correction is capitalized.
    /// SymSpell internally works with lowercase only.
    func spellCheck(_ word: String) -> (correction: String, alternatives: [String])? {
        guard let ss = symSpell, !word.isEmpty else { return nil }

        let lowered = word.lowercased()
        let results = ss.lookup(lowered, verbosity: .closest, maxEditDistance: 2)

        guard !results.isEmpty else { return nil }

        // If the top result matches the input exactly, the word is correctly spelled
        if results[0].term == lowered { return nil }

        // Restore case: capitalize correction if input was capitalized
        let isCapitalized = word.first?.isUppercase == true
        let correction = isCapitalized ? results[0].term.capitalized : results[0].term

        let alts = results.dropFirst().prefix(2).map { item -> String in
            isCapitalized ? item.term.capitalized : item.term
        }

        return (correction, Array(alts))
    }

    /// Whether a dictionary is loaded and ready for lookups.
    var isLoaded: Bool { symSpell != nil }

    /// Number of words in the loaded dictionary.
    var dictionarySize: Int { wordCount }
}
