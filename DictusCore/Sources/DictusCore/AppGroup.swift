// DictusCore/Sources/DictusCore/AppGroup.swift
import Foundation
#if os(macOS)
import Security
#endif

public enum AppGroup {
    public static let identifier = "group.solutions.pivi.dictus"

    /// Shared UserDefaults for cross-process data.
    /// Force-unwrap justified: if this fails, the App Group entitlement
    /// is misconfigured and the app cannot function.
    public static var defaults: UserDefaults {
        guard let defaults = UserDefaults(suiteName: identifier) else {
            fatalError("App Group '\(identifier)' not configured. Check entitlements.")
        }
        return defaults
    }

    /// Shared file container URL for larger data (audio, models metadata).
    ///
    /// WHY `nil` on a Mac without the entitlement: iOS already answers `nil` to a
    /// process that is not in the group, but macOS hands back the path anyway, to
    /// a folder it then guards for the app that owns it. The only Mac processes
    /// running this code are the `swift test` host and `polish-harness`, and their
    /// every `open()` in there is held on an authorization prompt that, under a
    /// host with no Full Disk Access, never resolves: the test run hangs instead of
    /// failing. Answering `nil` makes them take the path every store already has
    /// for "no container".
    public static var containerURL: URL? {
        #if os(macOS)
        guard isEntitledToGroup else { return nil }
        #endif
        return FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: identifier
        )
    }

    #if os(macOS)
    /// Whether this process's signature lists the Dictus App Group.
    private static let isEntitledToGroup: Bool = {
        guard let task = SecTaskCreateFromSelf(nil),
              let value = SecTaskCopyValueForEntitlement(
                task, "com.apple.security.application-groups" as CFString, nil
              ),
              let groups = value as? [String] else { return false }
        return groups.contains(identifier)
    }()
    #endif
}
