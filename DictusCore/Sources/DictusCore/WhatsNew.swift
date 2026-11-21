// DictusCore/Sources/DictusCore/WhatsNew.swift
// Who sees What's new, once per version (#685, #974).
import Foundation

/// What's new: after an update, the new version's release notes (`ReleaseNotes`), shown once,
/// at the first launch that can show them (#974). Settings reopens them at any time.
///
/// WHY IN DICTUSCORE: who is an existing user, and when the key is written, are rules, and
/// they are tested here.
///
/// HOW AN UPDATE IS TOLD FROM A NEW INSTALL (#685): `SharedKeys.lastVersionSeen` holds the
/// last version whose notes the user is up to date with. Before 2.0.0 the key did not exist,
/// so an absent key alone cannot say "new install". The other fact is
/// `hasCompletedOnboarding`: an existing user set it long ago, a new install has not. So the
/// first launch of an install that has NOT completed onboarding records the running version
/// straight away (`recordLaunch`), and its onboarding is never followed by What's new. An
/// install that HAS completed onboarding and is behind the running version is shown the
/// notes instead, and the key is written once they are on screen (`recordSeen`).
///
/// WHY THE 2.0.0 REPLAY CANNOT COME BACK: 2.0.0's What's new replayed the onboarding's
/// scenes, and that code is gone. What's new is now only a version's notes, and a version
/// without a `ReleaseNotes/<version>` folder is recorded at launch and shows nothing.
public enum WhatsNew {

    // MARK: - The rule

    /// Whether the running version's What's new is due.
    ///
    /// - Parameters:
    ///   - lastVersionSeen: `SharedKeys.lastVersionSeen`, nil when absent.
    ///   - onboardingCompleted: `SharedKeys.hasCompletedOnboarding`. False means a new
    ///     install, or one still in its onboarding.
    ///   - currentVersion: the running app's marketing version.
    public static func isDue(lastVersionSeen: String?, onboardingCompleted: Bool, currentVersion: String) -> Bool {
        onboardingCompleted && isOlder(lastVersionSeen, than: currentVersion)
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

    /// The value to write once the user is up to date: the later of what was stored and the
    /// running version. It never goes down, so a rollback to an older build cannot make an
    /// old What's new due again.
    public static func recordedVersion(lastVersionSeen: String?, currentVersion: String) -> String {
        guard let lastVersionSeen, isOlder(currentVersion, than: lastVersionSeen) else { return currentVersion }
        return lastVersionSeen
    }

    /// Whether `version` is older than `other`, comparing numbers part by part ("1.10.0"
    /// is newer than "1.9.0"). A missing version is older than any: every install from
    /// before the key existed.
    public static func isOlder(_ version: String?, than other: String) -> Bool {
        guard let version else { return true }
        return version.compare(other, options: .numeric) == .orderedAscending
    }

    // MARK: - Persistence

    /// The running app's marketing version, "0" if the bundle has none. Never "?": it is
    /// compared as a version, and a placeholder would sort above every number.
    public static var runningVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    /// Whether What's new is due for this install, read from the App Group.
    public static func isDue(currentVersion: String = runningVersion,
                             defaults: UserDefaults = AppGroup.defaults) -> Bool {
        isDue(
            lastVersionSeen: defaults.string(forKey: SharedKeys.lastVersionSeen),
            onboardingCompleted: defaults.bool(forKey: SharedKeys.hasCompletedOnboarding),
            currentVersion: currentVersion
        )
    }

    /// Called once per launch, before anything reads the key. Records the user as up to
    /// date unless What's new is due and has notes to show, which is what keeps a new
    /// install from ever seeing it. A due What's new is recorded when it appears
    /// (`recordSeen`) instead, so a launch that cannot show it (a dictation started from the
    /// keyboard) leaves it for the next.
    ///
    /// - Parameter hasNotes: the running version has release notes (`ReleaseNotes.current`).
    ///   A version without any is recorded here and shows nothing, so nothing stays due.
    public static func recordLaunch(hasNotes: Bool,
                                    currentVersion: String = runningVersion,
                                    defaults: UserDefaults = AppGroup.defaults) {
        guard !isDue(currentVersion: currentVersion, defaults: defaults) || !hasNotes else { return }
        recordSeen(currentVersion: currentVersion, defaults: defaults)
    }

    /// Records What's new as seen: written when it appears, so it is shown once even if the
    /// app is closed right away.
    public static func recordSeen(currentVersion: String = runningVersion, defaults: UserDefaults = AppGroup.defaults) {
        let recorded = recordedVersion(
            lastVersionSeen: defaults.string(forKey: SharedKeys.lastVersionSeen),
            currentVersion: currentVersion
        )
        defaults.set(recorded, forKey: SharedKeys.lastVersionSeen)
    }
}
