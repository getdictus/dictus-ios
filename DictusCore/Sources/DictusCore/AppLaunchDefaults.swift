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
    /// WHY NOTHING BEFORE FIRST UNLOCK: every key reads nil then, so `if nil` is true for
    /// all of them and the user's language and Live Activity choice would be replaced by
    /// the defaults. The caller runs this again once protected data is available.
    ///
    /// - Returns: whether the writes were attempted.
    @discardableResult
    public static func writeMissingDefaults(
        to store: AppGroupStore,
        protectedData: ProtectedDataAvailability,
        fileValues: [String: Any]? = nil
    ) -> Bool {
        guard protectedData.isProtectedDataAvailable else { return false }
        if store.string(forKey: SharedKeys.language) == nil {
            store.set("fr", forKey: SharedKeys.language)
        }
        if store.object(forKey: SharedKeys.liveActivityEnabled) == nil {
            store.set(true, forKey: SharedKeys.liveActivityEnabled)
        }
        return true
    }

    /// Whether onboarding is done, as the App Group says, or nil when it cannot say yet.
    ///
    /// Nil before first unlock, because the empty read would say false and false shows
    /// onboarding to a user who finished it. Once readable, a missing key reads false,
    /// as `KeyboardOnboardingGate.isOnboardingCompleted` explains.
    public static func onboardingCompleted(
        in store: AppGroupStore,
        protectedData: ProtectedDataAvailability,
        fileValues: [String: Any]? = nil
    ) -> Bool? {
        guard protectedData.isProtectedDataAvailable else { return nil }
        return store.object(forKey: SharedKeys.hasCompletedOnboarding) as? Bool ?? false
    }
}
