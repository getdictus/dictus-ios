// DictusCore/Sources/DictusCore/LanguageDetection/LanguageLean.swift
// Which language the last few words are in, to choose between two fixes (#1015).
//
// The rule is Hex's `languageLean` (github.com/anomalyco/hex, branch `dev`,
// `ios/HEXShared/FullKeyboard/AutocorrectEngine.swift`, MIT, Copyright (c) 2026
// Christopher Langton), on Dictus's tries instead of `UITextChecker`, with #2186's count
// of the words both languages know (dev `36197857`).
import Foundation

/// Counts the last four words before the cursor that only one language of the pair knows:
/// +1 for each the other language alone knows, −1 for each the active language alone
/// knows. Words both know, or neither, count for nothing, and so do one-letter words.
///
/// WHY next to `LanguageWindow` and not instead of it: the window decays over many words
/// and flips only past a threshold, so for the two words after a change of language it
/// still names the old one (#1010 measured 1.2 and 2.1 words of lag). The lean has no
/// state and no decay: it only breaks a tie when both languages fix a typo, and four
/// words are enough to see that the sentence has changed language.
public enum LanguageLean {

    /// How many words before the cursor are read. Hex's value.
    static let words = 4

    /// How many nats likelier one language must find a word both have, for it to count.
    static let commonGap = 3.0

    /// A word both languages have counts for the one that has it far more often (#2186 in
    /// Hex: the French and German dictionaries take `the`, `you`, `not`, so English
    /// sentences never leaned English). +1 for the other language, −1 for the active one.
    ///
    /// WHY a gap in nats and not Hex's "among the commonest 2,000 of one typing model":
    /// both tries carry frequencies on one scale (`TrieFrequencyScale`), and the English
    /// one, built from books, has French function words a little (`le` −6.1, `est` −6.0,
    /// against −0.7 and −0.6 in French). Hex leaves out two-letter words for that reason;
    /// the gap counts them for French, where they belong.
    private static func commonSide(
        _ word: String,
        active: some LanguageEvidenceSource,
        other: some LanguageEvidenceSource
    ) -> Int? {
        let typed = WordLanguageVote.lastSegment(of: word)
        guard let inActive = active.logFrequency(of: typed), let inOther = other.logFrequency(of: typed) else {
            return nil
        }
        if inOther >= inActive + commonGap { return 1 }
        if inActive >= inOther + commonGap { return -1 }
        return nil
    }

    /// Above zero the words before lean `other`, below zero `active`. `before` is the
    /// document before the word being decided; the word itself, if it ends `before`, is
    /// left out, and so is everything before the sentence it is in (`sentence(before:)`).
    public static func lean(
        before: String,
        word: String,
        active: some LanguageEvidenceSource,
        other: some LanguageEvidenceSource
    ) -> Int {
        let text = sentence(before: before.hasSuffix(word) ? String(before.dropLast(word.count)) : before)
        let recent = text.split(whereSeparator: { !$0.isLetter && $0 != "'" }).suffix(words)
        var lean = 0
        for token in recent where token.count >= 2 {
            let word = String(token)
            let mine = BilingualCheck.knows(word, in: active)
            let theirs = BilingualCheck.knows(word, in: other)
            if theirs && !mine {
                lean += 1
            } else if mine && !theirs {
                lean -= 1
            } else if mine, let side = commonSide(word, active: active, other: other) {
                lean += side
            }
        }
        return lean
    }

    /// The part of `text` after its last full stop, question or exclamation mark, or line
    /// break: the sentence being typed.
    ///
    /// WHY (unlike Hex, which reads the last 120 characters): the words of another sentence
    /// say what language that one was in. On Pierre's device session of 2026-11-23, `Oji`
    /// began a paragraph and became English's `Oki` instead of French's `Oui`, because
    /// `Navigate`, two lines above, leaned the lean English.
    static func sentence(before text: String) -> Substring {
        guard let end = text.lastIndex(where: { ".!?\n\r\u{2026}".contains($0) }) else { return text[...] }
        return text[text.index(after: end)...]
    }
}
