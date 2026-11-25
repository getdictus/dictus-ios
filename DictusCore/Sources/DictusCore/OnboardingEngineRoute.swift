// DictusCore/OnboardingEngineRoute.swift
// Which engine the onboarding sets up for the language the user confirmed (#1057).
import Foundation

/// The engine the onboarding sets up once the language step is confirmed (#1057, PR 2).
///
/// - `apple`: the language is covered by Apple's on-device model, so confirming the
///   language asks iOS for that model (`AssetInventory`) and Dictus downloads nothing.
///   No "Keep Dictus open" popup either: that popup is about Dictus's own download.
/// - `downloadedModel`: today's route, unchanged: the recommended model for the language
///   and this device (`ModelInfo.recommendedIdentifier(forSpokenLanguage:on:)`) downloads.
///
/// WHY A RULE IN DICTUSCORE: the app target has no test bundle, and each input below is a
/// case a user can be in. The app only reads the facts (`AppleEngineAssets.availability()`,
/// the device, `ModelManager`) and does what the route says.
public enum OnboardingEngineRoute: Equatable, Sendable {
    /// Apple's model dictates. `needsInstall` is false when iOS already has the model for
    /// this language (it may come with the iPhone's own dictation), so nothing waits.
    case apple(languageCode: String, needsInstall: Bool)
    /// The recommended Dictus model downloads, as before #1057.
    case downloadedModel

    /// The route for the language the user just confirmed.
    ///
    /// Apple only when every one of these holds; any other case keeps today's download:
    /// - `appleAvailability` is selectable: iOS 26+, `SpeechTranscriber` available, and the
    ///   dictation language in Apple's `supportedLocales` as read on the iPhone (never a
    ///   hard-coded list). Automatic detection is unavailable there: Apple does not detect.
    /// - The spoken language has a Dictus keyboard (Pierre, 2026-11-25). A spoken language
    ///   without one (Italian, Japanese…) dictates in automatic detection
    ///   (`LanguageSetup.transcriptionMode`), so it takes today's route even where Apple
    ///   covers it.
    /// - The keyboard can dictate with Apple on this iPhone. Before A14 the keyboard only
    ///   dictates with Parakeet active (`supportsKeyboardDictation(activeModel:)`), and
    ///   whether Apple's daemon transcribes for a backgrounded app there is unmeasured
    ///   (#1065). An Apple-only iPhone 11 would get a keyboard whose mic never works, so it
    ///   downloads Parakeet as before.
    /// - The recommended model is not already ready. A second run of the onboarding over a
    ///   working model changes nothing for that user.
    /// - Apple's model is not in a failed install state.
    ///
    /// `dictationLanguageCode` is the language Apple would dictate in, read from the
    /// settings the language step just wrote: `needsAsset` carries no language.
    public static func decide(spokenLanguageHasDictusKeyboard: Bool,
                              keyboardDictatesWithApple: Bool,
                              recommendedModelReady: Bool,
                              dictationLanguageCode: String? = AppleSpeechLanguage.activeDictationLanguageCode(),
                              appleAvailability: AppleEngineAvailability) -> OnboardingEngineRoute {
        guard spokenLanguageHasDictusKeyboard, keyboardDictatesWithApple, !recommendedModelReady else {
            return .downloadedModel
        }
        switch appleAvailability {
        case .ready(let code):
            return .apple(languageCode: code, needsInstall: false)
        case .needsAsset(.failed), .unavailable:
            return .downloadedModel
        case .needsAsset:
            guard let dictationLanguageCode else { return .downloadedModel }
            return .apple(languageCode: dictationLanguageCode, needsInstall: true)
        }
    }

    /// The route once Apple's install has ended, read again from a fresh availability.
    ///
    /// WHY A FALLBACK AND NOT A RETRY: an install that failed (no network, iOS refused the
    /// reservation, the model not ready after "done") must not block the onboarding. The
    /// user gets today's route, the recommended model's download, and the preparation step
    /// shows it with its own retry.
    public static func afterAppleInstall(succeeded: Bool,
                                         appleAvailability: AppleEngineAvailability) -> OnboardingEngineRoute {
        guard succeeded, case .ready(let code) = appleAvailability else { return .downloadedModel }
        return .apple(languageCode: code, needsInstall: false)
    }

    /// Whether this route dictates with Apple's model.
    public var isApple: Bool {
        if case .apple = self { return true }
        return false
    }
}
