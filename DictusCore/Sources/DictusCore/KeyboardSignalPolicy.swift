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
///
/// WHY THE NOTIFICATION DECIDES AND NOT THE FLAG: only the keyboard posts these two
/// notifications, and only after writing the flag. A process started before first unlock
/// can go on reading the flag as false for its whole life (#868, log B: twelve stop taps,
/// no reaction, no log line). So while a dictation the signal can end is running, the
/// notification is acted on whatever the flag reads. The flag still settles the other
/// case: outside such a dictation a true flag is honored as before, and a false one is a
/// repeat or a late signal, ignored with a reason.
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
        if flagRequested { return .honor }
        switch signal {
        case .stop:
            // Only a recording can be stopped: a stop during `transcribing` is a repeat
            // tap, which `stopDictation`'s own guard would refuse anyway.
            if status == .recording { return .honor }
        case .cancel:
            // The keyboard drops to idle as soon as it posts a cancel, so the app honors
            // it at any stage of the dictation, as the flag path always did.
            if DictationSessionLivenessPolicy.isActive(status) { return .honor }
        }
        return .ignore(reason: "flagFalse status=\(status.rawValue)")
    }
}
