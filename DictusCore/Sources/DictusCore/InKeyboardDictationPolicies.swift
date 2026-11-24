// DictusCore/InKeyboardDictationPolicies.swift
// The small rules around in-keyboard dictation (#992): what an interruption does, and
// when the one-time explanation shows.
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
        /// The capture died before the dictation began: hand the tap to
        /// `DictationStartSafetyNet`, which opens the app by URL.
        case openApp
    }

    /// Below this, a recording is a tap and a breath, not a sentence.
    public static let minimumSeconds: Double = 0.5

    public static func action(for event: Event, recordedSeconds: Double) -> Action {
        switch event {
        case .inputDeviceLost:
            return .continue
        case .interruptionBegan:
            return recordedSeconds >= minimumSeconds ? .finishKeepingText : .discard
        case .captureEnded:
            // A capture that dies before the dictation began is not the user's stop and
            // not a call they can see: they tapped and got nothing (device, 2026-11-23
            // 13:39:21, `context-interrupted` at 660 ms, `seconds=0.0`, back to idle).
            // The tap goes to the start safety net, which opens the app.
            return recordedSeconds >= minimumSeconds ? .finishKeepingText : .openApp
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

/// The language side of "Dictate in the keyboard" (Pierre, 2026-11-21): activation by
/// the language the user CHOSE, read against Apple's `SpeechTranscriber.supportedLocales`
/// (`AppleSpeechLanguage`, shared with the app's Apple engine since #1036), never by
/// detecting what they speak.
///
/// The user's own choice (the toggle, absent = on) is stored apart from this. The setting
/// is ON in effect only when both hold, so changing to a language Apple does not cover
/// turns it off, and changing back turns it on again only if the user had not turned it
/// off themselves.
extension AppleSpeechLanguage {
    public var isCovered: Bool {
        if case .covered = self { return true }
        return false
    }

    /// The value the app writes to the App Group (`SharedKeys.inKeyboardLanguageEligibility`)
    /// for the greyed setting and its explanation line.
    public var storedValue: String {
        switch self {
        case .covered: return "covered"
        case .notCovered: return "notCovered"
        case .autoDetect: return "autoDetect"
        case .speechTranscriberUnavailable: return "speechTranscriberUnavailable"
        }
    }
}

extension InKeyboardDictationRoute {
    /// The setting as the user sees it and the keyboard applies it.
    public static func isEffectivelyOn(userChoice: Bool?, language: AppleSpeechLanguage) -> Bool {
        (userChoice ?? defaultEnabled) && language.isCovered
    }
}
