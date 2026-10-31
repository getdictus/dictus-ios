// DictusCore/Sources/DictusCore/RecoveredTranscriptionChannel.swift
// A dictation whose text was produced but never typed, waiting for the user (#860).

import Foundation

/// The text of the last keyboard dictation the document refused, kept until the user
/// either opens it in DictusApp or starts another dictation.
///
/// WHY THIS EXISTS: an interrupted dictation (a call, another app taking the mic) is
/// transcribed when DictusApp comes back to the foreground, and by then the keyboard
/// is no longer in front of the field — `polishInsertionRefused reason=off-screen`.
/// The refusal is correct, and since #495 the text reaches the app's "Last
/// transcription" card. But nothing told the user it was there, and the keyboard had
/// already dropped its own short message (`reconciled-timeout`). This is the state the
/// keyboard's persistent banner is drawn from.
///
/// WHY ITS OWN KEY AND NOT `PolishedTextChannel`: that pair is the answer to one
/// hand-off, and the app clears it as it hands the next one over and in its launch
/// sweep. The banner has to outlive both — it stays until the user acts — and the
/// card behind it is `DictationCoordinator.lastResult`, which lives only in memory, so
/// an app relaunched since the dictation has nothing else to show.
///
/// The text is stored rather than a flag pointing at another key for the same reason:
/// the only other copies are in memory or in the Pro-only history.
public enum RecoveredTranscriptionChannel {

    /// Record how a dictation ended. Only a refusal creates the pending state: an
    /// insertion put the text where the user wanted it, and `.nothing` carries no text
    /// (the raw DictusApp holds is that dictation's whole story, told by its own error).
    public static func note(_ ending: PolishedTextChannel.Ending, in defaults: UserDefaults = AppGroup.defaults) {
        guard case .refused(let text) = ending, !text.isEmpty else { return }
        defaults.set(text, forKey: SharedKeys.recoveredTranscription)
        defaults.synchronize()
    }

    /// The text waiting for the user, or nil when there is none.
    public static func current(in defaults: UserDefaults = AppGroup.defaults) -> String? {
        defaults.string(forKey: SharedKeys.recoveredTranscription)
    }

    /// Drop the pending text. Called when a dictation starts: the banner describes the
    /// previous one, and a new dictation is the user moving on.
    public static func clear(in defaults: UserDefaults = AppGroup.defaults) {
        defaults.removeObject(forKey: SharedKeys.recoveredTranscription)
        defaults.synchronize()
    }

    /// Read the pending text and drop it. Called by DictusApp when the banner opens it:
    /// from then on the card holds it, and the banner has done its job.
    public static func take(in defaults: UserDefaults = AppGroup.defaults) -> String? {
        let text = current(in: defaults)
        if text != nil { clear(in: defaults) }
        return text
    }
}
