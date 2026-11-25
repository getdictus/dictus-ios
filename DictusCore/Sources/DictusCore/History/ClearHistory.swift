// DictusCore/Sources/DictusCore/History/ClearHistory.swift
// What Settings' "Clear history" deletes (#906): the history and the polish journal.
import Foundation

/// The two stores on the device that hold what the user dictated, and the one call
/// that empties both.
///
/// WHY both: the confirmation promises that every transcription saved on this
/// device will be deleted. The history is one such store. The polish journal
/// (`PolishEventStore`) is the other: since #747 it keeps the raw, vocabulary-
/// corrected and polished text of every dictation for seven days, Pro or not.
/// Emptying only the history left that sentence false.
@MainActor
public enum ClearHistory {

    /// Whether the row has anything to delete. It stays available while either
    /// store holds something, so a user with no history but a journal (anyone
    /// without Dictus Pro who dictated this week) still has a visible way to clear it.
    public static func hasSomethingToDelete(history: TranscriptionHistoryStore,
                                            journalURL: URL? = PolishEventStore.fileURL) -> Bool {
        guard history.isEmpty else { return true }
        guard let journalURL else { return false }
        return PolishEventStore.hasEntries(at: journalURL)
    }

    /// Empty the history and the polish journal.
    public static func run(history: TranscriptionHistoryStore,
                           journalURL: URL? = PolishEventStore.fileURL) {
        history.clear()
        if let journalURL {
            PolishEventStore.clear(at: journalURL)
        }
    }
}
