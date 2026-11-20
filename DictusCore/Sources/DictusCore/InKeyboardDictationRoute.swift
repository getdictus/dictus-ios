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

    /// First iOS major version with `SpeechAnalyzer`, `SpeechTranscriber` and
    /// `AssetInventory`.
    public static let minimumSystemMajorVersion = 26

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
    public static func decide(
        settingEnabled: Bool,
        appAnswered: Bool,
        systemMajorVersion: Int,
        localeInstalled: Bool?
    ) -> InKeyboardDictationRoute {
        if appAnswered { return .appIsRecording }
        guard settingEnabled,
              systemMajorVersion >= minimumSystemMajorVersion,
              localeInstalled == true
        else { return .openAppURL }
        return .inKeyboard
    }

    /// Whether the setting is on when the user never touched it. On for this spike build:
    /// the test is to install and dictate without ever opening the app, so the keyboard
    /// cannot wait for a toggle only the app shows.
    public static let defaultEnabled = true

    /// The setting, read from the App Group. An absent key reads as `defaultEnabled`;
    /// the toggle writes an explicit value either way.
    public static func isSettingEnabled(in defaults: UserDefaults) -> Bool {
        guard defaults.object(forKey: SharedKeys.inKeyboardDictationEnabled) != nil else { return defaultEnabled }
        return defaults.bool(forKey: SharedKeys.inKeyboardDictationEnabled)
    }

    /// The full locale to ask the speech model for, from a bare dictation language.
    ///
    /// WHY not `Locale(identifier: "fr")`: `supportedLocale(equivalentTo:)` resolves a bare
    /// language to an arbitrary region (measured 2026-11-19 on the iOS 26.5 simulator:
    /// "fr" gave `fr_BE`), and the installed model is per region. The device's own region
    /// wins when it speaks that language; otherwise the language's main region.
    public static func speechLocaleIdentifier(languageCode: String, deviceLocaleIdentifier: String) -> String {
        let device = Locale(identifier: deviceLocaleIdentifier)
        if device.language.languageCode?.identifier == languageCode,
           let region = device.region?.identifier {
            return "\(languageCode)-\(region)"
        }
        let mainRegion = ["fr": "FR", "en": "US", "es": "ES", "de": "DE", "it": "IT", "pt": "BR"]
        guard let region = mainRegion[languageCode] else { return languageCode }
        return "\(languageCode)-\(region)"
    }

    /// The major component of `UIDevice.current.systemVersion` ("26.5" → 26).
    /// An unreadable string gives 0, which routes to the fallback.
    public static func majorVersion(of systemVersion: String) -> Int {
        Int(systemVersion.split(separator: ".").first ?? "") ?? 0
    }
}
