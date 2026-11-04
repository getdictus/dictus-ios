// DictusCore/Sources/DictusCore/AppGroupReadCheck.swift
// Whether what this process reads from the App Group can be trusted (#868).
//
// WHY THE FILE IS THE WITNESS: in #868's log B the device had been unlocked for an hour,
// the App Group preferences file held the user's values, and the process iOS had started
// before the first unlock still read nothing through `UserDefaults`. Its writes reached
// the disk. So "protected data is available" is not enough to trust a read: a key the
// file holds and the store does not return is the proof the view is stale.
import Foundation

/// How far this process's App Group reads can be trusted.
public enum AppGroupReadState: Equatable, Sendable {
    /// Before the first unlock: nothing can be read.
    case protected
    /// Readable, but `UserDefaults` does not return keys the file holds.
    case stale(missingKeys: [String])
    /// `UserDefaults` returns what the file holds.
    case trusted
}

public enum AppGroupReadCheck {

    /// Keys every onboarded install holds and nothing ever removes, so a missing one
    /// cannot be a removal racing the file. They are also the launch's decisions.
    public static let witnessKeys = [
        SharedKeys.hasCompletedOnboarding,
        SharedKeys.language,
        SharedKeys.liveActivityEnabled
    ]

    /// The settings a stale process takes from the file. User settings that nothing
    /// removes (except the debug reset of `lastVersionSeen`), so a fallback can never
    /// resurrect a value that was deliberately cleared. Runtime state (dictation status,
    /// stop and cancel flags, the active model) is left out for exactly that reason.
    public static let settingsKeys = witnessKeys + [
        SharedKeys.transcriptionLanguage,
        SharedKeys.spokenLanguage,
        SharedKeys.keyboardLayout,
        SharedKeys.keyboardLayoutsByLanguage,
        SharedKeys.lastVersionSeen
    ]

    /// - Parameters:
    ///   - fileValues: the App Group preferences file, `fileValues(at:)`; nil when there is
    ///     no file to compare with (a new install), which trusts the store.
    public static func state(
        of store: AppGroupStore,
        protectedData: ProtectedDataAvailability,
        fileValues: [String: Any]?
    ) -> AppGroupReadState {
        guard protectedData.isProtectedDataAvailable else { return .protected }
        guard let fileValues else { return .trusted }
        let missing = witnessKeys.filter { fileValues[$0] != nil && store.object(forKey: $0) == nil }
        return missing.isEmpty ? .trusted : .stale(missingKeys: missing)
    }

    /// The preferences file's content, read directly, without `UserDefaults`.
    public static func fileValues(at url: URL?) -> [String: Any]? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any]
    }

    /// The file's settings, to register as `UserDefaults` fallbacks in a stale process.
    ///
    /// WHY `register(defaults:)`: the registration domain lives in memory and is never
    /// written to disk, so the process reads the user's settings without writing anything,
    /// and any value it does write later still wins over the fallback. It is shared by
    /// every `UserDefaults` instance of the suite in the process (measured on macOS on
    /// 2026-10-29), which matters because `AppGroup.defaults` builds a new one per access.
    public static func settingsFallback(from fileValues: [String: Any]?) -> [String: Any] {
        guard let fileValues else { return [:] }
        return fileValues.filter { settingsKeys.contains($0.key) }
    }
}
