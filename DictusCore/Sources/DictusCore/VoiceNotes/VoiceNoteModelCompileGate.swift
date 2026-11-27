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
