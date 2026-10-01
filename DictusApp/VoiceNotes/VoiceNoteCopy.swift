// DictusApp/VoiceNotes/VoiceNoteCopy.swift
// The sentences the app says about shared voice notes, in one place (#620).
import Foundation
import DictusCore

/// User-facing text for voice notes.
///
/// WHY one file: the same failure is named on the list row, on the result screen
/// and, shortened, on the Live Activity. Three call sites wording it three ways is
/// how #313 started.
enum VoiceNoteCopy {

    /// "1 in progress, 2 waiting" (#620 decision 6). Both words are invariable in
    /// French and English, so no plural variants are needed.
    static func queueLine(inProgress: Int, waiting: Int) -> String {
        String(localized: "\(inProgress) in progress, \(waiting) waiting",
               comment: "Voice note queue status on the Live Activity and the list. First number: notes being transcribed (0 or 1); second: notes waiting (#620).")
    }

    /// Why a note produced no transcript.
    static func failure(_ failure: VoiceNoteFailure) -> String {
        switch failure {
        case .unsupportedFormat:
            return String(localized: "This file is not an audio format Dictus can read.",
                          comment: "Voice note failure: the shared file is not a recognised audio container (#620).")
        case .unreadable:
            return String(localized: "This audio file could not be read.",
                          comment: "Voice note failure: recognised container, unreadable content (#620).")
        case .tooLong:
            return String(localized: "This voice note is longer than 10 minutes, the longest Dictus transcribes.",
                          comment: "Voice note failure: over the 10-minute cap (#620).")
        case .noSpeech:
            return String(localized: "No words were detected in this voice note.",
                          comment: "Voice note failure: transcription produced nothing (#620).")
        case .transcriptionFailed:
            return String(localized: "The transcription failed. Check that a model is installed, then try again.",
                          comment: "Voice note failure: the engine failed or no model is installed; a Retry button follows (#620).")
        }
    }

    /// Why the summary half of the result cannot run on this device.
    static func summaryUnavailable(_ reason: SmartModeUnavailableReason) -> String {
        switch reason {
        case .appleIntelligenceNotEnabled:
            return String(localized: "Turn on Apple Intelligence in Settings to get a summary.",
                          comment: "Voice note result: summary unavailable because Apple Intelligence is off (#620).")
        case .modelNotReady:
            return String(localized: "Apple Intelligence is still getting ready. Try again in a few minutes.",
                          comment: "Voice note result: summary unavailable because the on-device model is downloading (#620).")
        case .deviceNotEligible, .osTooOld, .sdkMissing:
            return String(localized: "Summaries need Apple Intelligence, which this iPhone does not support. The transcript is below.",
                          comment: "Voice note result: summary unavailable on this device for good (#620).")
        case .engineRefusing, .other, .notSubscribed, .switchedOff:
            return String(localized: "The summary is not available right now.",
                          comment: "Voice note result: summary unavailable for a reason the app cannot name (#620).")
        }
    }

    /// Why the summary was attempted and did not come back.
    static func summaryFailed(_ failure: SmartModeFailure) -> String {
        switch failure.outcome {
        case PolishMetrics.Outcome.exceededContextBudget.rawValue:
            return String(localized: "This voice note is too long for Apple Intelligence to summarise.",
                          comment: "Voice note result: the transcript exceeds Apple Intelligence's context (#620).")
        case PolishMetrics.Outcome.unsupportedInputLanguage.rawValue:
            return String(localized: "Apple Intelligence does not support the language of this voice note.",
                          comment: "Voice note result: summary refused because of the input language (#620).")
        default:
            return String(localized: "The summary could not be produced.",
                          comment: "Voice note result: summary failed; a Try again button follows (#620).")
        }
    }
}
