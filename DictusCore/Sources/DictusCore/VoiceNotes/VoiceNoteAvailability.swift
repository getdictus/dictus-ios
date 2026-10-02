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
        /// Refuse without naming a subscription: while #236's flag is down the app
        /// must not look like it has one, and the extension is part of the app.
        case refuseUnavailable
    }

    public static func shareDecision(isEntitled: Bool, paywallVisible: Bool) -> ShareDecision {
        if isEntitled { return .accept }
        return paywallVisible ? .refuseNeedsPro : .refuseUnavailable
    }

    /// The live answer for this process.
    public static var shareDecision: ShareDecision {
        shareDecision(isEntitled: isEntitled, paywallVisible: PremiumFlags.paywallVisible)
    }

    /// Whether the app may start transcribing a waiting note. Checked before each
    /// note, not once per queue: an entitlement can lapse while the app lives.
    public static func mayTranscribe(isEntitled: Bool) -> Bool {
        isEntitled
    }

    /// Shortest transcript, in characters, a voice note's summary runs on (#620
    /// rework). Below it the result shows the transcript alone.
    ///
    /// **200, the floor `Structuré` already carries** (`SmartModeCatalogue.structured`,
    /// #587 round 4), rather than a new number: it was read off 51 device dictations,
    /// where everything under 200 characters was one or two sentences with nothing
    /// to condense, and it is where the voice note device run failed too — both
    /// `LanguageModelError` refusals of 2026-10-01 were on one 8-second, 132-character
    /// note. 200 characters is about 30 to 35 words of French or English, the "roughly
    /// 30 words" the maintainer asked for.
    public static let summaryMinimumCharacters = 200

    /// Whether a transcript is long enough to be worth summarising.
    public static func summaryRuns(onTranscriptOfLength characters: Int) -> Bool {
        characters >= summaryMinimumCharacters
    }

    /// Whether the summary can run on this device right now. The transcript never
    /// depends on this; only the half of the result screen that needs Apple
    /// Intelligence does. Voice notes are their own Pro feature, so the Smart Mode
    /// switch in Settings is not consulted: it is about the keyboard's fan.
    public static func summaryUnavailableReason(engineState: PolishAvailabilityState) -> SmartModeUnavailableReason? {
        SmartModeAvailability.armability(engineState: engineState, engineIsRefusing: false,
                                         entitlement: .entitled).reason
    }
}
