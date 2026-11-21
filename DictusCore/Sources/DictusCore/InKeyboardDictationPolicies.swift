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

/// Whether the chosen dictation language lets the keyboard dictate with the app closed
/// (Pierre, 2026-11-21): activation by the language the user chose, checked against
/// Apple's `SpeechTranscriber.supportedLocales`, never by detecting what they speak.
///
/// The user's own choice (the "Dictate in the keyboard" toggle, absent = on) is stored
/// apart from this. The setting is ON in effect only when both hold, so changing to a
/// language Apple does not cover turns it off, and changing back turns it on again only
/// if the user had not turned it off themselves.
public enum InKeyboardLanguageEligibility: Equatable, Sendable {
    /// Apple lists the chosen language.
    case covered(String)
    /// Apple does not list it: the setting is off in effect and shown greyed.
    case notCovered(String)
    /// Automatic detection: no single language to dictate in, so off in effect.
    case autoDetect
    /// The iPhone or its iOS has no `SpeechTranscriber` (`isAvailable == false`, or before
    /// iOS 26): off in effect whatever the language. No fallback to `DictationTranscriber`
    /// (Pierre, 2026-11-21).
    case speechTranscriberUnavailable

    public var isCovered: Bool {
        if case .covered = self { return true }
        return false
    }

    /// The value the app writes to the App Group for its UI.
    public var storedValue: String {
        switch self {
        case .covered: return "covered"
        case .notCovered: return "notCovered"
        case .autoDetect: return "autoDetect"
        case .speechTranscriberUnavailable: return "speechTranscriberUnavailable"
        }
    }

    /// - Parameters:
    ///   - speechTranscriberAvailable: `SpeechTranscriber.isAvailable` on iOS 26 and
    ///     later, false before. Checked first: without it no language is covered.
    ///   - supportedLocales: `SpeechTranscriber.supportedLocales`, BCP 47 identifiers.
    public static func evaluate(mode: TranscriptionLanguageMode, keyboardLanguageCode: String,
                                speechTranscriberAvailable: Bool,
                                supportedLocales: [String]) -> InKeyboardLanguageEligibility {
        guard speechTranscriberAvailable else { return .speechTranscriberUnavailable }
        guard let code = InKeyboardDictationRoute.dictationLanguageCode(mode: mode, keyboardLanguageCode: keyboardLanguageCode)
        else { return .autoDetect }
        return InKeyboardDictationRoute.isLanguageCovered(code, bySupportedLocales: supportedLocales)
            ? .covered(code) : .notCovered(code)
    }

    /// The setting as the user sees it and the keyboard applies it.
    public static func isEffectivelyOn(userChoice: Bool?, eligibility: InKeyboardLanguageEligibility) -> Bool {
        (userChoice ?? InKeyboardDictationRoute.defaultEnabled) && eligibility.isCovered
    }
}
