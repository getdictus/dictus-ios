// DictusCore/ActiveSpeechEngine.swift
// The engine Dictus dictates with now, for every reader that names it (#1083).
import Foundation

/// The engine a dictation runs with now, as the App Group says: Apple's recognizer when the
/// user picked it and it is ready, otherwise the downloaded model.
///
/// WHY THIS EXISTS (#1083): `SharedKeys.activeModel` names the downloaded model even when
/// Apple is picked (`SpeechEngineChoice` says why). Home's "Active model" card, the Debug
/// export header and the voice-note queue read that key as "the engine", so after picking
/// Apple they kept saying Parakeet while Apple transcribed. They read this instead.
///
/// The rule is `EffectiveSpeechEngine.resolve`, the one `ensureEngineReady` dictates with;
/// Apple's side comes from `AppleEngineReadinessRecord`, the last reading DictusApp took.
public struct ActiveSpeechEngine: Equatable, Sendable {
    public let engine: SpeechEngine
    /// The catalogue identifier of the downloaded model, or
    /// `AppleSpeechEngineIdentity.identifier` for Apple's.
    public let identifier: String

    public static let apple = ActiveSpeechEngine(engine: .apple, identifier: AppleSpeechEngineIdentity.identifier)

    public init(engine: SpeechEngine, identifier: String) {
        self.engine = engine
        self.identifier = identifier
    }

    /// - Parameters:
    ///   - choice: the engine the user picked.
    ///   - appleAvailability: where Apple's engine stands for the dictation language.
    ///   - downloadedModel: `SharedKeys.activeModel`, nil when no model was elected.
    /// - Returns: nil when there is nothing to dictate with: no downloaded model, and
    ///   Apple not picked or not ready.
    public static func resolve(choice: SpeechEngineChoice, appleAvailability: AppleEngineAvailability,
                               downloadedModel: String?) -> ActiveSpeechEngine? {
        if case .apple = EffectiveSpeechEngine.resolve(choice: choice, availability: appleAvailability) {
            return .apple
        }
        guard let downloadedModel, !downloadedModel.isEmpty else { return nil }
        // Same fallback as `ensureEngineReady`: an identifier the catalogue no longer
        // knows is loaded as a Whisper model.
        return ActiveSpeechEngine(engine: ModelInfo.forIdentifier(downloadedModel)?.engine ?? .whisperKit,
                                  identifier: downloadedModel)
    }

    /// The same rule read from the App Group.
    ///
    /// - Parameter dictationLanguageCode: the language a dictation would be given now;
    ///   nil under automatic detection. Defaults to the App Group's.
    public static func current(defaults: UserDefaults = AppGroup.defaults,
                               dictationLanguageCode: String? = AppleSpeechLanguage.activeDictationLanguageCode())
        -> ActiveSpeechEngine? {
        resolve(choice: SpeechEngineChoice.read(from: defaults),
                appleAvailability: AppleEngineReadinessRecord.availability(in: defaults,
                                                                           dictationLanguageCode: dictationLanguageCode),
                downloadedModel: defaults.string(forKey: SharedKeys.activeModel))
    }
}
