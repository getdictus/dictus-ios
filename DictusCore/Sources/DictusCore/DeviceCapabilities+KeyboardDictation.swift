// DictusCore/Sources/DictusCore/DeviceCapabilities+KeyboardDictation.swift
// Whether the keyboard may start a dictation on this hardware (issue #635).
import Foundation

public extension DeviceCapabilities {

    /// Whether a dictation started from the keyboard can produce text on this device.
    ///
    /// WHY it is false on every pre-A14 chip:
    /// a keyboard dictation is transcribed by DictusApp while it sits in the
    /// background. On A12/A13-class chips WhisperKit only returns correct text with
    /// the audio encoder on the GPU (`audioEncoderComputePolicy`, #370, #612), and iOS
    /// refuses GPU work to a backgrounded app: measured on an `iPad8,1`, every
    /// configuration that touches the GPU failed the moment the app left the
    /// foreground, and the all-CPU one returned garbage (#635). In-app dictation, in
    /// the foreground, keeps working there; only the keyboard path is closed.
    ///
    /// WHY no rule of its own:
    /// the floor is `isPreA14` and nothing else, so the model recommendation, the
    /// compute policy and this gate can never disagree about which devices are old.
    /// The iPhone half (XS, XR, 11, SE 2) is not measured; it follows from Argmax's
    /// GPU requirement and Apple's background-GPU rule, and the decision on #635 is to
    /// apply the floor to iPhones too.
    ///
    /// WHY in DictusCore and not in the keyboard:
    /// the keyboard extension has no test bundle, and DictusApp needs the same answer
    /// to warn the user during onboarding.
    var supportsKeyboardDictation: Bool {
        !isPreA14
    }
}
