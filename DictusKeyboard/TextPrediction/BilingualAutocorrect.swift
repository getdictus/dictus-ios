// DictusKeyboard/TextPrediction/BilingualAutocorrect.swift
//
// Bilingual autocorrect (#1015): French and English corrected together, without
// switching language. The partner engine, its fallback and the tie-break by the words
// before follow Hex's bilingual autocorrect (github.com/anomalyco/hex, branch `dev`,
// `AutocorrectEngine.cautiousReplacement` and `KeyboardLanguageList.partner`, MIT,
// Copyright (c) 2026 Christopher Langton). The language window (#1009) and the keep
// rule are Dictus's. This file is the keyboard's side of it: the switch and the second
// engine. The decisions are DictusCore's `BilingualCheck`, tested there.
import DictusCore
import Foundation

/// Whether the bilingual check runs, and the partner engine it holds.
enum BilingualAutocorrect {
    /// App Group key of the switch. Debug builds only: a Release build never reads it.
    ///
    /// WHY here and not in `SharedKeys`: like `SpatialAutocorrect.switchKey` (#1011), an
    /// experiment of the keyboard's that nothing else reads, until PR 4 gives it a
    /// setting after #992.
    ///
    /// Turn it on with the Debug app's launch argument, then make the keyboard reappear:
    /// `xcrun devicectl device process launch --device <id> com.pivi.dictus -DictusDebugBilingualAutocorrect YES`
    /// (`xcrun simctl launch <udid> com.pivi.dictus -DictusDebugBilingualAutocorrect YES` on a simulator).
    static let switchKey = "debug.bilingualAutocorrect"

    static var isOn: Bool {
        #if DEBUG
        return AppGroup.defaults.bool(forKey: switchKey)
        #else
        return false
        #endif
    }

    #if DEBUG
    /// The App Group key of Adaptive touch's switch (#1014, `AdaptiveTouchSwitch.switchKey`).
    static let adaptiveSwitchKey = "debug.adaptiveTouch"

    /// The three Debug switches, for the journal's `TJ SWITCHES` line.
    ///
    /// WHY Adaptive touch's rule restated: `AdaptiveTouchSwitch` is #1018's, not on this
    /// branch. Its `isOn` is the decoder's switch and its own; once both PRs are in, this
    /// reads `AdaptiveTouchSwitch.isOn`.
    static var debugSwitches: DebugSwitches {
        let keys = [SpatialAutocorrect.switchKey, adaptiveSwitchKey, switchKey]
        return DebugSwitches(
            spatial: SpatialAutocorrect.isOn,
            adaptive: SpatialAutocorrect.isOn && AppGroup.defaults.bool(forKey: adaptiveSwitchKey),
            bilingual: isOn,
            source: DebugSwitches.source(of: keys, in: AppGroup.defaults)
        )
    }
    #endif

    private static let lock = NSLock()
    private static var keyboard: BilingualKeyboard?
    private static var lexicon: SupplementaryLexicon?

    /// The check for the keyboard's language, or nil when the switch is off or the
    /// language has no partner.
    static var current: BilingualKeyboard? {
        guard isOn else { return nil }
        lock.lock()
        defer { lock.unlock() }
        return keyboard
    }

    /// Follows the keyboard's language: `primary` is the one `engine`, the shared engine,
    /// was just set to. Main thread, from `SuggestionState.setLanguage`.
    ///
    /// The partner is the other of French and English (`KeyboardLanguagePair`). Its
    /// engine loads for the primary's layout, the grid both languages are typed on, and
    /// follows it when it changes. Turning the switch off releases it.
    static func follow(primary: String, engine: TextPredictionEngine) {
        guard isOn, let language = SupportedLanguage(rawValue: primary),
              let secondary = KeyboardLanguagePair.secondaries(for: language).first,
              let pair = KeyboardLanguagePair(primary: language, secondary: secondary) else {
            lock.lock()
            keyboard = nil
            lock.unlock()
            return
        }
        lock.lock()
        let existing = keyboard
        lock.unlock()
        if let existing, existing.pair == pair {
            existing.engine(secondary).setLanguage(secondary.rawValue)
            return
        }
        // Reuse the partner engine across a swap of the pair (fr+en to en+fr): its
        // dictionaries are already loaded.
        let partner: TextPredictionEngine
        if let existing, let reused = existing.engines.values.first(where: {
            $0 !== engine && $0.languageCode == secondary.rawValue
        }) {
            partner = reused
            partner.setLanguage(secondary.rawValue)
        } else {
            partner = TextPredictionEngine(language: secondary.rawValue)
        }
        lock.lock()
        if let lexicon { partner.setSupplementaryLexicon(lexicon) }
        keyboard = BilingualKeyboard(pair: pair, engines: [language: engine, secondary: partner])
        lock.unlock()
    }

    /// The contacts and text replacements lexicon (#873), for the partner engine too:
    /// a contact's name is no typo in either language.
    static func setSupplementaryLexicon(_ supplementary: SupplementaryLexicon) {
        lock.lock()
        lexicon = supplementary
        let engines = keyboard.map { Array($0.engines.values) } ?? []
        lock.unlock()
        for engine in engines { engine.setSupplementaryLexicon(supplementary) }
    }
}

/// A bilingual keyboard's two engines and its language window.
///
/// The window (`LanguageWindow`) names the language of the bar: letters ask that
/// language only, so a second language costs nothing per letter unless the bar is
/// already in it. On a space the word votes, the window moves, and `BilingualCheck`
/// decides the word with both languages, the partner reading the same taps.
///
/// Used from the main thread (space) and the suggestion queue (letters): the window
/// is behind a lock, and each engine is as thread-safe as the keyboard's one engine.
final class BilingualKeyboard {
    let pair: KeyboardLanguagePair
    let engines: [SupportedLanguage: TextPredictionEngine]
    private let lock = NSLock()
    private var window: LanguageWindow
    /// Each commit's language and decision, for the bench's trace; nil in the keyboard.
    var onCommit: ((String, SupportedLanguage, BilingualCheck.Decision) -> Void)?

    init(pair: KeyboardLanguagePair, engines: [SupportedLanguage: TextPredictionEngine]) {
        precondition(engines[pair.primary] != nil && engines[pair.secondary] != nil, "an engine per language")
        self.pair = pair
        self.engines = engines
        window = LanguageWindow(pair: pair)
    }

    /// The language the next word is typed in: the bar's.
    var language: SupportedLanguage {
        lock.lock()
        defer { lock.unlock() }
        return window.language
    }

    /// The engine of the bar: completions, the correction preview, next-word predictions.
    var typingEngine: TextPredictionEngine { engine(language) }

    func engine(_ language: SupportedLanguage) -> TextPredictionEngine {
        // swiftlint:disable:next force_unwrapping
        engines[language]! // init checks an engine per language of the pair
    }

    /// What the space bar does with `word`: the word votes, the window moves, and both
    /// languages decide it. `context` is the document before the cursor.
    func commit(
        _ word: String,
        previousWord: String?,
        isAtSentenceStart: Bool,
        spatial: SpatialCorrection.Input?,
        context: String
    ) -> CorrectionProposal? {
        let vote = WordLanguageVote.vote(
            for: word, after: previousWord,
            primary: votingEvidence(pair.primary), secondary: votingEvidence(pair.secondary)
        )
        lock.lock()
        window.push(vote)
        let active = window.language
        lock.unlock()
        let query = Query(word: word, previousWord: previousWord, isAtSentenceStart: isAtSentenceStart,
                          spatial: spatial, context: context)
        let decision = decide(query, active: active, asksOther: true, logs: true)
        onCommit?(word, active, decision)
        return decision.proposal
    }

    /// The contraction the previous word was, now that `word` follows it, with `word`:
    /// `its a` is `it's a` (`contextualContraction(profile:word:before:)`). The space bar
    /// writes both words; nil leaves them. Either language of the pair may have the rule,
    /// whatever the window says: `its` is no French word. Never a learned word (ADR 0004).
    ///
    /// WHY on the bilingual keyboard: Pierre's device test of #1015 (2026-11-23) found that
    /// `its` never became `it's`. The English keyboard alone restores it at a sentence's
    /// start only (#995), and a French window keeps it as a word of English.
    func contractionAcrossSpace(previousWord: String, word: String) -> String? {
        guard !UserDictionary.shared.isLearned(previousWord.lowercased()) else { return nil }
        for language in [pair.primary, pair.secondary] {
            if let contraction = contextualContraction(profile: language.profile, word: previousWord, before: word) {
                return "\(contraction) \(word)"
            }
        }
        return nil
    }

    /// What the bar previews for the word being typed: the bar's language's correction,
    /// with the keep rules, without moving the window and without taps (the preview never
    /// had them).
    ///
    /// WHY without the other language's correction: a partial word is mostly unknown to
    /// the bar's language, so asking the partner on every letter doubled the letter p95 on
    /// the bench (0.80 to 1.74 ms, French run). The keep rules only read the partner's
    /// trie, which costs nothing measurable. The bar therefore does not preview a fix only
    /// the partner makes (`teh` -> `the` in French); the space bar still applies it.
    func preview(_ partial: String, previousWord: String?, isAtSentenceStart: Bool, context: String) -> CorrectionProposal? {
        let query = Query(word: partial, previousWord: previousWord, isAtSentenceStart: isAtSentenceStart,
                          spatial: nil, context: context)
        return decide(query, active: language, asksOther: false, logs: false).proposal
    }

    /// One word to decide, as an engine's `correctionProposal` takes it, and the document
    /// before the cursor.
    private struct Query {
        let word: String
        let previousWord: String?
        let isAtSentenceStart: Bool
        let spatial: SpatialCorrection.Input?
        let context: String
    }

    private func decide(_ query: Query, active: SupportedLanguage, asksOther: Bool, logs: Bool) -> BilingualCheck.Decision {
        let (word, previousWord, isAtSentenceStart, spatial) =
            (query.word, query.previousWord, query.isAtSentenceStart, query.spatial)
        let other = pair.other(than: active)
        let own = engine(active)
        guard let activeEvidence = evidence(active) else {
            let proposal = own.correctionProposal(for: word, previousWord: previousWord,
                                                  isAtSentenceStart: isAtSentenceStart, spatial: spatial,
                                                  context: query.context)
            return BilingualCheck.Decision(proposal: proposal, rule: .alone)
        }
        // A partner still loading, or one whose dictionary takes any letters, is none.
        let otherEvidence = evidence(other).flatMap { BilingualCheck.isWorking($0) ? $0 : nil }
        let decision = BilingualCheck.decide(
            word, before: query.context, active: activeEvidence, other: otherEvidence,
            own: { otherKnows in
                own.correctionProposal(for: word, previousWord: previousWord, isAtSentenceStart: isAtSentenceStart,
                                       spatial: spatial, otherLanguageKnowsWord: otherKnows, context: query.context)
            },
            theirs: {
                guard asksOther else { return nil }
                return self.engine(other).correctionProposal(for: word, previousWord: previousWord,
                                                             isAtSentenceStart: isAtSentenceStart, spatial: spatial,
                                                             context: query.context)
            }
        )
        #if DEBUG
        if logs, decision.rule != .active, decision.rule != .alone {
            AutocorrectDebugLog.autocorrectDecision(
                original: word, corrected: decision.proposal?.autocorrection?.correction ?? word,
                branch: "bilingual.\(decision.rule.rawValue).\(active.rawValue)", prevWord: previousWord
            )
        }
        #endif
        return decision
    }

    private func evidence(_ language: SupportedLanguage) -> TrieLanguageEvidence? {
        engine(language).languageEvidence.flatMap { $0.language == language ? $0 : nil }
    }

    /// A language's evidence for the vote: a dictionary still loading knows no word.
    private func votingEvidence(_ language: SupportedLanguage) -> any LanguageEvidenceSource {
        if let evidence = evidence(language) { return evidence }
        return NoEvidence(language: language)
    }
}

/// The answers of a dictionary not loaded yet: it knows no word.
private struct NoEvidence: LanguageEvidenceSource {
    let language: SupportedLanguage
    func logFrequency(of word: String) -> Double? { nil }
    func accentExpansion(_ word: String) -> String? { nil }
    func contractionExpansion(_ word: String) -> String? { nil }
    func correction(of word: String) -> String? { nil }
    func bigram(_ word: String, after previous: String) -> Double { 0 }
}
