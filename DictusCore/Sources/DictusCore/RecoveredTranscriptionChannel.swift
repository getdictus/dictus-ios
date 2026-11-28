// DictusCore/Sources/DictusCore/RecoveredTranscriptionChannel.swift
// A dictation whose text was produced but never typed, waiting for the user (#860).

import Foundation

/// The text of the last keyboard dictation the document refused, kept until the user
/// opens it in DictusApp, pastes it from the keyboard's pill (#881), or starts another
/// dictation.
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
    ///
    /// The time is stored beside the text: the paste pill (#881) offers it for
    /// `pasteWindow` from that moment.
    public static func note(_ ending: PolishedTextChannel.Ending,
                            in defaults: UserDefaults = AppGroup.defaults,
                            now: Date = Date()) {
        guard case .refused(let text) = ending, !text.isEmpty else { return }
        defaults.set(text, forKey: SharedKeys.recoveredTranscription)
        defaults.set(now.timeIntervalSince1970, forKey: SharedKeys.recoveredTranscriptionStoredAt)
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
        defaults.removeObject(forKey: SharedKeys.recoveredTranscriptionStoredAt)
        defaults.synchronize()
    }

    /// Read the pending text and drop it. Called by DictusApp when the banner opens it:
    /// from then on the card holds it, and the banner has done its job.
    public static func take(in defaults: UserDefaults = AppGroup.defaults) -> String? {
        let text = current(in: defaults)
        if text != nil { clear(in: defaults) }
        return text
    }

    // MARK: - The paste pill (#881)

    /// How long the keyboard offers to paste the text. Hex's figure, and a choice rather
    /// than a measurement: long enough for a short call, short enough that the text does
    /// not follow the user into an unrelated app for the rest of the day. Past it the text
    /// stays in the channel, and DictusApp's "Last transcription" card still shows it.
    public static let pasteWindow: TimeInterval = 600

    /// The text the pill may paste, or nil when there is none or it is older than
    /// `pasteWindow`. A text with no stored time predates the pill and is never offered.
    public static func pasteable(in defaults: UserDefaults = AppGroup.defaults, now: Date = Date()) -> String? {
        guard let remaining = remainingPasteTime(in: defaults, now: now), remaining > 0 else { return nil }
        return current(in: defaults)
    }

    /// Seconds until the pill expires, nil when no text with a stored time is waiting.
    /// Negative once it has expired.
    public static func remainingPasteTime(in defaults: UserDefaults = AppGroup.defaults,
                                          now: Date = Date()) -> TimeInterval? {
        guard current(in: defaults) != nil,
              let storedAt = defaults.object(forKey: SharedKeys.recoveredTranscriptionStoredAt) as? Double
        else { return nil }
        return storedAt + pasteWindow - now.timeIntervalSince1970
    }

    /// What the keyboard's centre slot offers for the waiting text.
    ///
    /// - Parameter pastes: `KeyboardFeatureSettings.isPasteTranscriptionEffective`. Off,
    ///   the #860 banner as it always was: no time limit, a tap opens the app.
    public static func offer(in defaults: UserDefaults = AppGroup.defaults,
                             pastes: Bool,
                             now: Date = Date()) -> RecoveredTranscriptionOffer {
        if pastes {
            return pasteable(in: defaults, now: now) == nil ? .none : .paste
        }
        return current(in: defaults) == nil ? .none : .openInApp
    }
}

/// What the keyboard shows for a dictation it could not type.
public enum RecoveredTranscriptionOffer: Equatable, Sendable {
    /// Nothing is waiting, or the paste window has passed.
    case none
    /// "Dictation interrupted. Your text is in the Dictus app." (#860).
    case openInApp
    /// "Paste transcription" (#881): a tap types the text into the current field.
    case paste
}
