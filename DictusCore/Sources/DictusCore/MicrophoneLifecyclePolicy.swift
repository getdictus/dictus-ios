import Foundation

/// Existing installs retain warm standby unless the user opts out.
public enum MicrophoneLifecycleMode: String, Sendable {
    case standby
    case releaseAfterDictation
}

public enum MicrophoneStandbyRestorationState: Equatable, Sendable {
    case idle
    case preparing
    case verified
    case unavailable
}

public enum MicrophoneLifecyclePolicy {
    /// A preference change must never reconfigure an active dictation or handoff.
    public static func canRestoreStandby(
        mode: MicrophoneLifecycleMode,
        status: DictationStatus,
        awaitingKeyboard: Bool
    ) -> Bool {
        mode == .standby && !DictationSessionLivenessPolicy.isActive(status) && !awaitingKeyboard
    }

    public static func mode(defaults: UserDefaults) -> MicrophoneLifecycleMode {
        defaults.bool(forKey: SharedKeys.releaseMicrophoneAfterDictation) ? .releaseAfterDictation : .standby
    }

    /// Keep the existing audio background runtime throughout transcription and polish.
    public static func shouldRelease(
        mode: MicrophoneLifecycleMode,
        status: DictationStatus,
        awaitingKeyboard: Bool,
        abandonedRequest: Bool = false
    ) -> Bool {
        guard mode == .releaseAfterDictation, !awaitingKeyboard else { return false }
        switch status {
        case .requested: return abandonedRequest
        case .recording, .transcribing, .processing: return false
        case .idle, .ready, .failed: return true
        }
    }
}
