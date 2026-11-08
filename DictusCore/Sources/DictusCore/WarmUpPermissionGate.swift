// DictusCore/Sources/DictusCore/WarmUpPermissionGate.swift
// Whether a warm-up the user did not ask for may open the microphone input.
// Testable in isolation -- no AVFoundation dependency.

import Foundation

/// The record permission as the app reads it, without AVFoundation.
///
/// WHY a mirror of `AVAudioApplication.recordPermission` rather than the type itself:
/// DictusCore stays free of AVFoundation so its rules can be asserted on the Mac, and the
/// three cases are all the rule below needs. The caller maps the system value onto this.
public enum MicrophonePermissionState: String, Equatable, Sendable {
    case granted
    case undetermined
    case denied
}

/// Decides whether the audio warm-up may start the engine (issue #715).
///
/// ### The bug
///
/// iOS answers an input start with an undetermined record permission by showing its
/// microphone prompt. The warm-up starts the input on its own schedule — the launch
/// preload, and every return to the foreground once a model is ready — and never asked
/// about the permission. During onboarding the model finishes downloading minutes into
/// the flow, so the next foreground return raised the prompt on whatever step the user
/// happened to be on, before the microphone step that is meant to explain it.
///
/// ### The rule
///
/// A warm-up starts the engine only when the permission is **granted**. Undetermined
/// would raise the prompt; denied would start an input that captures nothing. In both
/// cases the warm-up skips, and a skip is not a failure: nothing is wrong with the model
/// or the engine, the microphone is simply not ours yet. The dictation start paths are
/// not governed by this — they ask for the permission themselves, through
/// `ensureMicrophonePermission()`, because there the user has just asked to record.
///
/// WHY one gate in `UnifiedAudioEngine.warmUp()` and not a check at each caller: every
/// warm-up door (launch preload, foreground return, any later caller) reaches the engine
/// through that one method, so a check there cannot be forgotten by a door added later.
public enum WarmUpPermissionGate {

    /// The `reason=` a skipped warm-up logs, per permission state. Nil when the
    /// warm-up may proceed.
    public static func skipReason(for permission: MicrophonePermissionState) -> String? {
        switch permission {
        case .granted:
            return nil
        case .undetermined, .denied:
            return "micPermission=\(permission.rawValue)"
        }
    }

    /// Whether the warm-up may start the engine with this permission.
    public static func mayStartEngine(_ permission: MicrophonePermissionState) -> Bool {
        skipReason(for: permission) == nil
    }
}
