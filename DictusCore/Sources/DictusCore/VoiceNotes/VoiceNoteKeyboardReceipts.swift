// DictusCore/Sources/DictusCore/VoiceNotes/VoiceNoteKeyboardReceipts.swift
// Turning the keyboard's voice note receipts into "read" in History or the queue (#637, #639).
import Foundation

/// DictusApp's side of the keyboard receipts, as a value the tests drive.
///
/// The keyboard never writes History or the queue: a note shown in the reader or
/// inserted leaves a receipt in the delivery directory (#639 decision A), and this is
/// where a receipt becomes "read" — the same `markOpened` a card in the app performs.
/// A History-off note is then removed from the queue, which is what the result screen
/// does on close for a note it showed: the transcript has been delivered to a user
/// who chose not to keep transcripts. The delivery itself stays in the keyboard for
/// the rest of its window; only the receipt is spent.
///
/// Idempotent by construction, which is what lets every entry point and the live
/// keyboard signal call it without coordination: `markOpened` keeps the first date
/// in both stores, a queue note already removed is not found again, and a spent
/// receipt is gone. The island's `read` the caller performs for each returned id is
/// idempotent too.
@MainActor
public enum VoiceNoteKeyboardReceipts {

    /// Apply every receipt on disk, then drop it. Returns the receipts applied, so the
    /// caller can clear the island's segments and log them.
    @discardableResult
    public static func apply(from deliveries: VoiceNoteKeyboardDeliveryStore,
                             history: TranscriptionHistoryStore,
                             queue: VoiceNoteQueueStore) -> [VoiceNoteKeyboardAcknowledgement] {
        let receipts = deliveries.acknowledgements()
        for receipt in receipts {
            if history.record(id: receipt.id) != nil {
                history.markOpened(id: receipt.id, at: receipt.at)
            } else if let note = queue.queue.note(id: receipt.id), note.state == .done {
                queue.mutate {
                    $0.markOpened(receipt.id, at: receipt.at)
                    $0.remove(receipt.id)
                }
            }
            deliveries.clearAcknowledgement(receipt.id)
        }
        return receipts
    }
}
