// DictusKeyboard/KeyboardState+DictationSupport.swift
// Whether the keyboard may dictate, on this device with the active model (issues #635, #963).
import Foundation
import DictusCore

extension KeyboardState {

    /// The hardware, read once per process: it cannot change under it.
    private static let device = DeviceCapabilities.current()

    /// Whether the keyboard can dictate right now, read from the App Group (#635, #963).
    ///
    /// False on a pre-A14 chip unless Parakeet is the active model: the dictation would
    /// be transcribed by a backgrounded DictusApp, where Whisper's GPU encoder is refused
    /// and Parakeet on the CPU is not. The answer is DictusCore's
    /// (`supportsKeyboardDictation(activeModel:)`), the predicate onboarding reads too.
    ///
    /// Read on every `refreshFromDefaults()`, like `polishUnavailable`: the active model
    /// changes in the app, and that refresh runs whenever a controller appears, the first
    /// moment the user can see the keyboard after changing it. Logs a change against the
    /// published `supportsDictation`.
    func currentDictationSupport() -> Bool {
        let activeModel = AppGroup.defaults.string(forKey: SharedKeys.activeModel)
        let supported = Self.device.supportsKeyboardDictation(activeModel: activeModel)
        if supported != supportsDictation {
            logProbe("dictationSupportChanged", details: "supported=\(supported) activeModel=\(activeModel ?? "nil")")
        }
        return supported
    }

    /// Decline a dictation on a device that cannot run one from the keyboard.
    ///
    /// The toolbar already draws the mic disabled and without its Smart Mode fan
    /// gesture; this is the guarantee for any caller that reaches `startRecording`
    /// anyway. The mic tap and the fan's release are the two callers today, and both
    /// go through it. Nothing is posted to DictusApp, so no backgrounded transcription
    /// is ever attempted. Read fresh at the tap: the drawn mic may predate a model
    /// change in the app.
    ///
    /// - Returns: `true` when the tap was refused and the caller must stop.
    func refuseMicTapOnUnsupportedDevice() -> Bool {
        guard !currentDictationSupport() else { return false }
        logProbe("micTapRejectedUnsupportedDevice", details: sessionDetails())
        HapticFeedback.actionRefused()
        return true
    }
}
