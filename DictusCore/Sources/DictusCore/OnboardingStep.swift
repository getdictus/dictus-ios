// DictusCore/Sources/DictusCore/OnboardingStep.swift
// The onboarding steps, in order, and where an install mid-onboarding resumes (#649).
import Foundation

/// One step of the first-run onboarding, persisted by name in `SharedKeys.onboardingStep`.
///
/// WHY persisted at all: when the user enables "Allow Full Access" during keyboard setup,
/// iOS kills the app (the TCC permission changes under it). The step has to survive that
/// so the user comes back where they were, not to the welcome screen.
///
/// WHY by name and not by index (#649): the flow used to store a page index, and every
/// page added or removed moved the meaning of every index after it — the old switch
/// carried a `case 3` that meant two different pages depending on the device. A raw
/// string means the same step for as long as the step exists, and a name this build does
/// not know (written by a later build, then rolled back) falls back to the start instead
/// of to whichever page happens to hold that number.
///
/// WHY in DictusCore: the order and the migration from the old index are rules, and the
/// app target has no test bundle.
public enum OnboardingStep: String, CaseIterable, Sendable {
    case welcome
    /// Spoken language, keyboard language and layout. Confirming it starts the model
    /// download.
    case language
    case microphone
    case keyboardSetup
    /// Shown only while the model is still downloading or compiling; skipped otherwise.
    case modelPreparation
    /// The first dictation through the globe key. Its completion ends the onboarding.
    case firstDictation

    /// The step after this one, or nil for the last.
    public var next: OnboardingStep? {
        let all = Self.allCases
        guard let index = all.firstIndex(of: self), index + 1 < all.count else { return nil }
        return all[index + 1]
    }

    /// Position in the flow, for the progress dots.
    public var position: Int {
        Self.allCases.firstIndex(of: self) ?? 0
    }

    // MARK: - Migration from the page index (before #649)

    /// Where an install that was mid-onboarding on the old page numbering resumes.
    ///
    /// The old flow was Welcome (0), Mic (1), Keyboard (2), Polish or, on a device without
    /// polish, Model (3), Model (4), Globe (5). The language screen did not exist, so every
    /// install between the welcome and the model has not seen it, and it is the screen
    /// that decides the keyboard and the model. They resume there; the microphone and
    /// keyboard pages that follow detect what is already granted and only ask for a tap.
    ///
    /// Index 5 had already installed a model on the old device-only rule, so it resumes at
    /// the first dictation: sending it back to the language screen would download a second
    /// model to someone one step from done. Anything else (a negative or unknown index)
    /// starts over, which is what the old switch's `default` did.
    public static func migrated(fromLegacyPageIndex index: Int) -> OnboardingStep {
        switch index {
        case 1...4: return .language
        case 5: return .firstDictation
        default: return .welcome
        }
    }

    // MARK: - Persistence

    /// The step to show, read from the App Group, migrating the legacy index once.
    ///
    /// The legacy key is removed as soon as it has been read, so the migration cannot run
    /// twice and a later reset of the onboarding is not dragged back to the old position.
    public static func current(defaults: UserDefaults = AppGroup.defaults) -> OnboardingStep {
        if let raw = defaults.string(forKey: SharedKeys.onboardingStep) {
            return OnboardingStep(rawValue: raw) ?? .welcome
        }
        guard defaults.object(forKey: SharedKeys.onboardingCurrentPage) != nil else {
            return .welcome
        }
        let migrated = migrated(fromLegacyPageIndex: defaults.integer(forKey: SharedKeys.onboardingCurrentPage))
        defaults.set(migrated.rawValue, forKey: SharedKeys.onboardingStep)
        defaults.removeObject(forKey: SharedKeys.onboardingCurrentPage)
        return migrated
    }

    /// Records `step` as the one to resume at.
    public static func save(_ step: OnboardingStep, defaults: UserDefaults = AppGroup.defaults) {
        defaults.set(step.rawValue, forKey: SharedKeys.onboardingStep)
    }
}
