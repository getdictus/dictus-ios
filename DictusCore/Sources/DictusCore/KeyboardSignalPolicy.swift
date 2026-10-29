// DictusCore/Sources/DictusCore/KeyboardSignalPolicy.swift
// Whether DictusApp acts on a stop or cancel the keyboard posted (#868).
import Foundation

/// The two keyboard signals that end a dictation.
public enum KeyboardSignal: String, Sendable {
    case stop
    case cancel
}

/// What the app does with one keyboard signal.
public enum KeyboardSignalDecision: Equatable, Sendable {
    case honor
    /// Not acted on. `reason` goes on the `stopIgnored` / `cancelIgnored` line.
    case ignore(reason: String)
}

/// Decides a Darwin `stopRecording` / `cancelRecording` notification.
public enum KeyboardSignalPolicy {

    /// - Parameters:
    ///   - signal: which notification arrived.
    ///   - flagRequested: `SharedKeys.stopRequested` / `cancelRequested` as the app reads it.
    ///   - status: the coordinator's status when the notification is handled.
    public static func decide(
        _ signal: KeyboardSignal,
        flagRequested: Bool,
        status: DictationStatus
    ) -> KeyboardSignalDecision {
        flagRequested ? .honor : .ignore(reason: "flagFalse")
    }
}
