// DictusCore/InKeyboardDictationPolicies.swift
// The small rules around in-keyboard dictation (#992): what an interruption does, when
// the one-time explanation shows, and how the setting's default is applied on update.
import Foundation

/// What a dictation running in the keyboard does when something takes the audio away.
///
/// A call, Siri, or a headset leaving all end WebKit's capture or interrupt the session.
/// The rule is the same for all: keep what was said and transcribe it, unless almost
/// nothing was recorded, in which case end quietly rather than insert noise.
public enum InKeyboardInterruptionPolicy {

    public enum Event: String, Sendable {
        /// `AVAudioSession.interruptionNotification` began (a call, Siri, an alarm).
        case interruptionBegan
        /// The page's capture ended by itself (track ended, context interrupted).
        case captureEnded
        /// The input device went away (AirPods taken out). iOS moves the route to the
        /// built-in microphone; the capture continues on it.
        case inputDeviceLost
    }

    public enum Action: String, Sendable {
        /// Stop and transcribe what was recorded: the text so far is kept.
        case finishKeepingText
        /// Stop and drop it: too short to be speech.
        case discard
        /// Nothing to do.
        case `continue`
    }

    /// Below this, a recording is a tap and a breath, not a sentence.
    public static let minimumSeconds: Double = 0.5

    public static func action(for event: Event, recordedSeconds: Double) -> Action {
        switch event {
        case .inputDeviceLost:
            return .continue
        case .interruptionBegan, .captureEnded:
            return recordedSeconds >= minimumSeconds ? .finishKeepingText : .discard
        }
    }
}

/// The one-time explanation, shown in the keyboard the first time it dictates with the
/// app closed, so a user knows why the result came from Apple's dictation.
public enum InKeyboardFirstUse {
    public static func shouldShow(in defaults: UserDefaults) -> Bool {
        !defaults.bool(forKey: SharedKeys.inKeyboardFirstUseShown)
    }

    public static func markShown(in defaults: UserDefaults) {
        defaults.set(true, forKey: SharedKeys.inKeyboardFirstUseShown)
    }
}

/// How "Dictate in the keyboard" is on or off after the update ships. One constant.
public enum InKeyboardDictationDefault {

    public enum Policy: String, Sendable {
        /// On for everyone, existing users included, from the update on.
        case onForEveryone
        /// On for new installs; existing users start off and are asked once in the app.
        case newInstallsOnly
    }

    /// `.newInstallsOnly`, decided by Pierre on 2026-11-21 (PR #992).
    ///
    /// WHY: existing users chose Dictus for its own model. With the setting on, a tap with
    /// the app closed gives Apple's dictation instead, with a different accuracy and the
    /// microphone indicator coming from the keyboard. Asking them once ("Turn on" /
    /// "Later") makes that change their choice and announces it; new users never knew the
    /// app switch, so they start with it on. Changing this one line switches the behaviour.
    public static let policy: Policy = .newInstallsOnly

    public struct LaunchResolution: Equatable, Sendable {
        /// The value to write to the setting now, or nil to leave it.
        public let write: Bool?
        /// Whether the app should ask the existing user once.
        public let prompt: Bool
    }

    /// What the app does at launch. `storedValue` is the setting as stored (nil when the
    /// user never touched it); `onboardingCompleted` tells an existing user from a new
    /// install at the first launch of the update.
    public static func resolveAtLaunch(policy: Policy, storedValue: Bool?, onboardingCompleted: Bool,
                                       promptPending: Bool) -> LaunchResolution {
        guard storedValue == nil else {
            // The user (or an earlier launch) decided; only an unanswered prompt remains.
            return LaunchResolution(write: nil, prompt: promptPending)
        }
        switch policy {
        case .onForEveryone:
            return LaunchResolution(write: nil, prompt: false)
        case .newInstallsOnly:
            return onboardingCompleted
                ? LaunchResolution(write: false, prompt: true)
                : LaunchResolution(write: true, prompt: false)
        }
    }
}
