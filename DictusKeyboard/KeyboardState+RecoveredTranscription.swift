// DictusKeyboard/KeyboardState+RecoveredTranscription.swift
// Clearing the waiting dictation text, and pasting it from the pill (#860, #881).

import DictusCore

/// The two actions on the waiting text that write the App Group first and then re-read
/// it, so they need no access to the `private(set)` offer. In their own file because
/// `KeyboardState.swift` is at the `file_length` budget.
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
}
