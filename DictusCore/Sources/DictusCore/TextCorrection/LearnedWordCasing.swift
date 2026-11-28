// DictusCore/Sources/DictusCore/TextCorrection/LearnedWordCasing.swift
// How a learned word is written, from the forms the user typed it in (#1090).
import Foundation

/// The casing `UserDictionary` keeps beside a learned word, so that swipe typing, which
/// has no typed letters to copy a capital from, writes « Apple » or « WisprFlow » the way
/// the user does, mid-sentence too.
///
/// WHY a rule and not "the last form typed": the keyboard capitalises the first word of a
/// sentence on its own, so a capital first letter says nothing on its own: « Zorglub » at
/// the start of a sentence may be « zorglub » anywhere else. What the store sees is the
/// word alone, without its place in the sentence, so each form counts for what it proves:
/// - **A capital after the first letter** (« WisprFlow », « iPhone », « SNCF ») is never the
///   keyboard's: the user wrote it so. It replaces whatever was kept.
/// - **All lowercase** is never the keyboard's either, where it capitalises: the user wrote
///   the word without a capital, which outweighs a capital first letter seen elsewhere.
/// - **A capital first letter only** (« Apple ») may be the sentence's. It is kept only when
///   nothing better is known: a word typed « apple » once keeps its lowercase.
///
/// So a word the user only ever typed at the start of a sentence keeps its capital: one
/// typed there and mid-sentence takes the mid-sentence form.
public enum LearnedWordCasing {

    /// The form to keep for a word, given the one kept so far (nil when none) and the one
    /// just typed. Nil when `typed` says nothing a store could keep (empty).
    public static func merged(kept: String?, typed: String) -> String? {
        guard !typed.isEmpty else { return kept }
        // A kept form of another word cannot be compared: start from what was typed.
        let kept = kept.flatMap { $0.lowercased() == typed.lowercased() ? $0 : nil }
        if hasInnerCapital(typed) || typed == typed.lowercased() { return typed }
        // A capital first letter only: the sentence's, as far as anyone can tell.
        return kept ?? typed
    }

    /// Whether `word` has a capital after its first letter (« WisprFlow », « iPhone »).
    public static func hasInnerCapital(_ word: String) -> Bool {
        word.dropFirst().contains(where: \.isUppercase)
    }
}
