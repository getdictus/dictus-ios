// DictusCore/Sources/DictusCore/Subscription/ProTrialUsage.swift
// The two counters behind the end-of-trial recap (#593, decision 5).
import Foundation

/// What the user did with Pro while the trial ran.
///
/// The end-of-trial paywall opens on a personal recap: "in 14 days you used Smart
/// Modes 23 times and Vocabulary fixed 11 words". A reverse trial converts through
/// loss aversion, and a number the user produced themselves names the loss better
/// than any feature list.
///
/// ### Privacy
///
/// Two integers in the App Group, like everything else on-device. No text, no
/// timestamps, nothing that leaves the iPhone.
///
/// ### Why only while the trial runs
///
/// The recap describes the trial. Counting before it started or after it ended, or
/// for a subscriber, would put numbers on the paywall that are not about the period
/// it names.
///
/// ### Two processes write these
///
/// Smart Modes run in the keyboard since #361 and in the app for in-app dictations,
/// and the vocabulary pass runs wherever the transcript is produced. A
/// read-increment-write through `UserDefaults` from two processes can lose an
/// increment if both land in the same instant; for a recap this is an acceptable
/// cost, and cheaper than a cross-process lock for a number nobody reconciles.
public enum ProTrialUsage {

    public struct Snapshot: Equatable, Sendable {
        public let smartModeUses: Int
        public let vocabularyFixes: Int

        public init(smartModeUses: Int, vocabularyFixes: Int) {
            self.smartModeUses = smartModeUses
            self.vocabularyFixes = vocabularyFixes
        }

        /// Whether there is anything to recap. A recap of zeros would tell the user
        /// they never tried the thing, which is not a reason to keep it; the paywall
        /// falls back to its generic framing instead.
        public var isEmpty: Bool { smartModeUses == 0 && vocabularyFixes == 0 }
    }

    /// Whether a use happening now belongs to the trial.
    ///
    /// Only a running, unpaid trial counts. Reads the same App Group inputs the
    /// entitlement does, so the counters and `isProActiveStatic` cannot disagree
    /// about whether the trial is on.
    ///
    /// `trialsEnabled` is `PremiumFlags.paywallVisible` in production, a parameter
    /// only so the tests can reach the counting branch the shipping flag pins shut.
    static func isCounting(in defaults: UserDefaults, now: Date, trialsEnabled: Bool) -> Bool {
        guard trialsEnabled, !defaults.bool(forKey: SharedKeys.proActive) else { return false }
        return ProTrialState(record: ProTrialStore.mirroredRecord(in: defaults), now: now).isRunning
    }

    /// A Smart Mode dictation succeeded. Called from `PolishService`, which both
    /// processes run.
    public static func recordSmartModeUse() {
        increment(SharedKeys.proTrialSmartModeUses, by: 1, in: AppGroup.defaults, now: Date(),
                  trialsEnabled: PremiumFlags.paywallVisible)
    }

    /// The vocabulary rewrote `count` words in one dictation. Called from
    /// `CustomVocabulary.corrected(_:)`.
    public static func recordVocabularyFixes(_ count: Int) {
        increment(SharedKeys.proTrialVocabularyFixes, by: count, in: AppGroup.defaults, now: Date(),
                  trialsEnabled: PremiumFlags.paywallVisible)
    }

    static func increment(_ key: String,
                          by count: Int,
                          in defaults: UserDefaults,
                          now: Date,
                          trialsEnabled: Bool) {
        guard count > 0, isCounting(in: defaults, now: now, trialsEnabled: trialsEnabled) else { return }
        defaults.set(defaults.integer(forKey: key) + count, forKey: key)
    }

    /// The two counters as they stand.
    public static func snapshot(in defaults: UserDefaults = AppGroup.defaults) -> Snapshot {
        Snapshot(
            smartModeUses: defaults.integer(forKey: SharedKeys.proTrialSmartModeUses),
            vocabularyFixes: defaults.integer(forKey: SharedKeys.proTrialVocabularyFixes)
        )
    }

    #if DEBUG
    /// DEBUG tooling only: forget the counters with the trial they describe.
    public static func debugReset(in defaults: UserDefaults = AppGroup.defaults) {
        defaults.removeObject(forKey: SharedKeys.proTrialSmartModeUses)
        defaults.removeObject(forKey: SharedKeys.proTrialVocabularyFixes)
    }
    #endif
}
