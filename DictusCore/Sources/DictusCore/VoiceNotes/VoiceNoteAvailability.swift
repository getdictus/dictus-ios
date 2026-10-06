// DictusCore/Sources/DictusCore/VoiceNotes/VoiceNoteAvailability.swift
// Who may transcribe a shared voice note, and what the others are told (#620).
import Foundation

/// The Pro gate for shared voice notes, as pure functions.
///
/// ### The rules, from #593
///
/// - **Taking a new note is Pro.** The share extension refuses one without the
///   entitlement, and the app does not start transcribing a waiting one.
/// - **Nothing already produced is locked away.** A transcript in the voice note list
///   stays readable, copyable and deletable after the trial or subscription ends, and
///   so does a note still waiting — the user can always delete it. Results saved to
///   the history follow the history's own rule, which is the same: kept, and
///   deletable from Settings.
///
/// Same shape as `HistoryAvailability`, and for its reason: an entitlement answered
/// inline in the view that needs it is one the next surface answers differently.
public enum VoiceNoteAvailability {

    /// Pro is active and the feature's switch is on.
    public static var isEntitled: Bool {
        FeatureGate.isAvailable(.voiceNotes)
    }

    /// What the share extension does with a note.
    public enum ShareDecision: Equatable, Sendable {
        /// Take it.
        case accept
        /// Refuse, and say it is part of Dictus Pro (paywall reachable).
        case refuseNeedsPro
        /// Refuse a Pro user who switched voice notes off in the Dictus Pro hub
        /// (#216), and say so. "Part of Dictus Pro" would be false to someone who has
        /// it, and the switch is where they turn it back on.
        case refuseSwitchedOff
        /// Refuse without naming a subscription: while #236's flag is down the app
        /// must not look like it has one, and the extension is part of the app.
        case refuseUnavailable
    }

    public static func shareDecision(isEntitled: Bool, paywallVisible: Bool) -> ShareDecision {
        if isEntitled { return .accept }
        return paywallVisible ? .refuseNeedsPro : .refuseUnavailable
    }

    /// What the share extension does, telling a switched-off Pro user apart from
    /// someone without Pro (#216).
    ///
    /// - Parameter hasPro: `FeatureGate.isProActive`, the entitlement without the
    ///   feature's switch.
    public static func shareDecision(isEntitled: Bool, hasPro: Bool, paywallVisible: Bool) -> ShareDecision {
        if !isEntitled && hasPro { return .refuseSwitchedOff }
        return shareDecision(isEntitled: isEntitled, paywallVisible: paywallVisible)
    }

    /// The live answer for this process.
    public static var shareDecision: ShareDecision {
        shareDecision(isEntitled: isEntitled, hasPro: FeatureGate.isProActive,
                      paywallVisible: PremiumFlags.paywallVisible)
    }

    /// Whether the app may start transcribing a waiting note. Checked before each
    /// note, not once per queue: an entitlement can lapse while the app lives.
    public static func mayTranscribe(isEntitled: Bool) -> Bool {
        isEntitled
    }

    // No length floor lives here any more (#650). There used to be a global
    // `summaryMinimumCharacters = 200`, set when the voice note result could only be a
    // summary; once the result became a picker over every Smart Mode, it blocked a
    // 7-second `→ EN` note too, silently. The floor is now the armed mode's own
    // `SmartMode.minimumInputCharacters`, the one the keyboard reads: 200 on `Résumé`
    // and `Structuré`, none on `Traduction`, `Message` or `Liste`.

    /// Whether the summary can run on this device right now. The transcript never
    /// depends on this; only the half of the result screen that needs Apple
    /// Intelligence does. Voice notes are their own Pro feature, so the Smart Mode
    /// switch in Settings is not consulted: it is about the keyboard's fan.
    public static func summaryUnavailableReason(engineState: PolishAvailabilityState) -> SmartModeUnavailableReason? {
        SmartModeAvailability.armability(engineState: engineState, engineIsRefusing: false,
                                         entitlement: .entitled).reason
    }
}
