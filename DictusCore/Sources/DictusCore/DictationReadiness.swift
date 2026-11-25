// DictusCore/DictationReadiness.swift
// Whether Dictus can dictate at all: a downloaded model, or Apple's engine (#1057).
import Foundation

/// Whether there is an engine to dictate with right now.
///
/// WHY THIS EXISTS (#1057): until 2.0.3 the only engine was a downloaded model, so every
/// gate asked `SharedKeys.modelReady` ("No model downloaded…", Home's mic, the launch
/// preload, voice notes). #1036 added Apple's on-device recognizer as an engine of its
/// own, and a user who picked it and has no downloaded model was still refused by all of
/// them. This is the one rule those gates read instead, so they cannot drift apart.
///
/// The rule: a downloaded model is ready, OR Apple's engine is the choice AND it is ready
/// for the dictation language (iOS 26+, `SpeechTranscriber` available, language covered,
/// model installed: `AppleEngineAvailability.ready`). For a user with a downloaded model
/// the answer is `modelReady`, exactly as before.
public enum DictationReadiness {

    /// - Parameters:
    ///   - modelReady: `SharedKeys.modelReady`: a downloaded model is on disk and elected.
    ///   - choice: `SpeechEngineChoice`, the engine the user picked.
    ///   - appleAvailability: where Apple's engine stands for the dictation language.
    public static func canDictate(modelReady: Bool, choice: SpeechEngineChoice,
                                  appleAvailability: AppleEngineAvailability) -> Bool {
        modelReady || dictatesWithAppleOnly(modelReady: modelReady, choice: choice,
                                            appleAvailability: appleAvailability)
    }

    /// True when the only engine there is, is Apple's: no downloaded model, Apple picked
    /// and ready. The case every pre-#1057 gate refused.
    public static func dictatesWithAppleOnly(modelReady: Bool, choice: SpeechEngineChoice,
                                             appleAvailability: AppleEngineAvailability) -> Bool {
        !modelReady && EffectiveSpeechEngine.resolve(choice: choice, availability: appleAvailability) != .downloadedModel
    }

    /// The same rule read from the App Group, for the gates that cannot await Apple's
    /// framework. Apple's side comes from `AppleEngineReadinessRecord`, the last reading
    /// DictusApp took, matched against the dictation language now.
    ///
    /// - Parameter dictationLanguageCode: the language a dictation would be given now;
    ///   nil under automatic detection. Defaults to the App Group's.
    public static func canDictate(defaults: UserDefaults = AppGroup.defaults,
                                  dictationLanguageCode: String? = AppleSpeechLanguage.activeDictationLanguageCode()) -> Bool {
        canDictate(modelReady: defaults.bool(forKey: SharedKeys.modelReady),
                   choice: SpeechEngineChoice.read(from: defaults),
                   appleAvailability: AppleEngineReadinessRecord.availability(in: defaults,
                                                                              dictationLanguageCode: dictationLanguageCode))
    }
}

/// The last time DictusApp read Apple's availability, kept in the App Group.
///
/// WHY A RECORD and not a fresh reading: the fresh one is `AppleEngineAssets.availability()`,
/// async, and it needs Apple's Speech framework. The keyboard, Home's mic and the
/// synchronous start of a dictation cannot await it. What they need is narrower: was Apple
/// ready for THIS language the last time the app looked. The language is part of the
/// record, so a language change (to another language, or to automatic detection) reads as
/// "not ready" at once, before the app looks again.
///
/// THE ACCEPTED STALENESS: iOS removing Apple's installed model between two readings
/// leaves the record saying ready. A dictation then starts, `ensureEngineReady` reads the
/// availability fresh, finds Apple not ready, and fails on the missing downloaded model.
public enum AppleEngineReadinessRecord {

    /// Store a fresh reading: the language when Apple is ready, nothing otherwise.
    public static func write(_ availability: AppleEngineAvailability, to defaults: UserDefaults) {
        if case .ready(let code) = availability {
            defaults.set(code, forKey: SharedKeys.appleEngineReadyLanguage)
        } else {
            defaults.removeObject(forKey: SharedKeys.appleEngineReadyLanguage)
        }
    }

    /// The recorded language Apple was ready for, if any.
    public static func readyLanguage(in defaults: UserDefaults) -> String? {
        defaults.string(forKey: SharedKeys.appleEngineReadyLanguage)
    }

    /// The availability the record stands for, for `dictationLanguageCode`: ready when the
    /// record names that language, otherwise not known to be ready.
    public static func availability(readyLanguage: String?, dictationLanguageCode: String?) -> AppleEngineAvailability {
        guard let readyLanguage, let dictationLanguageCode, readyLanguage == dictationLanguageCode else {
            return .needsAsset(.unknown)
        }
        return .ready(languageCode: readyLanguage)
    }

    public static func availability(in defaults: UserDefaults, dictationLanguageCode: String?) -> AppleEngineAvailability {
        availability(readyLanguage: readyLanguage(in: defaults), dictationLanguageCode: dictationLanguageCode)
    }
}
