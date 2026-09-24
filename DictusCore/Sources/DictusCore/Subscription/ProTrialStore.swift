// DictusCore/Sources/DictusCore/Subscription/ProTrialStore.swift
// Where the reverse trial is recorded: the Keychain decides, the App Group mirrors (#593).
import Foundation
import Security

/// The durable half of the trial record.
///
/// A protocol so the tests never touch a real keychain: `swift test` runs on the
/// Mac, where a keychain call from an unsigned test runner can block on the login
/// keychain the way the guarded App Group container once hung the suite (#560).
public protocol ProTrialKeychain {
    func read() -> ProTrialRecord?
    /// Returns whether the record is now durably stored.
    func write(_ record: ProTrialRecord) -> Bool
    /// DEBUG tooling only: the reset that lets the maintainer run the trial again.
    func delete()
}

/// The real Keychain, as a generic-password item private to DictusApp.
///
/// ### Why the Keychain is the source of truth
///
/// **The trial cannot be restarted by reinstalling** (#593). Deleting the app
/// deletes its container, and the App Group goes with it once no app of the group
/// is left, which is always the case here: the keyboard ships inside the app. A
/// Keychain item survives the deletion, so a reinstall finds the record and grants
/// nothing new.
///
/// ### Why `AfterFirstUnlock` and not `…ThisDeviceOnly`
///
/// The non-`ThisDeviceOnly` class travels in an encrypted backup, so restoring a
/// backup onto a new iPhone carries the record with it: a restore is the same user
/// on the same install history, not a new user. Not synchronizable through iCloud
/// Keychain, because nothing in #593 asks for a trial to follow the Apple ID across
/// devices, and that would be a decision rather than an implementation detail.
///
/// ### Why no access group
///
/// Only DictusApp reads or writes this. The keyboard reads the App Group mirror,
/// so no keychain entitlement is shared between the two targets and the default
/// app-private access group is exactly the right scope.
public struct SystemProTrialKeychain: ProTrialKeychain {
    private let service = "solutions.pivi.dictus.proTrial"
    private let account = "reverseTrial"

    public init() {}

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    public func read() -> ProTrialRecord? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(ProTrialRecord.self, from: data)
    }

    public func write(_ record: ProTrialRecord) -> Bool {
        guard let data = try? JSONEncoder().encode(record) else { return false }
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        let status = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        if status == errSecSuccess { return true }
        guard status == errSecItemNotFound else { return false }
        let add = baseQuery.merging(attributes) { _, new in new }
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }

    public func delete() {
        SecItemDelete(baseQuery as CFDictionary)
    }
}

/// The reverse trial's record, readable from both processes.
///
/// **The keyboard reads the mirror and only the mirror.** The extension decides Pro
/// through `ProStatusManager.isProActiveStatic`, which goes to the App Group, so the
/// trial end has to be there for the keyboard to agree with the app (#593). The
/// Keychain is never read from the extension: it has no business with the 50 MB
/// process, and a mirror the app keeps current is what #401 already established as
/// the way two processes agree on one answer.
///
/// Every write goes Keychain first, then mirror. A record that reached the mirror
/// but not the Keychain would be a trial a reinstall could restart, which is the one
/// property this type exists to hold.
public struct ProTrialStore {
    private let keychain: ProTrialKeychain
    private let defaults: UserDefaults

    public init(keychain: ProTrialKeychain, defaults: UserDefaults) {
        self.keychain = keychain
        self.defaults = defaults
    }

    /// The store both processes use in production.
    public static var live: ProTrialStore {
        ProTrialStore(keychain: SystemProTrialKeychain(), defaults: AppGroup.defaults)
    }

    // MARK: - Mirror (both processes)

    /// The record as the App Group mirrors it. Cheap: two `UserDefaults` reads.
    public var mirroredRecord: ProTrialRecord? {
        Self.mirroredRecord(in: defaults)
    }

    /// The mirror read without a store, for `ProStatusManager.isProActiveStatic`,
    /// which the keyboard calls on every panel open and must not build a Keychain
    /// wrapper to do it.
    static func mirroredRecord(in defaults: UserDefaults) -> ProTrialRecord? {
        guard let started = defaults.object(forKey: SharedKeys.proTrialStartedAt) as? Double,
              let ends = defaults.object(forKey: SharedKeys.proTrialEndsAt) as? Double else {
            return nil
        }
        return ProTrialRecord(
            startedAt: Date(timeIntervalSince1970: started),
            endsAt: Date(timeIntervalSince1970: ends)
        )
    }

    private func writeMirror(_ record: ProTrialRecord) {
        defaults.set(record.startedAt.timeIntervalSince1970, forKey: SharedKeys.proTrialStartedAt)
        defaults.set(record.endsAt.timeIntervalSince1970, forKey: SharedKeys.proTrialEndsAt)
        // The reader is another process, same reason `ProStatusManager.setProActive`
        // synchronises.
        defaults.synchronize()
    }

    // MARK: - Keychain (DictusApp only)

    /// Bring the mirror in line with the Keychain. Called once per app launch,
    /// before anything asks whether a trial may start.
    ///
    /// - The Keychain has a record: it wins, whatever the mirror says. This is the
    ///   reinstall path: a fresh App Group, an old Keychain item, no new trial.
    /// - Only the mirror has one: adopt it into the Keychain rather than drop it. A
    ///   record the user was shown must never be forgotten, and the only way to lose
    ///   the Keychain half is a write that failed after the mirror existed.
    ///
    /// Returns the record now in force, if any.
    @discardableResult
    public func reconcile() -> ProTrialRecord? {
        if let durable = keychain.read() {
            if mirroredRecord != durable { writeMirror(durable) }
            return durable
        }
        guard let mirrored = mirroredRecord else { return nil }
        _ = keychain.write(mirrored)
        return mirrored
    }

    /// Record a trial starting at `now`, unless one was ever recorded.
    ///
    /// Returns the new record, or nil when nothing was started: a trial already
    /// exists (no second trial, whatever the caller believed), or the Keychain
    /// refused the write. The second case fails closed on purpose: a trial that
    /// only the App Group knows about is one a reinstall would hand out again.
    public func startIfNeverStarted(now: Date) -> ProTrialRecord? {
        guard reconcile() == nil else { return nil }
        let record = ProTrialRecord.starting(at: now)
        guard keychain.write(record) else { return nil }
        writeMirror(record)
        return record
    }

    #if DEBUG
    /// Overwrite the record in both places. DEBUG tooling only: it is what lets the
    /// maintainer move a trial to its last two days or past its end on a device.
    public func debugOverwrite(_ record: ProTrialRecord) {
        _ = keychain.write(record)
        writeMirror(record)
    }

    /// Forget the trial in both places. DEBUG tooling only.
    public func debugReset() {
        keychain.delete()
        defaults.removeObject(forKey: SharedKeys.proTrialStartedAt)
        defaults.removeObject(forKey: SharedKeys.proTrialEndsAt)
        defaults.synchronize()
    }
    #endif
}
