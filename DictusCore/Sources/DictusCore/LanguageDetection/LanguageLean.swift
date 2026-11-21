// DictusCore/Sources/DictusCore/LanguageDetection/LanguageLean.swift
// Which language the last few words are in, to choose between two fixes (#1015).
//
// The rule is Hex's `languageLean` (github.com/anomalyco/hex, branch `dev`,
// `ios/HEXShared/FullKeyboard/AutocorrectEngine.swift`, MIT, Copyright (c) 2026
// Christopher Langton), on Dictus's tries instead of `UITextChecker`.
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

    /// Above zero the words before lean `other`, below zero `active`. `before` is the
    /// document before the word being decided; the word itself, if it ends `before`, is
    /// left out.
    public static func lean(
        before: String,
        word: String,
        active: some LanguageEvidenceSource,
        other: some LanguageEvidenceSource
    ) -> Int {
        let text = before.hasSuffix(word) ? String(before.dropLast(word.count)) : before
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
            }
        }
        return lean
    }
}
