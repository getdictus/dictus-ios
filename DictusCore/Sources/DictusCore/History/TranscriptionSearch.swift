// DictusCore/Sources/DictusCore/History/TranscriptionSearch.swift
// The rule the History screen's search field applies to the saved transcriptions.
import Foundation

/// Which saved transcriptions a search query finds (#621).
///
/// WHY the rule lives here and not in `HistoryView`: what counts as a match is a
/// product decision with test cases attached (`ecole` must find `école`), and the
/// app target has no test bundle. The view only owns the field and the list.
///
/// WHY a linear filter and no index: the store caps the history at a few hundred
/// short records held in memory (#453 allows at most 1000), so scanning them on
/// every keystroke costs less than keeping an index in step with every append,
/// edit and delete.
public enum TranscriptionSearch {

    /// Case- and diacritic-insensitive, so `ecole` and `Ecole` both find `école`
    /// and `école` finds a transcript that lost its accents.
    private static let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]

    /// Whether `record` is found by `query`.
    ///
    /// Only the text is searched. The language and the engine are not search terms
    /// (#621 v1): a query of `fr` finding every French dictation would bury the
    /// one transcript that contains the letters. A voice note's summary is not
    /// searched either, because it is not what the card shows.
    ///
    /// A query that is empty once trimmed matches everything, which is what makes
    /// clearing the field restore the whole list.
    public static func matches(_ record: TranscriptionRecord, query: String) -> Bool {
        let needle = normalized(query)
        guard !needle.isEmpty else { return true }
        return record.text.range(of: needle, options: options) != nil
    }

    /// The records `query` finds, in the order they were given (newest first, as
    /// the store keeps them).
    public static func filter(_ records: [TranscriptionRecord], query: String) -> [TranscriptionRecord] {
        let needle = normalized(query)
        guard !needle.isEmpty else { return records }
        return records.filter { $0.text.range(of: needle, options: options) != nil }
    }

    /// Leading and trailing whitespace is never meant: the keyboard adds a space
    /// after an autocompleted word, and that space must not hide a match at the
    /// end of a transcript.
    private static func normalized(_ query: String) -> String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
