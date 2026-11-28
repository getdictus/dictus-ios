// DictusCore/Sources/DictusCore/LanguageDetection/BilingualKeepRule.swift
// Keeps a typed word the other language of the pair likes better (#1009).
import Foundation

/// Whether a typed word stays as typed instead of taking the active language's correction.
///
/// The window decides which dictionary corrects a word, so one English word in a French
/// sentence is still checked by the French dictionary, which alone turns `call` into
/// `camp`. The word stays as typed when the active language does not have it, the other
/// language does, and the other language finds it at least as likely as the active
/// language finds its own correction, both in nats below their top word:
///
/// | Typed | Active | Its correction | Result |
/// |---|---|---|---|
/// | `call` | French | `camp` | stays: `call` is common English |
/// | `the` | French | `thé` | stays: `the` is English's top word |
/// | `telephone` | French | `téléphone` | corrected: English `telephone` is rarer than French `téléphone` |
///
/// Measured in #1007: without this rule the mixed run leaves 21 wrong words, with it 10.
public enum BilingualKeepRule {

    /// `margin`: how many nats more likely the other language must find the typed word
    /// than the active language finds its correction. 0 in #1010; the bilingual check
    /// (#1015) asks for more when the correction only puts accents back.
    public static func keepsTyped(
        _ word: String,
        over correction: String,
        active: some LanguageEvidenceSource,
        other: some LanguageEvidenceSource,
        margin: Double = 0
    ) -> Bool {
        let typed = WordLanguageVote.lastSegment(of: word)
        let corrected = WordLanguageVote.lastSegment(of: correction)
        guard active.logFrequency(of: typed) == nil,
              let typedInOther = other.logFrequency(of: typed),
              let correctedInActive = active.logFrequency(of: corrected) else { return false }
        return typedInOther >= correctedInActive + margin
    }
}
