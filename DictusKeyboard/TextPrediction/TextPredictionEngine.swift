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

    /// Shared instance — engines are heavy (~3 MiB FrequencyDictionary + AOSP trie mmap).
    /// Per-controller instances were leaking via SwiftUI @ObservedObject zombies that
    /// survive their owning KeyboardViewController.deinit (KeyboardRootView struct held
    /// alive by KeyboardState.shared.objectWillChange subscription). Sharing the heavy
    /// resources means the leak no longer multiplies memory per app-switch cycle.
    static let shared = TextPredictionEngine()

    private let textChecker = UITextChecker()
    private var frequencyDict = FrequencyDictionary()
    private let aospTrieEngine = AOSPTrieEngine()
    private var language: String = "fr"
    /// The layout the dictionaries were last loaded for. See `setLanguage`.
    private var loadedLayout: LayoutType?

    /// The active language's data profile, or nil if `language` is not a registered
    /// `SupportedLanguage`. Used to gate language-specific pipeline stages by
    /// reading profile data instead of hardcoded language string comparisons.
    private var profile: LanguageProfile? {
        SupportedLanguage(rawValue: language)?.profile
    }

    /// Whether this process has already reported that the prune was done in an
    /// earlier session. See `reportPruneAlreadyDone()`.
    private var hasReportedPruneAlreadyDone = false

    /// Contact names and text replacements (#873). Written on the main thread
    /// when the keyboard appears, read by `spellCheck` on the main thread (space)
    /// and on the suggestion queue (bar), hence the lock.
    private var supplementaryLexicon = SupplementaryLexicon.empty
    private let lexiconLock = NSLock()

    private init() {
        loadDictionaries(for: language)
    }

    /// Updates the active language for completions and spell-checking.
    /// Reloads the frequency dictionary for the new language.
    ///
    /// WHY reload on language change:
    /// We only keep one language's frequency data in memory at a time
    /// to stay within the keyboard extension's ~50MB memory budget.
    ///
    /// WHY nothing happens when neither the language nor the layout changed (#555):
    /// `viewWillAppear` calls this on every keyboard appearance. Each load parses
    /// and sorts a whole frequency file on the main thread and remounts the trie
    /// and n-grams, and before this guard every appearance paid for it with data
    /// that had not changed. The layout is part of the key because the trie's
    /// substitution costs are built for the layout active at load time.
    func setLanguage(_ lang: String) {
        let layout = LayoutType.active
        guard lang != language || layout != loadedLayout else { return }
        language = lang
        loadDictionaries(for: lang)
    }

    /// Replaces the contacts + text replacements lexicon (#873).
    func setSupplementaryLexicon(_ lexicon: SupplementaryLexicon) {
        lexiconLock.lock()
        supplementaryLexicon = lexicon
        lexiconLock.unlock()
    }

    /// The lexicon's verdict on `word`, or nil when the lexicon does not know it.
    func lexiconDecision(for word: String) -> SupplementaryLexicon.Decision? {
        lexiconLock.lock()
        let lexicon = supplementaryLexicon
        lexiconLock.unlock()
        return lexicon.decision(for: word, isDictionaryWord: aospTrieEngine.wordExists(word.lowercased()))
    }

    /// The phrase of the text replacement shortcut `word` is, or nil (#1022).
    func textReplacement(for word: String) -> String? {
        lexiconLock.lock()
        let lexicon = supplementaryLexicon
        lexiconLock.unlock()
        return lexicon.expansion(ofShortcut: word)
    }

    /// Turns a lexicon verdict into a `spellCheck` result: nil keeps the word.
    private func lexiconResult(
        _ decision: SupplementaryLexicon.Decision,
        for word: String
    ) -> (correction: String, alternatives: [String])? {
        switch decision {
        case .keep:
            #if DEBUG
            AutocorrectDebugLog.autocorrectSkipped(word: word, reason: "lexicon")
            #endif
            return nil
        case .replace(let text):
            #if DEBUG
            AutocorrectDebugLog.autocorrectDecision(
                original: word, corrected: text, branch: "lexicon", prevWord: nil
            )
            #endif
            return (text, [])
        }
    }

    /// Loads both dictionaries for `lang` and runs the work that can only happen
    /// once a dictionary is actually loaded.
    private func loadDictionaries(for lang: String) {
        // Verify language is available in UITextChecker
        let available = UITextChecker.availableLanguages
        if !available.contains(where: { $0.hasPrefix(lang) }) {
            print("[TextPredictionEngine] Warning: '\(lang)' not in available languages: \(available)")
        }
        loadedLayout = LayoutType.active
        frequencyDict.load(language: lang)
        aospTrieEngine.load(language: lang) { [weak self] _ in
            // The user dictionary's one-shot prune (#287). This is the first
            // moment in a cold session at which anything can ask the dictionary a
            // question, so it has to be one of the triggers — but it is not a
            // privileged one. A completion can belong to a load that has since
            // been superseded, and the trie it finds may be another language's
            // entirely; the gate below is what decides, not the fact of being
            // called from here.
            self?.pruneUserDictionaryIfPossible(trigger: "dictionary-loaded")
        }
    }

    /// Attempts the user dictionary's one-shot prune, and says so when it cannot.
    ///
    /// WHY there are several triggers and no privileged one (#287). Two triggers
    /// exist because neither is sufficient alone: the load completion is the only
    /// moment a cold session can ask the dictionary anything, and it is
    /// rare once a session is warm — a load only happens on a language or layout
    /// change since #555, and before that `viewWillAppear` issued one on every
    /// appearance, tearing the mmap down before the previous completion ran. That
    /// starvation is why the prune never once ran on device. `viewWillAppear`
    /// therefore also attempts it before calling `setLanguage`, while the
    /// dictionary is mounted.
    ///
    /// Neither is trusted, and that is the point. `UserDictionaryPruneGate` holds
    /// the one precondition — the mounted dictionary is the active language's —
    /// so a trigger cannot be wrong, only early. Adding another is safe.
    ///
    /// Whenever the prune is still owed and cannot be done, a probe says why, so
    /// an export can never again be ambiguous between "never called", "called and
    /// declined", and "done long ago".
    func pruneUserDictionaryIfPossible(trigger: String) {
        let decision = UserDictionaryPruneGate.decide(
            alreadyPruned: UserDictionary.shared.hasPrunedTrieDuplicates,
            mountedLanguage: aospTrieEngine.mountedLanguage,
            activeLanguage: SupportedLanguage.active.rawValue
        )
        switch decision {
        case .run:
            UserDictionary.shared.pruneTrieDuplicatesIfNeeded(using: aospTrieEngine)
        case .alreadyDone:
            reportPruneAlreadyDone()
        case .notMounted, .languageMismatch:
            PersistentLog.log(.diagnosticProbe(
                component: "UserDictionaryPrune",
                instanceID: "",
                action: "skipped",
                details: "trigger=\(trigger) reason=\(decision.reason)"
            ))
        }
    }

    /// Says, once per keyboard process, that the prune has already been done.
    ///
    /// WHY this line has to exist. `userDictionaryPruned` is written once in the
    /// life of an install, and `PersistentLog` is a 1 MB file trimmed from the
    /// head — so an hour of ordinary use scrolls that line out of every later
    /// export. Without a standing statement, "this install was cleaned long ago"
    /// and "the prune is broken and never ran" are the same observation: silence.
    /// The third device pass on #287 was spent on exactly that ambiguity.
    ///
    /// WHY once per process and not once per call: `viewWillAppear` runs on every
    /// keyboard appearance, seventeen times in an hour of real use, and iOS keeps
    /// several controllers alive. One line per process is enough to date the
    /// state, and anything finer is the noise #255 was about.
    private func reportPruneAlreadyDone() {
        guard !hasReportedPruneAlreadyDone else { return }
        hasReportedPruneAlreadyDone = true
        PersistentLog.log(.diagnosticProbe(
            component: "UserDictionaryPrune",
            instanceID: "",
            action: "alreadyDone",
            details: "learnedCount=\(UserDictionary.shared.count)"
        ))
    }

    /// Whether `word` is genuinely new to the active language's dictionary —
    /// the gate the word-boundary learning site needs (#287 decision 2).
    ///
    /// WHY false while the dictionary is still loading: the answer would be
    /// "unknown" for every word typed in that window, and learning them all is
    /// exactly the pollution this gate exists to stop. AOSP LatinIME takes the
    /// same position for the same reason — it turns learning off entirely on a
    /// slow InputConnection, because a word it cannot vet is a word it should
    /// not keep. If we cannot ask, we do not learn.
    func isUnknownToDictionary(_ word: String) -> Bool {
        aospTrieEngine.isReady && !aospTrieEngine.knowsWord(word)
    }

    /// Returns up to 3 word completions for a partial word, ranked by frequency.
    ///
    /// HOW IT WORKS:
    /// 1. UITextChecker.completions() returns all possible completions from the system dictionary
    /// 2. We order those completions by our frequency dictionary, most common first
    ///    (the dictionary answers with a frequency count: higher = more common)
    /// 3. LearnedWordCompletions gives one word the user taught us the first slot (#346)
    /// 4. We return only the top 3 to fill the suggestion bar's 3 slots
    ///
    /// WHY frequency-based ranking:
    /// UITextChecker returns completions in alphabetical order by default. Ranking by
    /// word frequency ensures "les" appears before "lesparre" when typing "le".
    ///
    /// WHY the learned set is read here on every keystroke, with no cache:
    /// it lives in memory, holds tens of entries since #287 stopped learning
    /// words the trie already knows, and this runs on the suggestion queue. A
    /// cache would only add an invalidation to get wrong — the other process
    /// writes to this dictionary too.
    func suggestions(for partialWord: String) -> [String] {
        guard !partialWord.isEmpty else { return [] }

        let nsString = partialWord as NSString
        let range = NSRange(location: 0, length: nsString.length)

        // `?? []` and not an early return: a prefix the system checker has
        // nothing to say about is exactly the case a learned word exists for.
        let completions = textChecker.completions(
            forPartialWordRange: range,
            in: partialWord,
            language: language
        ) ?? []

        let ranked = frequencyDict.sortedMostCommonFirst(completions)
        return LearnedWordCompletions.merge(
            typedPrefix: partialWord,
            learnedWords: UserDictionary.shared.learnedWordsByLastUsed,
            systemCompletions: ranked
        )
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
    /// - Parameter isAtSentenceStart: whether the word sits at a sentence start
    ///   in the host document (start-of-field, after newline or after .!?).
    ///   Drives the proper-noun guard (#199): mid-sentence capitalized unknown
    ///   words are preserved. Defaults to `true`, the conservative value —
    ///   callers without position info keep full correction behavior (only the
    ///   position-independent acronym rule applies).
    func spellCheck(
        _ word: String,
        isAtSentenceStart: Bool = true
    ) -> (correction: String, alternatives: [String])? {
        checkWord(word, isAtSentenceStart: isAtSentenceStart, previousWord: nil)?.proposal.autocorrection
    }

    /// What `checkWord` proposes, and whether it was already decided with the previous
    /// word, in which case the bigram rerank must leave it alone. A suggestion (#993)
    /// always counts as decided: the rerank would turn it into a correction.
    private struct CheckedWord {
        let proposal: CorrectionProposal
        let rankedInContext: Bool

        init(correction: String, alternatives: [String], rankedInContext: Bool = false) {
            proposal = .autocorrect(correction, alternatives: alternatives)
            self.rankedInContext = rankedInContext
        }

        init(_ proposal: CorrectionProposal) {
            self.proposal = proposal
            rankedInContext = true
        }
    }

    /// The body of `spellCheck(_:isAtSentenceStart:)`. `previousWord` is only read by
    /// the trie pass and the accent pass, which rank their candidates with it (#993).
    private func checkWord(
        _ word: String,
        isAtSentenceStart: Bool,
        previousWord: String?
    ) -> CheckedWord? {
        guard !word.isEmpty else { return nil }

        // The user's own contacts and text replacements (#873) outrank every
        // dictionary rule below, the language overrides included.
        if let decision = lexiconDecision(for: word) {
            return lexiconResult(decision, for: word).map { CheckedWord(correction: $0.correction, alternatives: $0.alternatives) }
        }

        // Language-specific overrides bypass everything — e.g., "ca" is never valid French.
        // Must check before UserDictionary, otherwise typing "ca" twice
        // would "learn" it and block the ça correction permanently.
        if let result = aospTrieEngine.languageOverride(for: word) {
            #if DEBUG
            AutocorrectDebugLog.autocorrectDecision(
                original: word, corrected: result.correction,
                branch: "language-override", prevWord: nil
            )
            #endif
            return CheckedWord(correction: result.correction, alternatives: result.alternatives)
        }

        // Apostrophe prefix fix: when the user types an apostrophe after an
        // invalid contraction prefix ("v'est", "qj'on"), correct the prefix via
        // keyboard proximity (`ElisionRepair.prefixSlips`, French only).
        //
        // WHY before everything else:
        // Our downstream apostrophe split only validates the part AFTER the
        // apostrophe — "v'est" → checks "est" (valid) → returns nil (no correction).
        // We need to intercept wrong prefixes explicitly.
        if let repaired = profile?.elisionRepair?.repairPrefix(word, isWord: aospTrieEngine.wordExists), allowsElision(repaired) {
            let display = Self.capitalized(repaired, like: word)
            #if DEBUG
            AutocorrectDebugLog.autocorrectDecision(
                original: word, corrected: display, branch: "apostrophe-prefix", prevWord: nil
            )
            #endif
            return CheckedWord(correction: display, alternatives: [])
        }

        // Two-pass lookup: user dictionary first (learned words are always "correct").
        // Extract the word part after any apostrophe for user dict check, matching
        // the same apostrophe handling that AOSPTrieEngine uses internally.
        let lowered = word.lowercased()
        let wordToCheck: String
        let apostrophePrefix: String?
        if let apoIndex = lowered.lastIndex(of: "'") {
            wordToCheck = String(lowered[lowered.index(after: apoIndex)...])
            apostrophePrefix = String(lowered[...apoIndex])
        } else {
            wordToCheck = lowered
            apostrophePrefix = nil
        }
        if UserDictionary.shared.isLearned(wordToCheck) {
            #if DEBUG
            AutocorrectDebugLog.autocorrectSkipped(word: word, reason: "user-learned")
            #endif
            return nil  // User-learned word: no correction needed
        }

        // Accent restoration runs BEFORE wordExists check.
        // "arrive" is a word, but after "est" it is "arrivé"; "manana" is in the trie
        // as a rare word, but "mañana" is 275 times as frequent (#994).
        // "deja" → "déjà", "apres" → "après", "tres" → "très"
        // The apostrophe prefix must be reassembled: wordToCheck is only the
        // part after the apostrophe, so "J'etais" checks "etais" → "étais" and
        // the correction is "j'" + "étais", not bare "étais".
        let isCapitalized = word.first?.isUppercase == true
        let display = { (spelling: String) -> String in
            let full = (apostrophePrefix ?? "") + spelling
            return isCapitalized ? full.capitalized : full
        }
        let elided = { (spelling: String) in self.allowsElided(spelling, after: apostrophePrefix) }
        switch aospTrieEngine.accentRestoration(wordToCheck, previousWord: previousWord) {
        case .restore(let accented) where elided(accented):
            let corrected = display(accented)
            #if DEBUG
            AutocorrectDebugLog.autocorrectDecision(
                original: word, corrected: corrected, branch: "accent", prevWord: previousWord
            )
            #endif
            return CheckedWord(correction: corrected, alternatives: [])
        case .ambiguous(let spellings) where spellings.contains(where: elided):
            // Two accented spellings, equally likely (#993): `reserve` is `réserve` or
            // `réservé`. Keep what was typed, offer both.
            #if DEBUG
            AutocorrectDebugLog.autocorrectSkipped(word: word, reason: "ambiguous-accent")
            #endif
            return CheckedWord(.suggest(spellings.filter(elided).map(display)))
        case .restore, .ambiguous, .keepTyped:
            break
        }

        // Valid word guard: if the word exists in the trie dictionary, it's correct.
        // This prevents aggressive corrections like "fais" → "vais".
        // Runs AFTER accent expansion so "tres" → "très" still works.
        if aospTrieEngine.wordExists(wordToCheck) {
            #if DEBUG
            AutocorrectDebugLog.autocorrectSkipped(word: word, reason: "already-valid")
            #endif
            return nil
        }

        // The key left of the apostrophe typed in its place (#1006): "qunil" → "qu'il".
        // Before the contraction expansion, which reads "qunon" as "qu'non": French
        // never elides before a consonant.
        if let repaired = profile?.elisionRepair?.repairApostropheSlip(word) {
            let corrected = Self.capitalized(repaired, like: word)
            #if DEBUG
            AutocorrectDebugLog.autocorrectDecision(
                original: word, corrected: corrected, branch: "apostrophe-slip", prevWord: nil
            )
            #endif
            return CheckedWord(correction: corrected, alternatives: [])
        }

        // Contraction expansion: "Cest" → "C'est", "jai" → "j'ai"
        // Runs BEFORE the proper-noun guard: like accent expansion, it's a
        // high-confidence exact transformation (registered prefix + dictionary
        // suffix), so a capitalized "Cest" mid-sentence must correct to "C'est"
        // rather than be preserved as a pseudo-name (and worse, learned).
        if let expanded = aospTrieEngine.contractionExpansion(word) {
            let isCapitalized = word.first?.isUppercase == true
            let corrected = isCapitalized ? expanded.capitalized : expanded
            #if DEBUG
            AutocorrectDebugLog.autocorrectDecision(
                original: word, corrected: corrected, branch: "contraction", prevWord: nil
            )
            #endif
            return CheckedWord(correction: corrected, alternatives: [])
        }

        // Proper-noun guard (#199): only unknown words reach this point.
        // An unknown capitalized word mid-sentence ("vu Mathilde") or an
        // all-caps acronym ("SNCF") is most likely intentional — preserve it
        // instead of forcing the closest dictionary word. Runs AFTER the
        // high-confidence branches (languageOverride, UserDictionary, accent
        // and contraction expansion) but BEFORE the fuzzy ones (split, trie).
        // The preserved word is then learned via handleSpace's recordUsage path,
        // protecting future occurrences even at sentence start.
        if ProperNounGuard.isLikelyProperNoun(word: word, isAtSentenceStart: isAtSentenceStart) {
            #if DEBUG
            AutocorrectDebugLog.autocorrectSkipped(word: word, reason: "likely-proper-noun")
            #endif
            return nil
        }

        // A learned word one edit away (#498). Runs after the dictionary and
        // proper-noun guards, so it only ever rewrites a word that is neither a
        // dictionary word nor a likely name, and before the fuzzy passes, which
        // would otherwise pick a dictionary word for a word the user taught.
        if let learned = LearnedWordCorrection.target(
            for: wordToCheck,
            learnedWords: UserDictionary.shared.allLearnedWords,
            dictionaryKnows: aospTrieEngine.wordExists
        ), allowsElided(learned, after: apostrophePrefix) {
            let full = (apostrophePrefix ?? "") + learned
            let isCapitalized = word.first?.isUppercase == true
            let corrected = isCapitalized ? full.capitalized : full
            #if DEBUG
            AutocorrectDebugLog.autocorrectDecision(
                original: word, corrected: corrected, branch: "learned", prevWord: nil
            )
            #endif
            return CheckedWord(correction: corrected, alternatives: [])
        }

        // Word splitting + single-word correction comparison.
        //
        // Strategy (informed by real user feedback + debug log analysis):
        //
        // 1. Split with bigram evidence (any strategy) → accept. The n-gram
        //    model confirms this is a real phrase pattern.
        //
        // 2. Split with boundary signal but NO bigram evidence → compare ED.
        //    Our Wikipedia corpus misses colloquial phrases like "pas mal"
        //    (bigram score 0) but the spacebar-neighbor key proves a missed
        //    space. Accept the split only when it fits the input noticeably
        //    better than the trie's single-word correction (split ED + 1 ≤
        //    single ED). This rejects "fonction agités" cases where single-
        //    word correction is at ED 0 or 1 but keeps "pas mal" cases
        //    where single-word "Pascal" is at ED 2 and split ED is 1.
        //
        // 3. No split → fall through to trie single-word correction.
        //
        // The halves are then written by the accent pass (#1006): "suisnarrive" →
        // "suis arrivé". The edit distances below compare the letters as typed.
        if let candidate = trySplit(wordToCheck, previousWord: previousWord) {
            let splitHasBoundary = candidate.usesBoundaryKey
            let splitHasBigram = candidate.hasBigram
            let useSplit: Bool
            if splitHasBigram {
                useSplit = true  // bigram confirmed, accept
            } else if splitHasBoundary {
                // Boundary-only (no bigram): compare with single-word correction via ED
                if let single = aospTrieEngine.spellCheck(word) {
                    let splitJoined = candidate.left + candidate.right
                    let splitED = Self.editDistance(wordToCheck, splitJoined)
                    let singleLower = single.correction.lowercased()
                    let singleWordPart: String
                    if let idx = singleLower.lastIndex(of: "'") {
                        singleWordPart = String(singleLower[singleLower.index(after: idx)...])
                    } else {
                        singleWordPart = singleLower
                    }
                    let singleED = Self.editDistance(wordToCheck, singleWordPart)
                    // Accept split only if strictly better fit (split + 1 ≤ single).
                    // "pasnmal": split "pasmal" ED 1, single "pascal" ED 2 → 1+1=2 ≤ 2 ✓
                    // "fonctionnalités": split "fonctionagités" ED ~3, single ED 0/1 → reject ✓
                    useSplit = (splitED + 1) <= singleED
                } else {
                    useSplit = true  // no single-word alternative, accept split
                }
            } else {
                useSplit = false  // direct split rejected without bigram (prevented by trySplit)
            }

            let split = GluedWordSplit.written(candidate, previousWord: previousWord, restore: aospTrieEngine.accentRestoration)
            if useSplit {
                let result = Self.capitalized(split, like: word)
                #if DEBUG
                AutocorrectDebugLog.autocorrectDecision(
                    original: word, corrected: result,
                    branch: splitHasBoundary ? "split-boundary" : "split-bigram",
                    prevWord: previousWord
                )
                #endif
                return CheckedWord(correction: result, alternatives: [])
            }
            #if DEBUG
            AutocorrectDebugLog.note("split \"\(split)\" rejected (ED comparison favored single-word)")
            #endif
        }

        // Pass 5: the trie's candidates, ranked with the previous word (#993).
        return trieCorrection(of: word, wordToCheck: wordToCheck, apostrophePrefix: apostrophePrefix,
                              previousWord: previousWord)
    }

    /// The trie pass of `checkWord`. `CorrectionRanking` keeps the typed word when two
    /// candidates are equally good, rather than letting whichever the trie listed
    /// first win (#993).
    private func trieCorrection(
        of word: String,
        wordToCheck: String,
        apostrophePrefix: String?,
        previousWord: String?
    ) -> CheckedWord? {
        // French never elides before a consonant: `d'cirre` is not `d'votre`. With
        // every candidate dropped, the decision keeps the typed word.
        let candidates = rankedCandidates(for: wordToCheck, previousWord: previousWord)
            .filter { allowsElided($0.word, after: apostrophePrefix) }
        let decision = CorrectionRanking.decide(candidates)
        #if DEBUG
        AutocorrectDebugLog.trieCandidates(word: word, candidates: candidates, decision: decision)
        #endif
        let isCapitalized = word.first?.isUppercase == true
        // The corrected word gets the accents a typed one would (#1006): `est zrrive`
        // is corrected to `arrive`, and after `est` that is `arrivé`.
        let accented = decision.proposal.map {
            CorrectedWordAccents.restored($0) { aospTrieEngine.accentRestoration($0, previousWord: previousWord) }
        }
        guard let proposal = accented?.mapWords({ candidate in
            let full = (apostrophePrefix ?? "") + candidate
            return isCapitalized ? full.capitalized : full
        }) else {
            #if DEBUG
            AutocorrectDebugLog.autocorrectSkipped(word: word, reason: "no-trie-candidate")
            #endif
            return nil
        }
        #if DEBUG
        if let correction = proposal.autocorrection?.correction {
            AutocorrectDebugLog.autocorrectDecision(
                original: word, corrected: correction, branch: "trie", prevWord: previousWord
            )
        } else {
            AutocorrectDebugLog.autocorrectSkipped(word: word, reason: "ambiguous-candidates")
        }
        #endif
        // A trie result is ranked with the previous word already, a suggestion included.
        return CheckedWord(proposal)
    }

    /// The trie's candidates for `word` (lowercased, no apostrophe prefix), each with
    /// its bigram score after `previousWord` when the n-gram data is loaded.
    private func rankedCandidates(for word: String, previousWord: String?) -> [CorrectionCandidate] {
        let candidates = aospTrieEngine.correctionCandidates(for: word)
        guard let previous = previousWord?.lowercased(), !previous.isEmpty, aospTrieEngine.ngramsLoaded else {
            return candidates
        }
        return candidates.map {
            CorrectionCandidate(
                word: $0.word, cost: $0.cost, frequency: $0.frequency,
                context: aospTrieEngine.bigramScore(for: $0.word, after: previous)
            )
        }
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
    func spellCheck(
        _ word: String,
        previousWord: String?,
        isAtSentenceStart: Bool = true
    ) -> (correction: String, alternatives: [String])? {
        correctionProposal(for: word, previousWord: previousWord, isAtSentenceStart: isAtSentenceStart)?
            .autocorrection
    }

    /// What `spellCheck(_:previousWord:isAtSentenceStart:)` decides, plus the
    /// suggestions it offers when it keeps the typed word (#993). The suggestion bar
    /// reads this; the space bar reads `spellCheck`, so a suggestion is never applied.
    func correctionProposal(
        for word: String,
        previousWord: String?,
        isAtSentenceStart: Bool = true
    ) -> CorrectionProposal? {
        let applied = { (result: (correction: String, alternatives: [String])?) -> CorrectionProposal? in
            result.map { .autocorrect($0.correction, alternatives: $0.alternatives) }
        }

        // The space bar replaces both words with the elision (#1006). A correction of
        // this word alone would be wrong: `ce st` made `s't`.
        if let previousWord, elisionAcrossSpace(previousWord: previousWord, word: word) != nil {
            return nil
        }

        // Lexicon verdicts (#873) return before the bigram rerank, which could
        // otherwise swap a replacement phrase or a kept name for a neighbour.
        if let decision = lexiconDecision(for: word) {
            return applied(lexiconResult(decision, for: word))
        }

        // Language overrides are authoritative — return before the bigram
        // rerank can replace them. Concrete failure this prevents (#222):
        // "je lai" → override "l'ai", but the corpus tokenizes "j'ai" as ONE
        // token so bigram("ai" after "je") = 0, while bigram("lui" after "je")
        // is huge and "lui" sits at edit distance 1 of "lai" — the rerank
        // replaced the override with "lui" ("je lai fais" → "je lui fais").
        if let override = aospTrieEngine.languageOverride(for: word) {
            #if DEBUG
            AutocorrectDebugLog.autocorrectDecision(
                original: word, corrected: override.correction,
                branch: "language-override", prevWord: previousWord
            )
            #endif
            return applied(override)
        }
        // A contraction that is also a word (`ill` for `I'll`, #995) needs the
        // previous word, which only this entry point has.
        if let profile = profile,
           let contraction = contextualContraction(
               profile: profile, word: word, previousWord: previousWord, isAtSentenceStart: isAtSentenceStart
           ) {
            #if DEBUG
            AutocorrectDebugLog.autocorrectDecision(
                original: word, corrected: contraction,
                branch: "contextual-contraction", prevWord: previousWord
            )
            #endif
            return .autocorrect(contraction, alternatives: [])
        }

        let checked = checkWord(word, isAtSentenceStart: isAtSentenceStart, previousWord: previousWord)
        let result = checked?.proposal.autocorrection

        // If no previous word context or n-grams not loaded, return standard result.
        // A trie correction was already ranked with the previous word.
        guard let prev = previousWord, !prev.isEmpty, aospTrieEngine.ngramsLoaded,
              checked?.rankedInContext != true else {
            return checked?.proposal
        }

        // A learned word has no bigrams, so the rerank below would trade it for
        // any n-gram prediction one edit away (#498).
        if let correction = result?.correction,
           UserDictionary.shared.isLearned(String(correction.lowercased().split(separator: "'").last ?? "")) {
            return applied(result)
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
                guard allowsElided(prediction, after: prefix) else { return nil }
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
                // `prefix ?? ""` reproduces the nil branch exactly: prepending the
                // empty string is the identity, which is what nil returned before.
                let full = (prefix ?? "") + prediction
                let display = isCapitalized ? full.capitalized : full
                if let existing = candidateSet[display] {
                    candidateSet[display] = max(existing, score)
                } else {
                    candidateSet[display] = score
                }
            }

            // CRITICAL: if no candidate has ANY bigram evidence (all scores = 0),
            // the rerank becomes a random pick based on Dictionary iteration order.
            // This corrupted good trie corrections like "main" → "mais" with no
            // real justification. In this case, keep the trie's original result.
            let hasAnyBigramEvidence = candidateSet.values.contains { $0 > 0 }
            guard hasAnyBigramEvidence else {
                #if DEBUG
                AutocorrectDebugLog.note(
                    "bigram-rerank skipped (no evidence) for \"\(word)\" prev=\"\(prev)\", keeping \"\(result.correction)\""
                )
                #endif
                return applied(result)
            }

            // CRITICAL: the rerank must not pick a candidate that's FARTHER from
            // the typed input than the original trie winner. Example from debug
            // logs: pejx → trie chose "peux" (ED 1), but bigram("veux" after "tu")
            // = 49828 while bigram("peux" after "tu") = 0 (data gap, our corpus
            // lacks common colloquial phrases). Rerank promoted "veux" (ED 2)
            // over "peux" (ED 1), forcing the user to undo.
            //
            // Fix: filter candidates to those at ED ≤ original winner's ED. The
            // rerank may still reorder within this set, but can never move to a
            // less-proximal candidate. Prevents bigram data gaps from overriding
            // the trie's proximity scoring.
            let originalWordPart: String = {
                let ol = result.correction.lowercased()
                if let idx = ol.lastIndex(of: "'") {
                    return String(ol[ol.index(after: idx)...])
                } else {
                    return ol
                }
            }()
            let originalED = Self.editDistance(wordToCheck, originalWordPart)

            let eligible = candidateSet.filter { candidate, _ in
                let cl = candidate.lowercased()
                let cWordPart: String
                if let idx = cl.lastIndex(of: "'") {
                    cWordPart = String(cl[cl.index(after: idx)...])
                } else {
                    cWordPart = cl
                }
                return Self.editDistance(wordToCheck, cWordPart) <= originalED
            }
            // Safety: if filter removed everything (shouldn't happen — original is always eligible),
            // fall back to full set.
            let candidates = eligible.isEmpty ? candidateSet : eligible

            // Ties go to the word itself, so the answer never depends on the
            // `Dictionary`'s hash order (#993: `meef` was `meer` or `meet` by process).
            let reranked = candidates.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            let newCorrection = reranked[0].key
            let newAlternatives = reranked.dropFirst().map { $0.key }
            #if DEBUG
            if newCorrection != result.correction {
                let beforeScore = candidateSet[result.correction] ?? 0
                let afterScore = reranked[0].value
                AutocorrectDebugLog.bigramRerank(
                    word: word, prevWord: prev,
                    before: (result.correction, beforeScore),
                    after: (newCorrection, afterScore)
                )
            }
            #endif
            return .autocorrect(newCorrection, alternatives: Array(newAlternatives.prefix(2)))
        }

        // Word is valid (spellCheck returned nil) — do not override with n-gram
        // predictions. This prevents "je fais" → "je vais" when "fais" is valid.
        return nil
    }

    /// The elision `previousWord` and `word` make when the space between them stands
    /// for an apostrophe (#1006): `qu il` → `qu'il`, `ce st` → `c'est`. The space bar
    /// replaces both words with it. Nil for a text replacement shortcut or a learned word.
    func elisionAcrossSpace(previousWord: String, word: String) -> String? {
        guard let repair = profile?.elisionRepair,
              !UserDictionary.shared.isLearned(word.lowercased()) else { return nil }
        if case .replace = lexiconDecision(for: word) { return nil }
        guard let joined = repair.joinAcrossSpace(previousWord: previousWord, word: word, isWord: aospTrieEngine.wordExists)
        else { return nil }
        return Self.capitalized(joined, like: previousWord)
    }

    /// Whether `word` may follow the apostrophe prefix `prefix` in the active language:
    /// French never elides before a consonant, so `votre` may not follow `d'`.
    private func allowsElided(_ word: String, after prefix: String?) -> Bool {
        profile?.allowsElided(word, after: prefix) ?? true
    }

    /// Whether a whole word, prefix included, is allowed in the active language.
    private func allowsElision(_ word: String) -> Bool {
        profile?.allowsElision(word) ?? true
    }

    /// `text` with a capital first letter when `typed` starts with one. Only the first
    /// letter: `String.capitalized` would write "Qu'Il".
    private static func capitalized(_ text: String, like typed: String) -> String {
        typed.first?.isUppercase == true ? text.prefix(1).uppercased() + text.dropFirst() : text
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

    // MARK: - Word Splitting

    /// Keys adjacent to the spacebar on each keyboard layout.
    /// When the user presses one of these instead of space, two words get fused.
    /// On AZERTY: bottom row is W-X-C-V-B-N — only N (rightmost, next to space/comma)
    /// and B are truly adjacent to the spacebar. V was previously included but is
    /// 3 keys from space, causing false splits like "calvier" → "cal hier".
    /// On QWERTY: bottom row is Z-X-C-V-B-N-M — M is rightmost (next to space),
    /// N and B are close enough to count.
    /// QWERTZ shares the QWERTY set: its bottom row is Y-X-C-V-B-N-M, so the three
    /// keys adjacent to the spacebar are the same ones (#151).
    private static let azertySpacebarNeighbors: Set<Character> = ["n", "b", ","]
    private static let qwertySpacebarNeighbors: Set<Character> = ["n", "b", "m"]

    /// Short words (2 chars) that are allowed to appear as split parts.
    /// Standard split requires ≥3 chars per part to avoid noise like "ho ne",
    /// but French has many 2-char pronouns/articles/connectives that commonly
    /// start missed-space compounds (e.g., "tuboeux" should split as "tu peux",
    /// "jepense" as "je pense"). This allowlist restricts the 2-char relaxation
    /// to words that are structurally plausible as a left/right split half.
    /// The set is shared by every language. Each word past the French ones was
    /// admitted only after the split-pass bench (tools/split-pass-bench, #499) showed
    /// it recovers glues and adds no false or wrong split in any language. "de",
    /// "of", "el", "zu", "so" and "sa" were measured and left out for adding one, and
    /// "no" for trapping on "queno" (#499).
    private static let shortSplitAllowlist: Set<String> = [
        "je", "tu", "il", "on", "me", "te", "se", "ne",
        "le", "la", "un", "du", "au", "en",
        "et", "ou", "ni", "si", "ça", "où", "ce",
        "pu", "vu",
        "to", "is", "in", "at", "by", "be", "go", "my",
        "es", "mi", "lo",
        "an", "er"
    ]

    /// Whether a split part is long enough or belongs to the short-word allowlist.
    private static func isValidSplitPart(_ part: String) -> Bool {
        return part.count >= 3 || (part.count == 2 && shortSplitAllowlist.contains(part))
    }

    /// The split of `word` the split pass proposes, chosen by `GluedWordSplit.best`.
    ///
    /// Evidence sources:
    /// - boundary key: the split dropped a spacebar-neighbor char, strong physical evidence
    /// - bigram: the pair (left, right) has a bigram score > 0, linguistic evidence
    ///
    /// Rules for a candidate:
    /// - Direct split (no boundary): REQUIRES bigram. Prevents "honnête lent".
    /// - Boundary split: allowed WITHOUT bigram (our n-gram corpus misses
    ///   colloquial phrases like "pas mal"). Caller applies an ED comparison
    ///   with the single-word correction to decide.
    ///
    /// `previousWord` adds the bigram of the left half after it to the score.
    private func trySplit(_ word: String, previousWord: String?) -> GluedWordSplit.Candidate? {
        let chars = Array(word)
        // Minimum absolute part length 2; each part must also pass isValidSplitPart
        // which requires either ≥3 chars or membership in the short-word allowlist.
        // This lets "tu peux" split from "tuboeux" while still blocking "ho ne"
        // from "honne" (since "ho" is not allowlisted).
        let minPartLength = 2
        guard chars.count >= 4 else { return nil }

        let spacebarNeighbors = LayoutType.active == .azerty
            ? Self.azertySpacebarNeighbors
            : Self.qwertySpacebarNeighbors
        let previous = previousWord?.lowercased()

        var candidates: [GluedWordSplit.Candidate] = []
        func candidate(left: String, right: String, usesBoundaryKey: Bool) -> GluedWordSplit.Candidate {
            GluedWordSplit.Candidate(
                left: left, right: right, usesBoundaryKey: usesBoundaryKey,
                bigram: aospTrieEngine.bigramScore(for: right, after: left),
                contextBigram: previous.map { aospTrieEngine.bigramScore(for: left, after: $0) } ?? 0,
                frequencyProduct: UInt64(aospTrieEngine.wordFrequency(left)) * UInt64(aospTrieEngine.wordFrequency(right))
            )
        }

        for splitPos in minPartLength...(chars.count - minPartLength) {
            let left = String(chars[0..<splitPos])
            let right = String(chars[splitPos...])

            // Both parts must meet the length/allowlist requirement.
            guard Self.isValidSplitPart(left), aospTrieEngine.wordExists(left) else { continue }

            // Boundary-char removal at spacebar neighbor (bigram OPTIONAL)
            if spacebarNeighbors.contains(chars[splitPos]) {
                let rightAfter = String(chars[(splitPos + 1)...])
                if Self.isValidSplitPart(rightAfter) {
                    if aospTrieEngine.wordExists(rightAfter) {
                        // Case A: both halves valid as-is
                        candidates.append(candidate(left: left, right: rightAfter, usesBoundaryKey: true))
                    } else if rightAfter.count >= 3, let c = aospTrieEngine.spellCheck(rightAfter) {
                        // Case B: right half needs spell correction (min 3 chars to avoid
                        // correcting short garbage into arbitrary words).
                        candidates.append(candidate(left: left, right: c.correction, usesBoundaryKey: true))
                    }
                }
            }

            // Direct split — REQUIRES bigram evidence (no boundary signal to fall back on)
            guard Self.isValidSplitPart(right), aospTrieEngine.wordExists(right) else { continue }
            let direct = candidate(left: left, right: right, usesBoundaryKey: false)
            if direct.hasBigram { candidates.append(direct) }
        }

        let winner = GluedWordSplit.best(candidates)
        #if DEBUG
        if let winner {
            AutocorrectDebugLog.splitEvaluation(
                word: word,
                boundaryBest: GluedWordSplit.best(candidates.filter(\.usesBoundaryKey)).map { "\($0.left) \($0.right)" },
                bigramBest: GluedWordSplit.best(candidates.filter { !$0.usesBoundaryKey }).map { "\($0.left) \($0.right)" },
                winner: "\(winner.left) \(winner.right)"
            )
        }
        #endif
        return winner
    }

}
