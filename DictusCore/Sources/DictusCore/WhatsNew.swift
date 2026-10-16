// DictusCore/Sources/DictusCore/WhatsNew.swift
// Who sees What's new, once, and which onboarding scenes it replays (#685).
import Foundation

/// What's new for existing users (#685, #649 decision 11): at the first launch of 2.0.0, an
/// install that completed onboarding on an earlier version replays the four feature
/// scenes, without the setup steps. The existing-user trial announcement (#593) follows it.
///
/// WHY NOT HOW TO STOP DICTUS (#649 decision 19 said it was part of it; Pierre dropped it
/// on 2026-10-14 after testing PR #741): stopping the standby from the island has existed
/// since the app's first version. It is a reminder for new users, in the onboarding, not
/// news for existing ones.
///
/// WHY IN DICTUSCORE: who is an existing user, and when the key is written, are rules, and
/// the app target has no test bundle.
///
/// HOW AN EXISTING USER IS TOLD FROM A NEW INSTALL: `SharedKeys.lastVersionSeen` does not
/// exist before this build, so on the first launch both look the same through it. The
/// other fact is `hasCompletedOnboarding`: an existing user set it long ago, a new install
/// has not. So the first launch of an install that has NOT completed onboarding records
/// the edition straight away (`recordLaunch`). Its onboarding plays every scene What's new
/// would, and when it completes, the key already says the user is up to date. An install
/// that HAS completed onboarding and is behind the edition is shown What's new instead,
/// and the key is written once it is on screen (`recordSeen`).
///
/// WHY THE RUNNING VERSION IS NOT PART OF THE RULE: the edition is the release that first
/// carries this code, and nothing else reaches a user before it. Not reading the running
/// version lets the sequence be tested on a development build that still says 1.9.0. Such
/// a build records the edition, never less (`recordedVersion`), so 2.0.0 does not replay it.
public enum WhatsNew {

    /// The release whose What's new this is.
    public static let edition = "2.0.0"

    /// The steps What's new plays, in onboarding order: the four feature scenes.
    ///
    /// WHY NOT THE SMART MODE PICK: it is a setup step. It writes the keyboard's pinned
    /// modes, and an existing user already has a fan, possibly chosen by hand.
    static let candidateSteps: [OnboardingStep] = [
        .smartModesScene, .voiceNotesScene, .vocabularyScene, .historyScene
    ]

    // MARK: - The rule

    /// Whether What's new is due.
    ///
    /// - Parameters:
    ///   - lastVersionSeen: `SharedKeys.lastVersionSeen`, nil when absent.
    ///   - onboardingCompleted: `SharedKeys.hasCompletedOnboarding`. False means a new
    ///     install, or one still in its onboarding, which already plays the scenes.
    public static func isDue(lastVersionSeen: String?, onboardingCompleted: Bool) -> Bool {
        onboardingCompleted && isOlder(lastVersionSeen, than: edition)
    }

    /// Whether What's new may take the screen now, when it is due.
    ///
    /// - Parameters:
    ///   - displayIsFree: nothing else owns the screen: no dictation, preparation, paywall,
    ///     voice note or trial screen.
    ///   - activationOpenedByURL: this activation was opened by a URL (the Live Activity's
    ///     voice note link, the keyboard's Pro entry, a widget), whether it launched the
    ///     process or reached it running.
    ///
    /// WHY A URL DEFERS IT (CodeRabbit on PR #741): the URL is handled after the first frame
    /// is drawn, so What's new would take the screen the user asked for, and be recorded as
    /// seen on the way. It waits for the next activation instead, and is recorded only when
    /// it is actually on screen.
    public static func mayAppear(displayIsFree: Bool, activationOpenedByURL: Bool) -> Bool {
        displayIsFree && !activationOpenedByURL
    }

    /// The value to write once the user is up to date: the latest of what was stored, the
    /// running version and the edition. It never goes down, so a rollback to an older
    /// build cannot make What's new due again.
    public static func recordedVersion(lastVersionSeen: String?, currentVersion: String) -> String {
        [lastVersionSeen, currentVersion, edition]
            .compactMap { $0 }
            .max { isOlder($0, than: $1) } ?? edition
    }

    /// Whether `version` is older than `other`, comparing numbers part by part ("1.10.0"
    /// is newer than "1.9.0"). A missing version is older than any: every install from
    /// before the key existed.
    public static func isOlder(_ version: String?, than other: String) -> Bool {
        guard let version else { return true }
        return version.compare(other, options: .numeric) == .orderedAscending
    }

    // MARK: - The steps

    /// The steps What's new plays on this device, in order. Empty when there is nothing to
    /// show, and then What's new is recorded as seen without appearing.
    ///
    /// The onboarding's own rule decides: the four scenes are Pro steps, hidden on a device
    /// that can never run Smart Modes (#593 decision 2). Such a device therefore has nothing
    /// to show, and gets no trial announcement either.
    public static func steps(deviceCanRunSmartModes: Bool) -> [OnboardingStep] {
        candidateSteps.filter { $0.isShown(deviceCanRunSmartModes: deviceCanRunSmartModes) }
    }

    /// The step after `step` in `steps`, or nil when What's new ends.
    public static func next(after step: OnboardingStep, in steps: [OnboardingStep]) -> OnboardingStep? {
        guard let index = steps.firstIndex(of: step), index + 1 < steps.count else { return nil }
        return steps[index + 1]
    }

    // MARK: - Persistence

    /// The running app's marketing version, or the edition if the bundle has none. Never
    /// "?": it is compared as a version, and a placeholder would sort above every number.
    public static var runningVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? edition
    }

    /// Whether What's new is due for this install, read from the App Group.
    public static func isDue(defaults: UserDefaults = AppGroup.defaults) -> Bool {
        isDue(
            lastVersionSeen: defaults.string(forKey: SharedKeys.lastVersionSeen),
            onboardingCompleted: defaults.bool(forKey: SharedKeys.hasCompletedOnboarding)
        )
    }

    /// Called once per launch, before anything reads the key. Records the user as up to
    /// date unless What's new is due and has something to show, which is what keeps a new
    /// install from ever seeing it. A due What's new is recorded when it appears
    /// (`recordSeen`) instead, so a launch that cannot show it (a dictation started from the
    /// keyboard) leaves it for the next.
    ///
    /// - Parameter deviceCanRunSmartModes: `SmartModeAvailability.deviceIsCapable`. On a
    ///   device that can never run Smart Modes What's new has no step (`steps`), so it is
    ///   recorded here and never appears: no empty screen, and nothing left due for good.
    public static func recordLaunch(deviceCanRunSmartModes: Bool,
                                    currentVersion: String = runningVersion,
                                    defaults: UserDefaults = AppGroup.defaults) {
        guard !isDue(defaults: defaults) || steps(deviceCanRunSmartModes: deviceCanRunSmartModes).isEmpty else {
            return
        }
        recordSeen(currentVersion: currentVersion, defaults: defaults)
    }

    /// Records What's new as seen: written when it appears, so it is shown once even if the
    /// app is closed halfway through.
    public static func recordSeen(currentVersion: String = runningVersion, defaults: UserDefaults = AppGroup.defaults) {
        let recorded = recordedVersion(
            lastVersionSeen: defaults.string(forKey: SharedKeys.lastVersionSeen),
            currentVersion: currentVersion
        )
        defaults.set(recorded, forKey: SharedKeys.lastVersionSeen)
    }
}
