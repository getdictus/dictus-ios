// DictusCore/Sources/DictusCore/LanguageDetection/WordLanguageVote.swift
// Scores one typed word against the two languages of a pair (#1009).
import Foundation

/// How much better the primary language explains a typed word than the secondary, in
/// nats: positive leans primary, negative secondary, near zero for a word both have
/// (`table`, `train`, `on`).
///
/// The parameters are the ones measured in #1007 (`docs/research/bilingual-keyboard/`),
/// where one-at-a-time changes moved monolingual typing by at most 2 words.
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

    public static func vote(
        for word: String,
        after previous: String?,
        primary: some LanguageEvidenceSource,
        secondary: some LanguageEvidenceSource
    ) -> Double {
        let difference = evidence(for: word, after: previous, in: primary)
            - evidence(for: word, after: previous, in: secondary)
        return min(clip, max(-clip, difference))
    }

    /// How well `source`'s language explains the typed word, in nats.
    static func evidence(for word: String, after previous: String?, in source: some LanguageEvidenceSource) -> Double {
        var typed = word.lowercased()
        var bonus = 0.0
        if let apostrophe = typed.lastIndex(of: "'") {
            let elision = String(typed[...apostrophe])
            typed = String(typed[typed.index(after: apostrophe)...])
            if source.language.profile.contractionPrefixes.contains(elision) { bonus += elisionBonus }
        }
        guard !typed.isEmpty else { return bonus }

        var target: String?
        var penalty = 0.0
        if source.logFrequency(of: typed) != nil {
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
            return unreachable + bonus
        }

        var score = frequency - penalty + bonus
        if let previous, case let context = lastSegment(of: previous), !context.isEmpty {
            score += bigramWeight * source.bigram(target, after: context)
        }
        return score
    }

    /// The lowercased word after its last apostrophe: the part the trie stores
    /// (`c'est` → `est`). A trailing apostrophe is ignored (`l'` → `l`).
    static func lastSegment(of word: String) -> String {
        word.lowercased().split(separator: "'").last.map(String.init) ?? ""
    }
}
