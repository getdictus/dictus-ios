// DictusKeyboard/TextPrediction/SymSpellEngine.swift
// Wraps vendored SymSpell to provide frequency-ranked spell correction.
import Foundation
import DictusCore

/// Wraps SymSpell for frequency-ranked spell correction.
///
/// WHY a wrapper:
/// Isolates SymSpell from the rest of the codebase. If the vendored library
/// changes or is replaced, only this file changes. Also handles JSON loading
/// (SymSpell natively expects TSV) and case restoration.
///
/// WHY async loading:
/// SymSpell needs to generate all edit-distance delete combinations for 40K+ words
/// (~1.12M entries). This takes 0.5-2s on iPhone and would freeze the keyboard UI
/// if done synchronously on the main thread. Loading happens on a background queue;
/// spellCheck() gracefully returns nil until loading completes.
final class SymSpellEngine {

    private var symSpell: SymSpell?
    private var wordCount: Int = 0

    /// Serial queue for dictionary loading. Ensures only one load runs at a time.
    private let loadQueue = DispatchQueue(
        label: "com.pivi.dictus.symspell-load",
        qos: .userInitiated
    )

    /// True while a background load is in progress.
    private(set) var isLoading: Bool = false

    /// Hard-coded French corrections that SymSpell can't infer from edit distance alone.
    /// "ca" is never a valid French word — it's always the unaccented form of "ça".
    /// Short words (≤2 chars) are too ambiguous for generic spell correction
    /// (e.g., "ou"/"où", "a"/"à" depend on grammar), so we only correct known cases.
    private static let frenchOverrides: [String: String] = [
        "ca": "ça"
    ]

    /// Minimum word length for generic spell correction.
    /// Set to 1 to allow correction of all words including short ones.
    /// French overrides handle known problematic cases ("ca" → "ça").
    /// Other short-word issues will be addressed based on user feedback.
    private static let minCorrectionLength = 1

    /// Frequency assigned to user-learned words when injected into SymSpell.
    /// Set to ~top 500 word frequency (15000). This is high enough that learned
    /// words appear in suggestions and aren't autocorrected away, but low enough
    /// that a wrongly-learned word won't override all nearby real words.
    /// For comparison: "de" = 2.9M, "bonjour" = 15K, median = 137.
    private static let userWordFrequency = 15000

    /// Maximum number of words loaded from the frequency dictionary.
    /// 20K covers all common words. Beyond that, words are extremely rare
    /// and not worth the memory cost. Each word generates ~7 delete entries
    /// at edit distance 1. Memory: 20K words ≈ 13 MiB vs 40K ≈ 90 MiB.
    private static let maxDictionaryWords = 20000

    /// Loads a frequency dictionary for the given language.
    /// Expected JSON format: {"word": count, ...} where count is Int (higher = more common).
    /// Replaces any previously loaded dictionary.
    ///
    /// WHY async: Prevents blocking the main thread during keyboard init.
    /// The keyboard appears instantly; spell correction becomes available ~0.5-1s later.
    ///
    /// MEMORY OPTIMIZATIONS:
    /// 1. maxEditDistance=1 (not 2): catches 80%+ of typos, uses ~4x less memory.
    ///    Most typos are single-character errors. Double-typos are rare.
    /// 2. Top 20K words only: rare words beyond 20K aren't worth the memory.
    /// 3. Old dictionary is freed before new one is created on language switch,
    ///    preventing both dictionaries from coexisting in memory.
    func load(language: String, bundle: Bundle = .main) {
        isLoading = true

        // Free old dictionary immediately to avoid two dictionaries in memory
        // during language switch (was causing 159 MiB peak).
        symSpell = nil
        wordCount = 0

        loadQueue.async { [weak self] in
            guard let self = self else { return }

            guard let url = bundle.url(forResource: "\(language)_frequency", withExtension: "json"),
                  let data = try? Data(contentsOf: url),
                  let dict = try? JSONDecoder().decode([String: Int].self, from: data) else {
                print("[SymSpellEngine] Failed to load \(language)_frequency.json")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                return
            }

            // Take only the top N most frequent words to stay within memory budget.
            // Sort by frequency descending, take top maxDictionaryWords.
            let topWords = dict.sorted { $0.value > $1.value }
                .prefix(Self.maxDictionaryWords)

            // maxEditDistance=1: single-character errors (insertion, deletion,
            // substitution, transposition). Covers most real typos.
            // Memory: ~7 deletes/word vs ~28 at distance 2 → 4x reduction.
            let ss = SymSpell(maxDictionaryEditDistance: 1, prefixLength: 7)
            for (word, count) in topWords {
                ss.createDictionaryEntry(key: word.lowercased(), count: max(1, count))
            }

            // Inject user-learned words so they're treated as known words.
            let userDict = UserDictionary.shared
            userDict.reload()
            let userWords = userDict.allLearnedWords
            for (word, _) in userWords {
                ss.createDictionaryEntry(key: word.lowercased(), count: Self.userWordFrequency)
            }

            let loadedCount = topWords.count

            DispatchQueue.main.async {
                self.symSpell = ss
                self.wordCount = loadedCount + userWords.count
                self.isLoading = false
                print("[SymSpellEngine] Loaded \(loadedCount)/\(dict.count) words + \(userWords.count) user words for \(language)")
            }
        }
    }

    /// Returns the best correction and alternatives for a misspelled word.
    /// Returns nil if the word is correctly spelled, too short, or dictionary not loaded yet.
    ///
    /// Rules:
    /// 1. French overrides checked first ("ca" → "ça") regardless of word length.
    /// 2. Words ≤ 2 characters skip generic correction (too ambiguous).
    /// 3. Apostrophe words: only the part after the last apostrophe is checked
    ///    ("qu'il" → checks "il", not the whole string).
    ///
    /// Case restoration: if input starts with uppercase, correction is capitalized.
    func spellCheck(_ word: String) -> (correction: String, alternatives: [String])? {
        let lowered = word.lowercased()

        // Check French overrides first (works even before dictionary loads)
        if let override = Self.frenchOverrides[lowered] {
            let isCapitalized = word.first?.isUppercase == true
            let corrected = isCapitalized ? override.capitalized : override
            return (corrected, [])
        }

        guard let ss = symSpell, !word.isEmpty else { return nil }

        // Handle apostrophe words: "qu'il" → check "il", "l'homme" → check "homme"
        // French contractions split at the apostrophe; only the main word can be misspelled.
        let wordToCheck: String
        let prefix: String?
        if let apoIndex = lowered.lastIndex(of: "'") {
            let afterApo = String(lowered[lowered.index(after: apoIndex)...])
            if afterApo.isEmpty { return nil }
            wordToCheck = afterApo
            prefix = String(lowered[...apoIndex])
        } else {
            wordToCheck = lowered
            prefix = nil
        }

        // Skip generic correction for very short words (too ambiguous)
        guard wordToCheck.count >= Self.minCorrectionLength else { return nil }

        let results = ss.lookup(wordToCheck, verbosity: .closest, maxEditDistance: 1)
        guard !results.isEmpty else { return nil }

        // If the top result matches the input, the word is correctly spelled
        if results[0].term == wordToCheck { return nil }

        // Restore case and reassemble with prefix if present
        let isCapitalized = word.first?.isUppercase == true
        let correctedWord = results[0].term
        let fullCorrection: String
        if let prefix = prefix {
            fullCorrection = isCapitalized ? (prefix + correctedWord).capitalized : prefix + correctedWord
        } else {
            fullCorrection = isCapitalized ? correctedWord.capitalized : correctedWord
        }

        let alts = results.dropFirst().prefix(2).map { item -> String in
            let altWord = prefix != nil ? (prefix! + item.term) : item.term
            return isCapitalized ? altWord.capitalized : altWord
        }

        return (fullCorrection, Array(alts))
    }

    /// Inject a user-learned word into the live SymSpell instance.
    /// Called when a word is learned mid-session (after rejection or repetition)
    /// so the correction is available immediately without reloading the dictionary.
    func injectUserWord(_ word: String) {
        symSpell?.createDictionaryEntry(key: word.lowercased(), count: Self.userWordFrequency)
    }

    /// Whether a dictionary is loaded and ready for lookups.
    var isLoaded: Bool { symSpell != nil }

    /// Number of words in the loaded dictionary.
    var dictionarySize: Int { wordCount }
}
