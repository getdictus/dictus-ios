// DictusCore/InKeyboardDictationRoute.swift
import Foundation

/// Where a mic tap goes once the keyboard has waited for DictusApp to answer (spike).
///
/// The keyboard posts its Darwin start notification and waits 500 ms. A warm app answers
/// within that window and records in the background; nothing changes for it. A cold app
/// does not answer, and today the keyboard then opens `dictus://dictate`, which is the
/// app switch this spike tries to remove.
///
/// The experiment replaces only that last step: behind a setting, and only where the
/// keyboard can transcribe on the device by itself, it records through a hidden web view
/// and transcribes with Apple's on-device `SpeechTranscriber`. Every other combination
/// keeps today's URL fallback, so the setting off means the app behaves exactly as
/// before.
public enum InKeyboardDictationRoute: String, Equatable, Sendable {
    /// The app answered the Darwin notification: it records, the keyboard does nothing.
    case appIsRecording
    /// Cold app, experiment usable: dictate inside the keyboard.
    case inKeyboard
    /// Cold app, experiment off or unusable: open the app through the URL, as today.
    case openAppURL
    /// Cold app, and the microphone is refused for Dictus: neither path can record, so
    /// the keyboard says so in one line and opens nothing.
    case microphoneDenied

    /// The microphone permission as the keyboard reads it (DictusApp's, which WebKit's
    /// capture is attributed to).
    public enum MicrophonePermission: String, Sendable {
        case granted
        case denied
        /// Never asked: only the app can show the system prompt, so the URL path goes.
        case undetermined
    }

    /// The whole rule, as a pure function so every combination is tested.
    ///
    /// - Parameters:
    ///   - settingEnabled: "Experiments > Dictate in the keyboard".
    ///   - appAnswered: the app moved the status past `.requested` within the wait.
    ///   - systemMajorVersion: the running iOS major version.
    ///   - localeInstalled: whether the on-device speech model for the dictation
    ///     language is installed, per `AssetInventory`. `nil` means the check has not
    ///     answered yet, which is treated as not installed: the fallback is always safe,
    ///     a dictation into a missing model is not.
    ///   - hasFullAccess: the keyboard's Full Access. Without it the toolbar shows the
    ///     Full Access bar instead of the mic, so this is defensive; it routes to today's
    ///     path, which has its own handling.
    ///   - microphone: the microphone permission.
    ///   - sessionOwner: who claimed the session (`DictationSessionClaim`). The app
    ///     owning it means the app records, whatever the keyboard's own status says: the
    ///     route and the claim must agree (device, 2026-11-23 12:55:39, `route=inKeyboard`
    ///     with `owner=app`, and nobody recorded).
    public static func decide(
        settingEnabled: Bool,
        appAnswered: Bool,
        systemMajorVersion: Int,
        localeInstalled: Bool?,
        hasFullAccess: Bool = true,
        microphone: MicrophonePermission = .granted,
        sessionOwner: DictationSessionClaim.Owner? = nil
    ) -> InKeyboardDictationRoute {
        if appAnswered || sessionOwner == .app { return .appIsRecording }
        guard settingEnabled,
              systemMajorVersion >= AppleEngineAvailability.minimumSystemMajorVersion,
              localeInstalled == true,
              hasFullAccess
        else { return .openAppURL }
        switch microphone {
        case .granted: return .inKeyboard
        case .undetermined: return .openAppURL
        case .denied: return .microphoneDenied
        }
    }

    /// Full Access as the route reads it: the current controller's answer, else the one
    /// read at the tap.
    ///
    /// WHY: iOS tears keyboard controllers down and rebuilds them at any moment (#281). On
    /// the device (2026-11-23 10:32:01) the controller the keyboard held was deinited
    /// between the tap and the end of the wait; read through it, Full Access came back
    /// false and the tap opened the app (`route=openAppURL`) although the keyboard had
    /// just shown the mic, which it only does with Full Access.
    public static func fullAccess(current: Bool?, atTap: Bool?) -> Bool {
        current ?? atTap ?? false
    }

    /// Whether the setting is on when the user never touched it: on, for every user, new
    /// installs and existing users after the update alike.
    ///
    /// WHY: Pierre decided on 2026-11-21 (PR #992) that every user should benefit from
    /// dictating without the app switch, so nothing is asked and nothing is written; a
    /// user who turns the setting off keeps it off. This replaced an earlier
    /// `.newInstallsOnly` plan with a one-time question, which is gone with it.
    public static let defaultEnabled = true

    /// The setting, read from the App Group. An absent key reads as `defaultEnabled`;
    /// the toggle writes an explicit value either way.
    public static func isSettingEnabled(in defaults: UserDefaults) -> Bool {
        guard defaults.object(forKey: SharedKeys.inKeyboardDictationEnabled) != nil else { return defaultEnabled }
        return defaults.bool(forKey: SharedKeys.inKeyboardDictationEnabled)
    }

    /// The speech locales the app reserves and installs ahead of the keyboard's first
    /// cold tap, in priority order: the dictation language, then the keyboard language
    /// when it differs (the toolbar switches it, and in follow mode the dictation follows).
    /// Nothing under automatic detection, where the keyboard does not dictate.
    public static func speechLocalesToReserve(transcriptionMode: TranscriptionLanguageMode,
                                              keyboardLanguageCode: String,
                                              deviceLocaleIdentifier: String) -> [String] {
        // The dictation language the user CHOSE, never one detected from speech (Pierre,
        // 2026-11-21); nil under automatic detection.
        guard let dictation = transcriptionMode.resolvedLanguageCode(keyboardLanguageCode: keyboardLanguageCode) else { return [] }
        var result: [String] = []
        for code in [dictation, keyboardLanguageCode] {
            let identifier = AppleSpeechLanguage.localeIdentifier(languageCode: code, deviceLocaleIdentifier: deviceLocaleIdentifier)
            if !result.contains(identifier) { result.append(identifier) }
        }
        return result
    }
}
