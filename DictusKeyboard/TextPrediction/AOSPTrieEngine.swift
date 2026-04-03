// DictusKeyboard/TextPrediction/AOSPTrieEngine.swift
// Wraps the AOSP-inspired C++ trie engine via ObjC++ bridge.
import Foundation
import DictusCore

/// Wraps the AOSP-inspired C++ trie engine via ObjC++ bridge.
///
/// WHY replacing SymSpell:
/// SymSpell pre-generates all edit-distance deletes (~7 per word at distance 1), using 15 MiB
/// for 10K words. The trie walks candidates during lookup, supporting 100K+ words in ~3-5 MiB
/// via mmap, with keyboard proximity scoring and accent-aware costs.
final class AOSPTrieEngine {

    private let bridge = AOSPTrieBridge()
    private var wordCount: Int = 0

    /// Serial queue for dictionary loading. Ensures only one load runs at a time.
    private let loadQueue = DispatchQueue(
        label: "com.pivi.dictus.aosptrie-load",
        qos: .userInitiated
    )

    /// True while a background load is in progress.
    private(set) var isLoading: Bool = false

    /// Hard-coded French corrections that the trie can't infer from edit distance alone.
    /// "ca" is never a valid French word -- it's always the unaccented form of "ca".
    /// Short words (<=2 chars) are too ambiguous for generic spell correction
    /// (e.g., "ou"/"ou", "a"/"a" depend on grammar), so we only correct known cases.
    private static let frenchOverrides: [String: String] = [
        "ca": "\u{00E7}a"  // "ca" -> "ca"
    ]

    /// Loads binary .dict file for the given language.
    /// Replaces any previously loaded dictionary.
    ///
    /// WHY async: Prevents blocking the main thread during keyboard init.
    /// The keyboard appears instantly; spell correction becomes available after mmap load.
    func load(language: String, bundle: Bundle = .main) {
        isLoading = true
        bridge.unloadDictionary()
        wordCount = 0

        loadQueue.async { [weak self] in
            guard let self = self else { return }

            guard let path = bundle.path(
                forResource: "\(language)_spellcheck", ofType: "dict"
            ) else {
                print("[AOSPTrieEngine] Failed to find \(language)_spellcheck.dict")
                DispatchQueue.main.async { self.isLoading = false }
                return
            }

            let success = self.bridge.loadDictionary(atPath: path)

            // Set proximity map based on active keyboard layout.
            // AZERTY is default because Dictus targets French-speaking users.
            if LayoutType.active == .azerty {
                self.bridge.setProximityMapAZERTY()
            } else {
                self.bridge.setProximityMapQWERTY()
            }

            DispatchQueue.main.async {
                if success {
                    self.wordCount = Int(self.bridge.wordCount())
                    print("[AOSPTrieEngine] Loaded \(language)_spellcheck.dict (\(self.wordCount) words)")
                } else {
                    print("[AOSPTrieEngine] Failed to load \(language)_spellcheck.dict")
                }
                self.isLoading = false
            }
        }
    }

    /// Check French overrides only (no trie lookup). Returns nil if no override applies.
    /// Used by TextPredictionEngine to check overrides BEFORE UserDictionary,
    /// since words like "ca" must always correct to "ça" even if "ca" was learned.
    func frenchOverride(for word: String) -> (correction: String, alternatives: [String])? {
        let lowered = word.lowercased()
        guard let override = Self.frenchOverrides[lowered] else { return nil }
        let isCapitalized = word.first?.isUppercase == true
        return (isCapitalized ? override.capitalized : override, [])
    }

    /// Returns best correction and alternatives, or nil if word is correct.
    /// Preserves SymSpellEngine behavior: French overrides, apostrophe handling, case restoration.
    ///
    /// Rules:
    /// 1. French overrides checked first ("ca" -> "ca") regardless of word length.
    /// 2. Apostrophe words: only the part after the last apostrophe is checked
    ///    ("qu'il" -> checks "il", not the whole string).
    /// 3. Case restoration: if input starts with uppercase, correction is capitalized.
    func spellCheck(_ word: String) -> (correction: String, alternatives: [String])? {
        let lowered = word.lowercased()

        // Check French overrides first (works even before dictionary loads)
        if let override = Self.frenchOverrides[lowered] {
            let isCapitalized = word.first?.isUppercase == true
            return (isCapitalized ? override.capitalized : override, [])
        }

        guard bridge.isLoaded(), !word.isEmpty else { return nil }

        // Handle apostrophe words: "qu'il" -> check "il", "l'homme" -> check "homme"
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

        guard let result = bridge.spellCheck(wordToCheck, maxEditDistance: 2.0) else {
            return nil
        }

        // Restore case and reassemble with prefix if present
        let isCapitalized = word.first?.isUppercase == true
        let correction = prefix != nil ? (prefix! + result.correction) : result.correction
        let fullCorrection = isCapitalized ? correction.capitalized : correction

        let alts = result.alternatives.prefix(2).map { alt -> String in
            let full = prefix != nil ? (prefix! + alt) : alt
            return isCapitalized ? full.capitalized : full
        }

        return (fullCorrection, Array(alts))
    }

    /// No-op for trie engine. User words are checked separately via UserDictionary.
    /// The mmap'd trie is read-only; user words are handled as a two-pass lookup
    /// in TextPredictionEngine (user dict first, then trie).
    func injectUserWord(_ word: String) {
        // No-op: user dictionary is checked before trie in TextPredictionEngine
    }

    /// Whether a dictionary is loaded and ready for lookups.
    var isLoaded: Bool { bridge.isLoaded() }

    /// Number of words in the loaded dictionary.
    var dictionarySize: Int { wordCount }
}
