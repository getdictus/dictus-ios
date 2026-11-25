// DictusCore/OtherModelsCardRule.swift
// When Home shows the "Other transcription models" card (#1057).
import Foundation

/// Whether Home presents the downloadable models to someone who dictates with Apple's.
///
/// WHY THIS EXISTS (#1057): since PR 1 of #1057 an iPhone can dictate with Apple's
/// on-device model and no Dictus model at all. Such a user may never open the Models tab,
/// so Home says once that other models exist, what they cost in space, and lets them go.
///
/// The rule, all four at once:
/// 1. Apple's engine is the one dictating with no downloaded model ready
///    (`DictationReadiness.dictatesWithAppleOnly`). A user who did not pick Apple, or whose
///    Apple is not ready, sees Home's usual cards.
/// 2. No Dictus model is on disk at all. `modelReady` alone is not enough: a model just
///    downloaded but still preparing has `modelReady` false, and offering "other models"
///    to someone who has one would be wrong. This is also what keeps the card away from
///    every user who already had a model before #1057.
/// 3. The user has not closed it. Closed is for good (`SharedKeys.otherModelsCardDismissed`).
///
/// The card goes away on its own when a downloaded model becomes active: rule 1 turns
/// false with `modelReady`, rule 2 as soon as the model is on disk.
public enum OtherModelsCardRule {

    public static func shows(modelReady: Bool, choice: SpeechEngineChoice,
                             appleAvailability: AppleEngineAvailability,
                             downloadedModelCount: Int, dismissed: Bool) -> Bool {
        guard !dismissed, downloadedModelCount == 0 else { return false }
        return DictationReadiness.dictatesWithAppleOnly(modelReady: modelReady, choice: choice,
                                                        appleAvailability: appleAvailability)
    }

    /// Whether the user closed the card.
    public static func isDismissed(in defaults: UserDefaults) -> Bool {
        defaults.bool(forKey: SharedKeys.otherModelsCardDismissed)
    }

    /// Record that the user closed the card. Nothing clears it.
    public static func dismiss(in defaults: UserDefaults) {
        defaults.set(true, forKey: SharedKeys.otherModelsCardDismissed)
    }
}
