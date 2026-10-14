// DictusCore/Sources/DictusCore/Vocabulary/ObservedVariant.swift
// Text selected in a history entry, turned into a variant the add sheet can prefill (#723).
import Foundation

/// What a selection in a saved transcript becomes when the user picks
/// **Add to Vocabulary** on it (#723).
///
/// The selection is the evidence: it is what the engine actually wrote, so it goes in
/// the entry's variants, and the user types the correct spelling as the term. That
/// pairing is the one #512 will read later, and it needs no field of its own — the
/// variant list already says "the engine writes this, the user means that".
///
/// ### Why the selection is cleaned rather than taken as is
///
/// `VocabularyReplacer` matches a variant character for character, between word
/// boundaries. A span dragged one character too far carries a comma or a full stop,
/// and a variant `cloud code,` only ever matches where the engine writes that comma
/// too — which is to say it silently matches almost nothing. Sentence punctuation and
/// quotes at either end are therefore dropped. Punctuation **inside** the span is kept:
/// `l'ampli` and `Node.js` are spellings, not sentence marks.
///
/// A span across a line break is joined with one space, since the transcript the
/// replacer reads next time will not break at the same place.
public enum ObservedVariant {

    /// Characters dropped from either end of a selection, after whitespace.
    ///
    /// Sentence marks, quotes and brackets: what a selection picks up from the text
    /// around a word. Not `#`, `+`, `@` or `&`, which end real spellings (`C#`, `C++`).
    static let surroundingMarks = CharacterSet(charactersIn: ".,;:!?…\"'«»“”‘’()[]{}")

    /// The variant a selection stands for, or nil when there is nothing usable in it.
    ///
    /// Nil for an empty or whitespace-only selection, and for one longer than
    /// `VocabularyEntry.maxFieldLength` once cleaned — `VocabularyEntry` would drop it,
    /// and an action that opens a sheet with nothing in it is worse than no action.
    public static func from(selection: String) -> String? {
        let trimmed = selection.trimmingCharacters(in: surroundingMarks.union(.whitespacesAndNewlines))
        let joined = trimmed
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        guard !joined.isEmpty, joined.count <= VocabularyEntry.maxFieldLength else { return nil }
        return joined
    }
}
