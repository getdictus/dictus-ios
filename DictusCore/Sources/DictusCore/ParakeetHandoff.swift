// DictusCore/ParakeetHandoff.swift
// The marker the onboarding leaves when Parakeet downloads behind Apple's model (#1057).
import Foundation

/// Whether Parakeet is due to take over from Apple's model once it is ready (#1057).
///
/// Set by the onboarding on Apple's route when the recommended model is Parakeet: the user
/// dictates with Apple at once while Parakeet downloads in the background
/// (`OnboardingConfirmDownload.parakeetBehindApple`). The switch itself is a later change;
/// until then nothing but the tests reads the marker.
///
/// WHY A KEY OF ITS OWN and not `speechEngineChoice`: the choice says what dictates NOW,
/// and that stays Apple until the switch. The marker says the switch was promised, so it
/// must not survive the user taking the decision themselves: any engine picked on the
/// Models page clears it, Apple or a downloaded model alike.
public enum ParakeetHandoff {
    public static func isPending(in defaults: UserDefaults) -> Bool {
        defaults.bool(forKey: SharedKeys.parakeetHandoffPending)
    }

    /// The onboarding started Parakeet's download behind Apple's model.
    public static func markPending(in defaults: UserDefaults) {
        defaults.set(true, forKey: SharedKeys.parakeetHandoffPending)
    }

    /// The onboarding's route no longer downloads Parakeet behind Apple: confirmed again
    /// with another language, or Apple's install failed and the download is the route.
    public static func cancel(in defaults: UserDefaults) {
        defaults.removeObject(forKey: SharedKeys.parakeetHandoffPending)
    }

    /// Stores an engine the user picked on the Models page, and ends the handoff: their
    /// choice wins over it, whichever engine it is. The Models page's only way to write
    /// the choice, so neither card can forget the marker.
    public static func recordModelsPageChoice(_ choice: SpeechEngineChoice, in defaults: UserDefaults) {
        defaults.removeObject(forKey: SharedKeys.parakeetHandoffPending)
        SpeechEngineChoice.write(choice, to: defaults)
    }
}
