// DictusCore/Sources/DictusCore/VoiceNotes/VoiceNoteSmartModeAttempt.swift
// One run of a voice note's Smart Mode, as the log and the fallback read it (#627).
import Foundation

/// What started a voice note's Smart Mode.
public enum VoiceNoteSmartModeTrigger: String, Sendable {
    /// Chained right after the transcription, by the queue, usually with DictusApp in
    /// the background (#627).
    case background
    /// The card on screen, with nothing stored yet: the behaviour before #627, and its
    /// fallback.
    case open
}

/// One run of a voice note's Smart Mode, reduced to what the persistent log and the
/// card's fallback need.
///
/// ### Why every attempt is logged (#627)
///
/// Before #627 only failures reached the log, from the card. The decision to keep the
/// background route rests on a device probe that counts successes against refusals
/// and reads where in the process's Apple FM budget each refusal came, so a success
/// has to leave a line too, and so does a refusal the user never sees because the
/// card silently ran the mode again on open.
///
/// The line, after `component=VoiceNote instanceID=summary action=<action>`:
///
///     mode=summary outcome=success reason=- engineMs=3120 appState=background callIndex=4 trigger=background
public struct VoiceNoteSmartModeAttempt: Equatable, Sendable {

    public enum Action: String, Sendable {
        /// The mode's result is there to show.
        case success
        /// The mode turned the transcript down as too short for it (#650): not a
        /// failure, the card shows the transcript alone.
        case declined
        /// No result.
        case failed
    }

    public let action: Action
    public let modeIdentifier: String
    /// `PolishMetrics.Outcome` raw value, or `success`, or `emptyOutput` for a
    /// success that came back blank.
    public let outcome: String
    /// `PolishFailureReason.slug`, or `backgroundTimeExpired` when the queue's
    /// background task ran out under the call, or "-".
    public let reason: String
    public let engineMs: Int
    /// The application state when the attempt started: `active`, `inactive`,
    /// `background`. What Apple's rate limit is decided on.
    public let appState: String
    /// `AppleFMCallCounter.current` when the attempt ended: how many Apple FM calls
    /// this process had made, this one included when it made one.
    public let callIndex: Int
    public let trigger: VoiceNoteSmartModeTrigger

    /// The reason a cancellation is logged with when it was the background task
    /// expiring, rather than a supersede.
    public static let backgroundTimeExpiredReason = "backgroundTimeExpired"

    public init(outcome: PolishOutcome,
                modeIdentifier: String,
                appState: String,
                callIndex: Int,
                trigger: VoiceNoteSmartModeTrigger,
                cancelReason: String? = nil) {
        self.modeIdentifier = modeIdentifier
        self.engineMs = outcome.engineMs ?? 0
        self.appState = appState
        self.callIndex = callIndex
        self.trigger = trigger
        if let failure = outcome.smartModeFailure {
            let declined = failure.outcome == PolishMetrics.Outcome.smartModeSkippedShortInput.rawValue
            self.action = declined ? .declined : .failed
            self.outcome = failure.outcome
            let isCancel = failure.outcome == PolishMetrics.Outcome.cancelled.rawValue
            self.reason = isCancel ? (cancelReason ?? failure.reason) : failure.reason
        } else if let text = outcome.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.action = .success
            self.outcome = "success"
            self.reason = "-"
        } else {
            self.action = .failed
            self.outcome = "emptyOutput"
            self.reason = "-"
        }
    }

    /// The `details` of the log line; `action` travels in its own field.
    public var logDetails: String {
        "mode=\(modeIdentifier) outcome=\(outcome) reason=\(reason) engineMs=\(engineMs) "
            + "appState=\(appState) callIndex=\(callIndex) trigger=\(trigger.rawValue)"
    }

    /// Whether this attempt failed only because it ran in the background, so the card
    /// runs the mode again on open, in the foreground, without showing an error (#627).
    ///
    /// - `rateLimited`: Apple's background budget refused the call. Per call, and
    ///   served in the foreground (#315).
    /// - `engineUnavailable`: the background service's #315 gate latched after two of
    ///   those in a row and stopped calling. The foreground service has its own gate.
    /// - `cancelled`: the background task expired under the call, or a newer call on
    ///   the same slot superseded it. Either way the mode never answered.
    ///
    /// Every other failure is the mode's own answer to this transcript, and the card
    /// treats it as it always has.
    public var defersToOpen: Bool {
        guard action == .failed else { return false }
        return reason == PolishFailureReason.rateLimited.slug
            || outcome == PolishMetrics.Outcome.engineUnavailable.rawValue
            || outcome == PolishMetrics.Outcome.cancelled.rawValue
    }

    /// Whether the queue tries a note's mode right after transcribing it (#627).
    ///
    /// The same conditions the card checks before running it on open, so the background
    /// never spends a call the card would not have: a mode is chosen, the device can
    /// run it, the user is entitled, nothing is stored yet, and the transcript is long
    /// enough for the mode (#650). A note too short for its mode is left to the card,
    /// which records the decline when the user looks at it, as before.
    public static func runsInBackground(mode: SmartMode?,
                                        transcriptLength: Int,
                                        unavailableReason: SmartModeUnavailableReason?,
                                        isEntitled: Bool,
                                        hasStoredResult: Bool) -> Bool {
        guard let mode, unavailableReason == nil, isEntitled, !hasStoredResult else { return false }
        return mode.runs(onInputOfLength: transcriptLength)
    }
}
