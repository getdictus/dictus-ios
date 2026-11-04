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
    /// WHY ONLY ON A TRUSTED READ: before the first unlock, and in a process whose view
    /// stayed stale after it (#868), every key reads nil, so `if nil` is true for all of
    /// them and the user's language and Live Activity choice would be replaced by the
    /// defaults. The caller runs this again later; see `AppGroupReadCheck`.
    ///
    /// - Parameter fileValues: the App Group preferences file, `AppGroupReadCheck.fileValues`.
    /// - Returns: whether the writes were attempted.
    @discardableResult
    public static func writeMissingDefaults(
        to store: AppGroupStore,
        protectedData: ProtectedDataAvailability,
        fileValues: [String: Any]? = nil
    ) -> Bool {
        let state = AppGroupReadCheck.state(of: store, protectedData: protectedData, fileValues: fileValues)
        guard state == .trusted else { return false }
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
    /// onboarding to a user who finished it. From the file when the store's view is stale.
    /// Otherwise from the store, where a missing key reads false, as
    /// `KeyboardOnboardingGate.isOnboardingCompleted` explains.
    public static func onboardingCompleted(
        in store: AppGroupStore,
        protectedData: ProtectedDataAvailability,
        fileValues: [String: Any]? = nil
    ) -> Bool? {
        let key = SharedKeys.hasCompletedOnboarding
        switch AppGroupReadCheck.state(of: store, protectedData: protectedData, fileValues: fileValues) {
        case .protected:
            return nil
        case .stale:
            return fileValues?[key] as? Bool ?? false
        case .trusted:
            return store.object(forKey: key) as? Bool ?? false
        }
    }
}
