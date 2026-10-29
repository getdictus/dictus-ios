// DictusCore/Sources/DictusCore/AppLaunchDefaults.swift
// What DictusApp reads and writes in the App Group at launch (#868).
import Foundation

/// The App Group values DictusApp settles at launch: the onboarding flag it reads, and
/// the defaults it writes when a key is missing.
public enum AppLaunchDefaults {

    /// Write the defaults a missing key stands for: `language = "fr"` and
    /// `liveActivityEnabled = true`.
    ///
    /// WHY at launch: `@AppStorage` defaults live in memory only, and the transcription
    /// service and the keyboard read the stored value. `if nil` keeps a user's own choice.
    ///
    /// - Returns: whether the writes were attempted.
    @discardableResult
    public static func writeMissingDefaults(
        to store: AppGroupStore,
        protectedData: ProtectedDataAvailability
    ) -> Bool {
        if store.string(forKey: SharedKeys.language) == nil {
            store.set("fr", forKey: SharedKeys.language)
        }
        if store.object(forKey: SharedKeys.liveActivityEnabled) == nil {
            store.set(true, forKey: SharedKeys.liveActivityEnabled)
        }
        return true
    }

    /// Whether onboarding is done, as the App Group says, or nil when it cannot say yet.
    public static func onboardingCompleted(
        in store: AppGroupStore,
        protectedData: ProtectedDataAvailability
    ) -> Bool? {
        store.object(forKey: SharedKeys.hasCompletedOnboarding) as? Bool ?? false
    }
}
