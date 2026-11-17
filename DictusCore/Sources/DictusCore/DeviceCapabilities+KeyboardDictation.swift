// DictusCore/Sources/DictusCore/DeviceCapabilities+KeyboardDictation.swift
// Whether the keyboard may start a dictation on this hardware (issues #635, #963).
import Foundation

public extension DeviceCapabilities {

    /// Whether a dictation started from the keyboard can produce text on this device
    /// with `activeModel` as the active model (`SharedKeys.activeModel`).
    ///
    /// A keyboard dictation is transcribed by DictusApp while it sits in the background,
    /// and iOS refuses GPU work to a backgrounded app.
    ///
    /// WHY WHISPER IS REFUSED BEFORE A14 (#635): on A12/A13-class chips WhisperKit only
    /// returns correct text with the audio encoder on the GPU (`audioEncoderComputePolicy`,
    /// #370, #612). Measured on an `iPad8,1`: every configuration that touches the GPU
    /// failed the moment the app left the foreground, and the all-CPU one returned
    /// garbage. In-app dictation, in the foreground, keeps working there.
    ///
    /// WHY PARAKEET IS ALLOWED (#963): on these chips Parakeet runs on the CPU only
    /// (`parakeetComputePolicy`), which the background allows. Measured on `iPad8,1`:
    /// 4/4 keyboard dictations inserted, 4.6-6.2 s each, DictusApp in the background.
    ///
    /// WHY THE ACTIVE MODEL AND NOT "IS PARAKEET DOWNLOADED": the keyboard dictates with
    /// whatever model is active. A pre-A14 user who had Base before #963 keeps Base active
    /// until Parakeet is downloaded and adopted, and their keyboard stays closed until then.
    ///
    /// WHY IN DICTUSCORE and not in the keyboard: the keyboard extension has no test
    /// bundle, and DictusApp needs the same answer to word the onboarding.
    func supportsKeyboardDictation(activeModel: String?) -> Bool {
        !isPreA14 || activeModel == ModelInfo.parakeetV3Identifier
    }
}
