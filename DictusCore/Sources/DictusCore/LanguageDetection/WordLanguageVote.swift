// DictusCore/Sources/DictusCore/LanguageDetection/WordLanguageVote.swift
// Scores one typed word against the two languages of a pair (#1009).
import Foundation

/// How much better the primary language explains a typed word than the secondary, in
/// nats: positive leans primary, negative secondary, near zero for a word both have
/// (`table`, `train`, `on`).
///
/// The parameters are the ones measured in #1007 (`docs/research/bilingual-keyboard/`),
/// where one-at-a-time changes moved monolingual typing by at most 2 words.
///
/// Rare words both languages reach vote at most `weakClip` (`isWeak`): a word the primary
/// language has as typed, when the secondary has it more often but still rarely, and a typo
/// both languages only reach by correcting it, into a word the leading one rarely uses.
public enum WordLanguageVote {

    /// One word cannot outvote the window on its own: an English loanword in a French
    /// sentence votes at most this much.
    static let clip = 4.0
    /// A word the language reaches only by correcting it is weaker evidence than one it has.
    static let typoPenalty = 3.0
    /// A word the language cannot even correct.
    static let unreachable = -16.0
    /// Weight of the bigram score of the word after the previous one.
    static let bigramWeight = 2.0
    /// An elision (`c'`, `j'`, `qu'`...) or a contraction the language expands.
    static let elisionBonus = 3.0
    /// The vote of weak evidence (`isWeak`): near zero, as for any word both languages have.
    static let weakClip = 1.0
    /// The log-frequency from which a word is common in its language: about its 1,000
    /// commonest words on `TrieFrequencyScale` (French `demain` −4.46, `juste` −4.07,
    /// English `call` −4.75; English `navigate` −7.30 and French `lainage` −10.56 are rare).
    static let commonFloor = -5.0

    public static func vote(
        for word: String,
        after previous: String?,
        primary: some LanguageEvidenceSource,
        secondary: some LanguageEvidenceSource
    ) -> Double {
        let inPrimary = reading(of: word, after: previous, in: primary)
        let inSecondary = reading(of: word, after: previous, in: secondary)
        let difference = inPrimary.score - inSecondary.score
        let bound = isWeak(difference, primary: inPrimary, secondary: inSecondary) ? weakClip : clip
        return min(bound, max(-bound, difference))
    }

    /// Whether the word says little about the language, so that it votes near zero.
    ///
    /// - A word the primary language has as typed, which the secondary explains better but
    ///   has only as a rare word: the tries come from different corpora (subtitles, books),
    ///   so the frequencies of a rare word both have do not compare across them, and the
    ///   primary is the language the typist chose. On Pierre's device session of 2026-11-23,
    ///   a French keyboard just launched read `Test bug` as English (−2.05 and −4.00: French
    ///   has both words, at −7.06 and −11.09, English at −5.01 and −6.37) and the window
    ///   flipped. A common word of the secondary keeps its vote (`us` −2.94, `for` −1.36,
    ///   which French books have rarely), and so does any word toward the primary: `projet`,
    ///   which English books have at −10.44, is French.
    /// - A typo both languages only reach by correcting it, into a word the leading
    ///   language rarely uses: `Jaihate` voted −3.26 for English's `navigate` against
    ///   French's `lainage`, both rare, and kept the window English, so the French decoder
    ///   never read `J'ai hâte`. A common correction keeps its vote (`Oji`, French `oui`),
    ///   and so does an elision of the leading language (`j'aihate`).
    static func isWeak(_ difference: Double, primary: Reading, secondary: Reading) -> Bool {
        let leading = difference >= 0 ? primary : secondary
        if difference < 0, primary.hasAsTyped, let frequency = secondary.targetFrequency, frequency < commonFloor {
            return true
        }
        guard primary.corrected, secondary.corrected, !leading.elided,
              let frequency = leading.targetFrequency else { return false }
        return frequency < commonFloor
    }

    /// How well `source`'s language explains the typed word, in nats.
    static func evidence(for word: String, after previous: String?, in source: some LanguageEvidenceSource) -> Double {
        reading(of: word, after: previous, in: source).score
    }

    /// One language's reading of a typed word: its score, the word it reads it as, and how.
    struct Reading {
        /// How well the language explains the typed word, in nats.
        var score: Double
        /// The log-frequency of the word it reads, or nil when it reaches none.
        var targetFrequency: Double?
        /// Whether an elision or contraction of the language counted.
        var elided = false
        /// The language has the word as typed (after an elision).
        var hasAsTyped = false
        /// The language reaches the word only by correcting it.
        var corrected = false
    }

    static func reading(of word: String, after previous: String?, in source: some LanguageEvidenceSource) -> Reading {
        var typed = word.lowercased()
        var bonus = 0.0
        if let apostrophe = typed.lastIndex(of: "'") {
            let elision = String(typed[...apostrophe])
            typed = String(typed[typed.index(after: apostrophe)...])
            if source.language.profile.contractionPrefixes.contains(elision) { bonus += elisionBonus }
        }
        guard !typed.isEmpty else { return Reading(score: bonus, targetFrequency: nil, elided: bonus > 0) }
        let hasAsTyped = source.logFrequency(of: typed) != nil

        var target: String?
        var penalty = 0.0
        if hasAsTyped {
            target = typed
        } else if let accented = source.accentExpansion(typed) {
            target = accented
        } else if let contraction = source.contractionExpansion(typed) {
            target = lastSegment(of: contraction)
            bonus += elisionBonus
        } else if let correction = source.correction(of: typed) {
            target = lastSegment(of: correction)
            penalty = typoPenalty
        }
        guard let target, !target.isEmpty, let frequency = source.logFrequency(of: target) else {
            return Reading(score: unreachable + bonus, targetFrequency: nil, elided: bonus > 0)
        }

        var score = frequency - penalty + bonus
        if let previous, case let context = lastSegment(of: previous), !context.isEmpty {
            score += bigramWeight * source.bigram(target, after: context)
        }
        return Reading(score: score, targetFrequency: frequency, elided: bonus > 0, hasAsTyped: hasAsTyped,
                       corrected: penalty > 0)
    }

    /// The lowercased word after its last apostrophe: the part the trie stores
    /// (`c'est` → `est`). A trailing apostrophe is ignored (`l'` → `l`).
    static func lastSegment(of word: String) -> String {
        word.lowercased().split(separator: "'").last.map(String.init) ?? ""
    }
}
