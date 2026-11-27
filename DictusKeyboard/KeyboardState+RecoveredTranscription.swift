// DictusKeyboard/KeyboardState+RecoveredTranscription.swift
// Clearing the waiting dictation text, and pasting it from the pill (#860, #881).

import Foundation
import DictusCore

/// The actions on the waiting text that write the App Group first and then re-read it, so
/// they need no access to the `private(set)` offer, and the pill's expiry timer. In their
/// own file because `KeyboardState.swift` is at the `file_length` budget.
extension KeyboardState {

    /// A new dictation is the user moving on: the banner describes the previous one.
    /// DictusApp clears it too, in `startDictation`, for dictations started in the app.
    func clearRecoveredTranscriptionForNewDictation() {
        guard recoveredTranscriptionOffer != .none || RecoveredTranscriptionChannel.current() != nil else { return }
        RecoveredTranscriptionChannel.clear()
        refreshRecoveredTranscription()
        logProbe("recoveredTranscriptionCleared", details: "reason=new-dictation")
    }

    /// The paste pill was tapped (#881): type the text into this field.
    ///
    /// Through `insertDictation`, so the undo arms exactly as after a dictation. The
    /// channel is cleared first, for the reason the hand-off clears its key before typing:
    /// a second tap delivered before the redraw must find nothing. Past its window the tap
    /// types nothing and the pill goes; DictusApp's card still holds the text.
    func pasteRecoveredTranscription() {
        guard let text = RecoveredTranscriptionChannel.pasteable() else {
            logProbe("recoveredTranscriptionPasted", details: "outcome=expired")
            refreshRecoveredTranscription()
            return
        }
        RecoveredTranscriptionChannel.clear()
        refreshRecoveredTranscription()
        logProbe("recoveredTranscriptionPasted", details: "outcome=inserted chars=\(text.count)")
        insertDictation(text)
    }

    /// The one re-read queued for the pill's expiry. Static because `KeyboardState` is a
    /// single shared instance and an extension cannot hold an instance property.
    private static var recoveredTranscriptionExpiry: DispatchWorkItem?

    /// Queue a re-read of the pill `remaining` seconds from now, replacing any queued one;
    /// nil cancels it.
    func scheduleRecoveredTranscriptionExpiry(in remaining: TimeInterval?) {
        Self.recoveredTranscriptionExpiry?.cancel()
        Self.recoveredTranscriptionExpiry = nil
        guard let remaining else { return }
        let reread = DispatchWorkItem { [weak self] in self?.refreshRecoveredTranscription() }
        Self.recoveredTranscriptionExpiry = reread
        DispatchQueue.main.asyncAfter(deadline: .now() + max(remaining, 0) + 0.1, execute: reread)
    }
}
