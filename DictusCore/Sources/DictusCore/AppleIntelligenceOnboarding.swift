// DictusCore/Sources/DictusCore/AppleIntelligenceOnboarding.swift
// Whether the onboarding shows its Apple Intelligence step (#683, #649 decision 7).
import Foundation

/// The rule behind the onboarding's Apple Intelligence step.
///
/// WHY IN DICTUSCORE: the app target has no test bundle, and "shown only on a capable
/// device where Apple Intelligence is not ready" is a rule, not a layout.
public enum AppleIntelligenceOnboarding {

    /// Whether the step has something to ask on a device in `engineState`.
    ///
    /// - A capable iPhone where Apple Intelligence is not ready: shown. That is
    ///   `appleIntelligenceNotEnabled`, `modelNotReady`, and `.other`, a reason this build
    ///   does not know, which `SmartModeUnavailableReason.isRecoverable` already treats as
    ///   recoverable rather than guess that it is permanent.
    /// - Apple Intelligence available: nothing to ask.
    /// - A device that can never run it (hardware, OS, SDK): nothing to ask, and nothing
    ///   the user could do about it.
    ///
    /// WHY THE REASON IS NOT SPLIT FURTHER: Apple reportedly reports Apple Intelligence
    /// switched off as `modelNotReady` too, so the two cannot be told apart reliably. The
    /// step shows one page for both, whose copy does not depend on the reason.
    ///
    /// "Capable" is `SmartModeAvailability.isCapable(engineState:)`, the same table the
    /// trial and the paywall read, so the onboarding cannot disagree with them about
    /// which iPhones can run Smart Modes.
    public static func isStepNeeded(engineState: PolishAvailabilityState) -> Bool {
        engineState != .available && SmartModeAvailability.isCapable(engineState: engineState)
    }

    /// `isStepNeeded` for this device, right now.
    public static var isStepNeeded: Bool {
        isStepNeeded(engineState: PolishAvailability.state)
    }
}
