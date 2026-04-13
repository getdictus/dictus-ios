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

    /// The currently loaded language code ("fr", "en", "es").
    /// Set by load(language:) so overrides and apostrophe handling can be language-aware.
    private var currentLanguage: String = "fr"

    /// Per-language hard-coded corrections that the trie can't infer from edit distance alone.
    /// French: "ca" is never valid -- always the unaccented form of "ça".
    /// English: common contractions typed without apostrophe ("im" → "I'm", "dont" → "don't").
    /// Short words (<=2 chars) are too ambiguous for generic spell correction
    /// (e.g., "ou"/"où", "a"/"à" depend on grammar), so we only correct known cases.
    private static let languageOverrides: [String: [String: String]] = [
        // Common unambiguous accent-missing words. These are NOT valid French without accents.
        // Excluded: "a"/"à" (both valid), "ou"/"où" (both valid), "meme" (could be English)
        "fr": [
            "ca": "\u{00E7}a",            // ca -> ça
            "tres": "tr\u{00E8}s",        // tres -> très
            "apres": "apr\u{00E8}s",      // apres -> après
            "deja": "d\u{00E9}j\u{00E0}", // deja -> déjà
            "ete": "\u{00E9}t\u{00E9}",   // ete -> été
            "etre": "\u{00EA}tre",         // etre -> être
            "voila": "voil\u{00E0}",       // voila -> voilà
            "bientot": "bient\u{00F4}t",   // bientot -> bientôt
            "plutot": "plut\u{00F4}t",     // plutot -> plutôt
            "probleme": "probl\u{00E8}me", // probleme -> problème
            "systeme": "syst\u{00E8}me",   // systeme -> système
            "etait": "\u{00E9}tait",       // etait -> était
            "etaient": "\u{00E9}taient",   // etaient -> étaient
            "evenement": "\u{00E9}v\u{00E9}nement", // evenement -> événement
        ],
        // Only unambiguous contractions — words that are NOT valid English on their own.
        // Excluded: "were" (we're), "well" (we'll), "wed" (we'd), "ill" (I'll),
        // "id" (I'd), "hell" (he'll), "hed" (he'd), "shed" (she'd), "shell" (she'll),
        // "its" (it's), "lets" (let's), "wont" (won't) — all valid standalone words.
        "en": [
            "im": "i'm",
            "ive": "i've",
            "dont": "don't",
            "doesnt": "doesn't",
            "didnt": "didn't",
            "cant": "can't",
            "couldnt": "couldn't",
            "wouldnt": "wouldn't",
            "shouldnt": "shouldn't",
            "wasnt": "wasn't",
            "isnt": "isn't",
            "arent": "aren't",
            "werent": "weren't",
            "hasnt": "hasn't",
            "havent": "haven't",
            "hadnt": "hadn't",
            "youre": "you're",
            "youve": "you've",
            "youll": "you'll",
            "youd": "you'd",
            "theyre": "they're",
            "theyve": "they've",
            "theyll": "they'll",
            "theyd": "they'd",
            "weve": "we've",
            "hes": "he's",
            "shes": "she's",
            "itll": "it'll",
            "thats": "that's",
            "thatll": "that'll",
            "whats": "what's",
            "whos": "who's",
            "wholl": "who'll",
            "theres": "there's",
            "heres": "here's",
        ],
        "es": [:]
    ]

    /// Loads binary .dict file for the given language.
    /// Replaces any previously loaded dictionary.
    ///
    /// WHY async: Prevents blocking the main thread during keyboard init.
    /// The keyboard appears instantly; spell correction becomes available after mmap load.
    func load(language: String, bundle: Bundle = .main) {
        isLoading = true
        currentLanguage = language
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

            // Load n-gram data on the same queue, right after the spell dict.
            // WHY here: n-grams are only useful after the dictionary is loaded,
            // and loading both on the same serial queue ensures correct ordering.
            if success {
                self.loadNgrams(language: language, bundle: bundle)
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

    /// Check language-specific overrides only (no trie lookup). Returns nil if no override applies.
    /// Used by TextPredictionEngine to check overrides BEFORE UserDictionary,
    /// since words like "ca" must always correct to "ça" even if "ca" was learned.
    func languageOverride(for word: String) -> (correction: String, alternatives: [String])? {
        let lowered = word.lowercased()
        guard let overrides = Self.languageOverrides[currentLanguage],
              let override = overrides[lowered] else { return nil }
        let isCapitalized = word.first?.isUppercase == true
        return (isCapitalized ? override.capitalized : override, [])
    }

    /// Returns best correction and alternatives, or nil if word is correct.
    /// Handles language-specific overrides, apostrophe splitting, and case restoration.
    ///
    /// Rules:
    /// 1. Language overrides checked first (e.g., French "ca" -> "ça").
    /// 2. Apostrophe words: only the part after the last apostrophe is checked
    ///    ("qu'il" -> checks "il", not the whole string).
    /// 3. Case restoration: if input starts with uppercase, correction is capitalized.
    func spellCheck(_ word: String) -> (correction: String, alternatives: [String])? {
        let lowered = word.lowercased()

        // Check language-specific overrides first (works even before dictionary loads)
        if let overrides = Self.languageOverrides[currentLanguage],
           let override = overrides[lowered] {
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

    /// Check if a word exists in the trie dictionary.
    func wordExists(_ word: String) -> Bool {
        guard bridge.isLoaded() else { return false }
        return bridge.wordExists(word)
    }

    /// Get the frequency of a word in the trie (0 if not found).
    func wordFrequency(_ word: String) -> UInt16 {
        guard bridge.isLoaded() else { return 0 }
        return UInt16(bridge.getFrequency(word))
    }

    /// Try to expand a word into a French contraction with apostrophe.
    /// "Cest" → "c'est", "lhomme" → "l'homme", "jai" → "j'ai"
    func contractionExpansion(_ word: String) -> String? {
        guard bridge.isLoaded() else { return nil }
        let lowered = word.lowercased()
        guard lowered.count >= 2 else { return nil }

        let knownPrefixes = ["l'", "d'", "c'", "j'", "n'", "s'", "m'", "t'"]
        // Try 1-char prefix (l', d', c', j', n', s', m', t')
        let oneCharPrefix = String(lowered.prefix(1)) + "'"
        let oneCharSuffix = String(lowered.dropFirst(1))
        if knownPrefixes.contains(oneCharPrefix),
           !oneCharSuffix.isEmpty,
           bridge.wordExists(oneCharSuffix) {
            return oneCharPrefix + oneCharSuffix
        }

        // Try 2-char prefix (qu')
        if lowered.count >= 3 {
            let twoCharPrefix = String(lowered.prefix(2)) + "'"
            let twoCharSuffix = String(lowered.dropFirst(2))
            if twoCharPrefix == "qu'",
               !twoCharSuffix.isEmpty,
               bridge.wordExists(twoCharSuffix) {
                return twoCharPrefix + twoCharSuffix
            }
        }

        return nil
    }

    /// Try adding accents to an unaccented word and check if the result exists.
    /// "deja" → "déjà", "apres" → "après", "ete" → "été", "tres" → "très"
    ///
    /// Users commonly type without accents expecting autocorrect to add them.
    /// This method generates accent variants and picks the highest-frequency match
    /// to avoid selecting rare words (e.g., "âpres" over "après").
    func accentExpansion(_ word: String) -> String? {
        guard bridge.isLoaded() else { return nil }
        let lowered = word.lowercased()
        guard lowered.count >= 2 else { return nil }

        let accentMap: [Character: [Character]]
        if currentLanguage == "fr" {
            accentMap = [
                "e": ["é", "è", "ê", "ë"],
                "a": ["à", "â"],
                "i": ["î", "ï"],
                "o": ["ô"],
                "u": ["ù", "û", "ü"],
                "c": ["ç"],
            ]
        } else if currentLanguage == "es" {
            accentMap = [
                "a": ["á"],
                "e": ["é"],
                "i": ["í"],
                "o": ["ó"],
                "u": ["ú", "ü"],
                "n": ["ñ"],
            ]
        } else if currentLanguage == "de" {
            accentMap = [
                "a": ["ä"],
                "o": ["ö"],
                "u": ["ü"],
                "s": ["ß"],
            ]
        } else {
            return nil
        }

        var accentablePositions: [(Int, [Character])] = []
        let chars = Array(lowered)
        for (i, ch) in chars.enumerated() {
            if let accents = accentMap[ch] {
                accentablePositions.append((i, accents))
            }
        }

        guard !accentablePositions.isEmpty else { return nil }

        // Collect ALL valid matches with their frequency, then pick the best.
        // This prevents "apres" → "âpres" (rare) when "après" (common) exists.
        // Uses getFrequency as primary ranking, wordExists as fallback.
        var bestMatch: String?
        var bestFreq: Int = -1

        func checkCandidate(_ candidateWord: String) {
            let freq = Int(bridge.getFrequency(candidateWord))
            if freq > 0 && freq > bestFreq {
                bestMatch = candidateWord
                bestFreq = freq
            } else if freq == 0 && bestFreq < 0 && bridge.wordExists(candidateWord) {
                // Fallback: word exists but getFrequency returns 0 (edge case)
                bestMatch = candidateWord
                bestFreq = 0
            }
        }

        // Single substitutions
        for (pos, accents) in accentablePositions {
            for accent in accents {
                var candidate = chars
                candidate[pos] = accent
                checkCandidate(String(candidate))
            }
        }

        // Double substitutions (déjà, après, éléphant, etc.)
        if accentablePositions.count >= 2 {
            for i in 0..<accentablePositions.count {
                for j in (i + 1)..<accentablePositions.count {
                    let (pos1, accents1) = accentablePositions[i]
                    let (pos2, accents2) = accentablePositions[j]
                    for a1 in accents1 {
                        for a2 in accents2 {
                            var candidate = chars
                            candidate[pos1] = a1
                            candidate[pos2] = a2
                            checkCandidate(String(candidate))
                        }
                    }
                }
            }
        }

        // Only return if an accented version was found with higher frequency than input.
        let inputFreq = Int(bridge.getFrequency(lowered))
        if let match = bestMatch, bestFreq > inputFreq {
            return match
        }
        return nil
    }

    // MARK: - N-gram prediction

    /// Load n-gram binary for the given language.
    /// Called after the spellcheck dictionary loads on the same loadQueue,
    /// so n-gram data is ready shortly after spell correction is available.
    func loadNgrams(language: String, bundle: Bundle = .main) {
        guard let path = bundle.path(forResource: "\(language)_ngrams", ofType: "dict") else {
            print("[AOSPTrieEngine] No n-gram data for \(language)")
            return
        }
        let success = bridge.loadNgrams(atPath: path)
        // Log file size to confirm the correct binary is loaded (769 bigrams = 38 KiB old, 1589 = 58 KiB new)
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int) ?? 0
        print("[AOSPTrieEngine] N-grams \(language): \(success ? "loaded" : "failed") (\(fileSize / 1024) KiB)")

        // Write diagnostic to App Group so app logs can confirm n-gram loading
        if let defaults = UserDefaults(suiteName: "group.solutions.pivi.dictus") {
            defaults.set("lang=\(language) ok=\(success) size=\(fileSize)", forKey: "ngramDiagnostic")
        }
    }

    /// Predict next words given 1-2 previous words.
    /// Uses trigram+bigram backoff when 2 words provided, bigram only for 1 word.
    ///
    /// WHY [String] input instead of String:
    /// The n-gram engine supports both bigram (1 word context) and trigram (2 word context).
    /// Passing an array lets the caller provide as much context as available without
    /// needing separate methods for each n-gram order.
    func predictNextWords(after words: [String], maxResults: Int = 3) -> [String] {
        guard bridge.ngramsLoaded() else { return [] }
        if words.count >= 2 {
            let result = bridge.predict(
                afterWord1: words[words.count - 2],
                word2: words[words.count - 1],
                maxResults: UInt(maxResults)
            )
            return result as? [String] ?? []
        } else if words.count == 1 {
            let result = bridge.predict(
                afterWord: words[0],
                maxResults: UInt(maxResults)
            )
            return result as? [String] ?? []
        }
        return []
    }

    /// Get bigram score for a candidate correction given previous word context.
    /// Returns 0 if no n-gram data or no match.
    /// Used by the prediction pipeline to boost corrections that match n-gram patterns.
    func bigramScore(for word: String, after prevWord: String) -> UInt16 {
        guard bridge.ngramsLoaded() else { return 0 }
        return bridge.bigramScore(forWord: word, afterWord: prevWord)
    }

    /// Returns nearby words (edit distance candidates) for a word, excluding the word itself.
    /// Unlike spellCheck, this returns results even for correctly-spelled words.
    /// Used by n-gram context boosting to find alternatives for valid-but-rare words
    /// (e.g., "sui" is valid but "suis" is much more likely after "je").
    func nearbyWords(for word: String) -> [String] {
        guard bridge.isLoaded(), !word.isEmpty else { return [] }
        return bridge.nearbyWords(word, maxEditDistance: 2.0, maxResults: 5) as? [String] ?? []
    }

    /// Whether n-gram data is loaded and ready for predictions.
    var ngramsLoaded: Bool { bridge.ngramsLoaded() }
}
