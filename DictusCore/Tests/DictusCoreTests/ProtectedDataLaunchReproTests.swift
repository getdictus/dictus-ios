// DictusCore/Tests/DictusCoreTests/ProtectedDataLaunchReproTests.swift
// Reproduction of #868: DictusApp started by iOS at boot, before the first unlock, while
// the App Group is protected data and reads come back empty.
import XCTest
@testable import DictusCore

/// An App Group store whose reads come back empty while `isLocked`, the way the App Group
/// `UserDefaults` does before first unlock, and, in #868's log B, for the rest of the
/// process's life after it. Writes always land, and are counted.
final class LockableAppGroupStore: AppGroupStore {
    var values: [String: Any]
    var isLocked: Bool
    private(set) var keysWrittenWhileLocked: [String] = []

    init(values: [String: Any], isLocked: Bool) {
        self.values = values
        self.isLocked = isLocked
    }

    func object(forKey defaultName: String) -> Any? {
        isLocked ? nil : values[defaultName]
    }

    func string(forKey defaultName: String) -> String? {
        object(forKey: defaultName) as? String
    }

    func bool(forKey defaultName: String) -> Bool {
        object(forKey: defaultName) as? Bool ?? false
    }

    func set(_ value: Any?, forKey defaultName: String) {
        if isLocked { keysWrittenWhileLocked.append(defaultName) }
        values[defaultName] = value
    }
}

struct FixedProtectedData: ProtectedDataAvailability {
    var isProtectedDataAvailable: Bool
}

final class ProtectedDataLaunchReproTests: XCTestCase {

    private let locked = FixedProtectedData(isProtectedDataAvailable: false)
    private let unlocked = FixedProtectedData(isProtectedDataAvailable: true)

    /// An existing user's App Group: onboarding done, English, Live Activity turned off.
    private func existingUserStore(isLocked: Bool) -> LockableAppGroupStore {
        LockableAppGroupStore(values: [
            SharedKeys.hasCompletedOnboarding: true,
            SharedKeys.language: "en",
            SharedKeys.liveActivityEnabled: false
        ], isLocked: isLocked)
    }

    /// Log B, session C0E845CE: the keyboard wrote `stopRequested = true` and posted the
    /// Darwin stop, the app was recording and read the flag as false. The stop vanished.
    func testStopWhileRecordingIsHonoredWhenTheFlagReadsFalse() {
        let appView = existingUserStore(isLocked: true)
        let flag = appView.bool(forKey: SharedKeys.stopRequested)

        XCTAssertEqual(
            KeyboardSignalPolicy.decide(.stop, flagRequested: flag, status: .recording),
            .honor
        )
    }

    /// Log B, sessions C0E845CE and A51999A3: Cancel reset the keyboard to idle and the
    /// app kept recording.
    func testCancelDuringADictationIsHonoredWhenTheFlagReadsFalse() {
        let appView = existingUserStore(isLocked: true)
        let flag = appView.bool(forKey: SharedKeys.cancelRequested)

        XCTAssertEqual(
            KeyboardSignalPolicy.decide(.cancel, flagRequested: flag, status: .recording),
            .honor
        )
    }

    /// Log A: onboarding shown again, and the launch defaults written over the user's
    /// own settings, because both ran on the empty view.
    func testLaunchBeforeFirstUnlockNeitherReadsNorWritesTheAppGroup() {
        let store = existingUserStore(isLocked: true)

        AppLaunchDefaults.writeMissingDefaults(to: store, protectedData: locked)
        let onboarding = AppLaunchDefaults.onboardingCompleted(in: store, protectedData: locked)

        XCTAssertEqual(store.keysWrittenWhileLocked, [], "no default may be written before first unlock")
        XCTAssertNil(onboarding, "an unreadable flag is unknown, not false: false shows onboarding")

        // First unlock: the real values are read and kept.
        store.isLocked = false
        AppLaunchDefaults.writeMissingDefaults(to: store, protectedData: unlocked)
        XCTAssertEqual(AppLaunchDefaults.onboardingCompleted(in: store, protectedData: unlocked), true)
        XCTAssertEqual(store.string(forKey: SharedKeys.language), "en")
        XCTAssertEqual(store.object(forKey: SharedKeys.liveActivityEnabled) as? Bool, false)
    }

    /// The case #868 actually observed: the device is unlocked, the preferences file opens
    /// and holds the user's values, and the process's `UserDefaults` view still reads
    /// nothing. Its writes do reach the disk, so every `if nil` default would replace a
    /// real setting, and onboarding would come back.
    func testUnlockedWithStaleReadsWritesNothingAndKeepsOnboardingDone() {
        let store = existingUserStore(isLocked: true)
        let file = store.values

        let wrote = AppLaunchDefaults.writeMissingDefaults(to: store, protectedData: unlocked, fileValues: file)
        let onboarding = AppLaunchDefaults.onboardingCompleted(in: store, protectedData: unlocked, fileValues: file)

        XCTAssertFalse(wrote, "a stale view must not run the launch writes")
        XCTAssertEqual(store.keysWrittenWhileLocked, [], "no default may be written over the file's values")
        XCTAssertEqual(onboarding, true, "the file says onboarding is done: it must not be shown")
    }

    /// `KeyboardState.reconcileAbandonedDictation` posts a cancel for a stale recording.
    /// When the app is already transcribing, a cancel whose flag reads false must not throw
    /// away the transcription that is about to arrive.
    func testACancelWithoutTheFlagDuringTranscriptionIsIgnored() {
        XCTAssertEqual(
            KeyboardSignalPolicy.decide(.cancel, flagRequested: false, status: .transcribing),
            .ignore(reason: "flagFalse status=transcribing")
        )
    }
}
