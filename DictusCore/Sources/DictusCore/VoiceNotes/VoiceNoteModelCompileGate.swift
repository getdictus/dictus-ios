// DictusCore/Sources/DictusCore/VoiceNotes/VoiceNoteModelCompileGate.swift
// When the downloaded model a voice note wanted may be compiled (#1084, PR 2).
import Foundation

/// Whether DictusApp may compile the downloaded model a voice note asked for
/// (`VoiceNoteEngineChoice.Decision.compilesDownloadedModel`).
///
/// A Core ML compile holds the Neural Engine for minutes on an iPhone. The rule keeps it off
/// every path where someone is waiting: only with the app in the foreground (the moment
/// `warmUpEngineOnForeground` already loads a model the user did not ask for), never while a
/// dictation is in progress or a keyboard-launched one is about to start (the cold start's
/// pending dictation), never while the voice-note queue runs, and so never on a background
/// wake (a download finishing, a share).
public enum VoiceNoteModelCompileGate {
    public enum Refusal: String, Equatable, Sendable {
        case nothingScheduled
        case appNotActive
        case dictationInProgress
        case keyboardDictationPending
        case voiceNoteInProgress
    }

    /// Nil when the compile may start, else the first reason it may not.
    public static func refusal(scheduled: Bool, appIsActive: Bool, dictationStatus: DictationStatus,
                               keyboardDictationPending: Bool, voiceNoteRunning: Bool) -> Refusal? {
        guard scheduled else { return .nothingScheduled }
        guard appIsActive else { return .appNotActive }
        guard dictationStatus == .idle else { return .dictationInProgress }
        guard !keyboardDictationPending else { return .keyboardDictationPending }
        guard !voiceNoteRunning else { return .voiceNoteInProgress }
        return nil
    }
}

/// Which downloaded model waits to be compiled for the voice notes (#1084, PR 2).
///
/// A value, so its one subtle rule is tested: a compile that finishes clears the schedule
/// only when it compiled the model still scheduled. The user can pick another model while a
/// compile runs, a cold note then schedules that one, and it must stay scheduled
/// (PR #1095 review).
public struct VoiceNoteCompileSchedule: Equatable, Sendable {
    public private(set) var model: String?

    public init(model: String? = nil) {
        self.model = model
    }

    /// Returns false when `model` was already the one scheduled.
    @discardableResult
    public mutating func schedule(_ model: String) -> Bool {
        guard self.model != model else { return false }
        self.model = model
        return true
    }

    /// `compiled` finished and is warm.
    public mutating func finished(_ compiled: String) {
        if model == compiled { model = nil }
    }
}
