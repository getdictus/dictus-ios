// DictusCore/Sources/DictusCore/PreA14ParakeetProbe.swift
// Debug-build unlock of Parakeet and keyboard dictation on A12X/A12Z iPads, to measure them (issue #963).
import Foundation

/// The one exception to the pre-A14 floor, for a measurement: on an A12X/A12Z iPad Pro
/// (`iPad8,*`), a build that switches the probe on offers Parakeet in Models and enables
/// the keyboard mic.
///
/// WHY IT EXISTS: #612 greyed Parakeet out on pre-A14 chips without a measurement, and
/// #635 closed keyboard dictation there because WHISPER needs the GPU, which iOS refuses
/// to a backgrounded app. FluidAudio loads Parakeet on the CPU and the Neural Engine only
/// (`.cpuAndNeuralEngine`, preprocessor `.cpuOnly`), so the GPU argument may not apply.
/// Only a device run can tell, and a device run needs a build that lets the model and the
/// keyboard path be reached.
///
/// WHY `probeEnabled` IS A PARAMETER and not read here: the app targets pass `true` in
/// Debug builds only (`#if DEBUG` at their call sites), so a TestFlight or App Store
/// build cannot reach this branch. Deciding it here would tie the answer to how
/// DictusCore itself is compiled, and `swift test` runs in debug, which would hide the
/// Release behaviour from the tests.
///
/// WHAT IT DOES NOT TOUCH: the recommendation (onboarding still installs Base), the
/// onboarding chip notice, the Whisper compute policy, and every other pre-A14 device.
public enum PreA14ParakeetProbe {

    /// The Parakeet v3 catalogue identifier, the only model the probe unlocks.
    public static let parakeetIdentifier = "parakeet-tdt-0.6b-v3"

    /// Whether the probe changes anything on this device.
    public static func applies(to capabilities: DeviceCapabilities, probeEnabled: Bool) -> Bool {
        probeEnabled && capabilities.isA12XOrA12ZIPadPro
    }

    /// `model.incompatibilityReason(on:)`, except Parakeet on a probed device, which is
    /// offered.
    public static func incompatibilityReason(
        of model: ModelInfo,
        on capabilities: DeviceCapabilities,
        probeEnabled: Bool
    ) -> ModelInfo.IncompatibilityReason? {
        if applies(to: capabilities, probeEnabled: probeEnabled), model.identifier == parakeetIdentifier {
            return nil
        }
        return model.incompatibilityReason(on: capabilities)
    }

    /// `capabilities.supportsKeyboardDictation`, except on a probed device, where the
    /// keyboard may dictate whatever model is active. The test protocol selects Parakeet
    /// first; with Base active the keyboard fails the way #635 measured.
    public static func supportsKeyboardDictation(
        on capabilities: DeviceCapabilities,
        probeEnabled: Bool
    ) -> Bool {
        capabilities.supportsKeyboardDictation || applies(to: capabilities, probeEnabled: probeEnabled)
    }
}
