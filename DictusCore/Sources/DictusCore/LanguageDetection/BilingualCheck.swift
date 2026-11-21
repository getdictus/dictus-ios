// DictusCore/Sources/DictusCore/LanguageDetection/BilingualCheck.swift
// What the space bar writes on a bilingual keyboard: both languages checked together (#1015).
//
// The partner fallback, the tie-break by the words before, and the guard against a
// dictionary that takes any letters for a word come from Hex's `cautiousReplacement`
// (github.com/anomalyco/hex, branch `dev`, `ios/HEXShared/FullKeyboard/AutocorrectEngine.swift`,
// MIT, Copyright (c) 2026 Christopher Langton), and so does the rule that a word the
// other language knows stays as typed, with its two-letter exception. For a correction
// that only puts accents back, `BilingualKeepRule`, which compares frequencies, decides.
// Hex #2186 (dev `36197857`) adds the rule that the other language's guess of a name is
// never a fix, taken here, and the lean's count of the words both languages know
// (`LanguageLean`).
import Foundation

/// The bilingual check (#1015): the window's language corrects the word, and the other
/// language of the pair is asked when that correction may be wrong.
///
/// | Typed, French window | French alone | Rule | Written |
/// |---|---|---|---|
/// | `call` | `camp` | English `call` likelier than French `camp` (`BilingualKeepRule`) | `call` |
/// | `the` | `thé` | accents only; English `the` far likelier than French `thé` | `the` |
/// | `telephone` | `téléphone` | accents only; English `telephone` rarer than French `téléphone` | `téléphone` |
/// | `afraid`, after `I'm` | `aurais` | an English word after English words (Hex) | `afraid` |
/// | `teh` | nothing | English alone fixes it (Hex's fallback) | `the` |
/// | `wprk` | `porc` | both fix it; the words before are English (Hex's lean) | `work` |
///
/// WHY two keep rules. Hex keeps every word the other language knows. Measured on the
/// mixed bench of #1010 with both spatial decoders (study of 2026-11-21, section 7), that
/// cost 6 French words on the #954 run, all accents not put back because English knows
/// the bare spelling (`reserve`, `verifier`, `cinema`, `telephone`, `couches`, `arrive`).
/// Measured here, it also kept typos that are words of the other language inside a
/// sentence of the active one: `boue` for `hour`, `Ul` for `il`, `dont` for `don't`.
/// `BilingualKeepRule`, which compares frequencies, keeps none of those, but on Pierre's
/// device session it let a French window turn English `afraid` into common French `aurais`.
/// So the frequencies always decide, and Hex's rule is added where the words before are in
/// the other language: there, a word of that language is one the typist meant.
public enum BilingualCheck {

    /// How many nats likelier the other language must find the typed word than the active
    /// language finds a correction that only puts accents back, for the word to stay.
    ///
    /// WHY a margin for accents only: the accent rules decide from the previous word too
    /// (#994: `avons reserve` is `réservé`), which the frequencies alone do not see. On the
    /// #954 French run, English `reserve` (−6.48) outweighed French `réservé` (−7.67) and
    /// the accents were lost. `the`, 6 nats above French `thé`, stays.
    static let accentMargin = 2.0

    /// Which rule decided, for the debug log and the bench.
    public enum Rule: String, Equatable, Sendable {
        /// No working partner: the active language decides alone.
        case alone
        /// The active language's proposal stands.
        case active
        /// The typed word stays: the other language likes it at least as much as the
        /// active language likes its correction (`BilingualKeepRule`).
        case keptForOther
        /// The typed word stays: a word of the other language, after words of the other
        /// language, would become a different word (Hex).
        case keptOtherWord
        /// Only the other language fixes the word.
        case otherFixes
        /// Both fix it differently; the words before lean the other language.
        case otherByLean
    }

    public struct Decision: Equatable, Sendable {
        public var proposal: CorrectionProposal?
        public var rule: Rule

        public init(proposal: CorrectionProposal?, rule: Rule) {
            self.proposal = proposal
            self.rule = rule
        }
    }

    /// Decides `word`.
    ///
    /// - Parameters:
    ///   - before: the document before the cursor, for the lean.
    ///   - active: the window's language.
    ///   - other: the other language of the pair, or nil when it has no working
    ///     dictionary (`isWorking`).
    ///   - own: the active language's proposal. Its argument says whether the other
    ///     language knows the word as typed, which the spatial decoder treats as a known
    ///     word (Hex does the same): it then needs its larger margin to change it.
    ///   - theirs: the other language's proposal, asked only when the active language does
    ///     not know the word and either has no fix or the words before lean the other
    ///     language: it costs a second correction.
    ///
    /// WHY six parameters (`swiftlint:disable:this`): the word, the document, the two
    /// dictionaries and the two engines' answers, each engine asked only when needed. A
    /// struct around them would hide which one is lazy.
    public static func decide( // swiftlint:disable:this function_parameter_count
        _ word: String,
        before: String,
        active: some LanguageEvidenceSource,
        other: (any LanguageEvidenceSource)?,
        own: (_ otherKnowsWord: Bool) -> CorrectionProposal?,
        theirs: () -> CorrectionProposal?
    ) -> Decision {
        guard let other else { return Decision(proposal: own(false), rule: .alone) }
        let otherKnows = knows(word, in: other)
        let ownProposal = own(otherKnows)
        let activeKnows = knows(word, in: active)
        // One-letter words stay the active language's, as in Hex: "a" is a word in both.
        let mayAskOther = !activeKnows && word.count >= 2

        guard let fix = ownProposal?.autocorrection?.correction else {
            // The active language keeps the word. Its partner may still fix a typo the
            // active language cannot ("teh" in a French window), but never a word it has,
            // nor one the active language offered and found too unsure to write: French
            // offers `déclare` for `decalee` (meant `décalée`), English would write `declare`.
            guard mayAskOther, !otherKnows, let theirProposal = theirs(),
                  let theirFix = theirProposal.autocorrection?.correction,
                  !offers(ownProposal, theirFix), !isNameGuess(theirFix, for: word) else {
                return Decision(proposal: ownProposal, rule: .active)
            }
            return Decision(proposal: theirProposal, rule: .otherFixes)
        }
        let lean = LanguageLean.lean(before: before, word: word, active: active, other: other)
        // Hex's exception: a two-letter word is mostly an abbreviation or a slip in the other
        // dictionary, so the active language fixes it once the words before are in that
        // language ("fine for le" -> "fine for me").
        if otherKnows, word.count >= 2, !(word.count == 2 && lean < 0) {
            let accentsOnly = accentless(fix) == accentless(word)
            if frequencyKeeps(word, over: fix, active: active, other: other, accentsOnly: accentsOnly) {
                return Decision(proposal: nil, rule: .keptForOther)
            }
            if !accentsOnly, lean > 0, prefersOther(word, active: active, other: other) {
                return Decision(proposal: nil, rule: .keptOtherWord)
            }
        }
        // The lean first: it reads tries only, the partner's correction is a second engine.
        guard mayAskOther, lean > 0, let theirProposal = theirs(),
              let theirFix = theirProposal.autocorrection?.correction,
              theirFix.caseInsensitiveCompare(fix) != .orderedSame, !isNameGuess(theirFix, for: word) else {
            return Decision(proposal: ownProposal, rule: .active)
        }
        return Decision(proposal: theirProposal, rule: .otherByLean)
    }

    /// `BilingualKeepRule`, and the same comparison for a word the active language has
    /// too but rarely: English has `je` (−7.8), French near the top (−0.3), and the English
    /// window changed `Je` into `Be`.
    ///
    /// Not for accents put back on a word the active language has bare too: its accent
    /// rules chose between two of its own spellings from the previous word (`j'ai rate`
    /// is `raté`), which no frequency of the other language can overrule.
    private static func frequencyKeeps(
        _ word: String,
        over fix: String,
        active: some LanguageEvidenceSource,
        other: some LanguageEvidenceSource,
        accentsOnly: Bool
    ) -> Bool {
        let margin = accentsOnly ? accentMargin : 0
        if BilingualKeepRule.keepsTyped(word, over: fix, active: active, other: other, margin: margin) { return true }
        guard !accentsOnly else { return false }
        let typed = WordLanguageVote.lastSegment(of: word)
        guard let inActive = active.logFrequency(of: typed), let inOther = other.logFrequency(of: typed),
              let fixInActive = active.logFrequency(of: WordLanguageVote.lastSegment(of: fix)) else { return false }
        return inOther > inActive && inOther >= fixInActive
    }

    /// Whether the typed word is more the other language's than the active one's: the
    /// active language lacks it, or has it less often. WHY not every word the other
    /// language knows, as Hex: the English trie, built from Google Books, holds French
    /// words (`fait`, `trop`, `je`, −7.8 to −10.6), which would freeze French corrections
    /// of them; Hex's `UITextChecker` dictionaries do not.
    private static func prefersOther(
        _ word: String,
        active: some LanguageEvidenceSource,
        other: some LanguageEvidenceSource
    ) -> Bool {
        let typed = WordLanguageVote.lastSegment(of: word)
        guard let inActive = active.logFrequency(of: typed) else { return true }
        guard let inOther = other.logFrequency(of: typed) else { return true }
        return inOther > inActive
    }

    /// Whether the other language's fix is a name it guessed: a capital the typist did not
    /// type. Hex #2186: "Ziri" became the partner's "Zuri". A name of the active language
    /// is its own engine's to write (the lexicon, #873); the other one's is never a fix.
    private static func isNameGuess(_ fix: String, for word: String) -> Bool {
        guard let fixFirst = fix.first, let typedFirst = word.first else { return false }
        return fixFirst.isUppercase && !typedFirst.isUppercase
    }

    /// Whether `proposal` offers `word` in the bar, accents and case aside.
    private static func offers(_ proposal: CorrectionProposal?, _ word: String) -> Bool {
        guard case let .suggest(words)? = proposal else { return false }
        let target = accentless(word)
        return words.contains { accentless($0) == target }
    }

    /// `word` lowercased, without its accents. Apostrophes stay: `s'hé` is not `she`.
    static func accentless(_ word: String) -> String {
        word.lowercased().folding(options: .diacriticInsensitive, locale: nil)
    }

    /// Whether `source`'s dictionary has `word` as typed: the word itself, or an elision
    /// of the language (`j'aime`) followed by a word it has.
    public static func knows(_ word: String, in source: some LanguageEvidenceSource) -> Bool {
        let lowered = word.lowercased()
        if source.logFrequency(of: lowered) != nil { return true }
        guard let apostrophe = lowered.lastIndex(of: "'") else { return false }
        let elision = String(lowered[...apostrophe])
        guard source.language.profile.contractionPrefixes.contains(elision) else { return false }
        let rest = String(lowered[lowered.index(after: apostrophe)...])
        return rest.isEmpty || source.logFrequency(of: rest) != nil
    }

    /// Whether `source` can be a partner: a dictionary that takes any letters for a word
    /// would keep every typo as "a word of the other language". Hex met one (the iOS 27.2
    /// simulator's `pl_PL`) and checks the same nonsense word.
    public static func isWorking(_ source: some LanguageEvidenceSource) -> Bool {
        source.logFrequency(of: "qzxjvkq") == nil
    }
}
