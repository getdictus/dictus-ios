// DictusCore/AppleSpeechEngineChoice.swift
// "Apple (on-device)" as an engine the user picks on the Models screen, beside the
// downloaded Parakeet / Whisper / Nemotron models (Pierre, 2026-11-21).
import Foundation

/// Which engine the app dictates with: the downloaded model, or Apple's recognizer.
///
/// WHY A KEY OF ITS OWN and not an Apple identifier in `SharedKeys.activeModel`:
/// `activeModel` means "the downloaded model" to a dozen readers, the keyboard among
/// them (its pre-A14 gate, the Core ML warmth gate, the log header), and to the
/// last-model and delete rules of `ModelManager`. Keeping it as it is means picking
/// Apple changes none of them, and the app falls back to that model whenever Apple
/// cannot run (language changed to automatic detection, model not installed yet)
/// without anything to repair.
public enum SpeechEngineChoice: String, Equatable, Sendable {
    /// The downloaded model in `SharedKeys.activeModel`. The default: an absent key reads
    /// as this, so nothing changes for a user who never picks Apple.
    case downloadedModel = "model"
    /// Apple's on-device recognizer (`SpeechTranscriber`).
    case apple

    public static func read(from defaults: UserDefaults) -> SpeechEngineChoice {
        defaults.string(forKey: SharedKeys.speechEngineChoice).flatMap(Self.init(rawValue:)) ?? .downloadedModel
    }

    public static func write(_ choice: SpeechEngineChoice, to defaults: UserDefaults) {
        defaults.set(choice.rawValue, forKey: SharedKeys.speechEngineChoice)
        defaults.synchronize()
    }
}

/// Apple's on-device speech model for one locale, as `AssetInventory` reports it.
public enum AppleEngineAssetState: Equatable, Sendable {
    /// Not asked yet.
    case unknown
    /// Supported, not on the device: picking the engine asks iOS to install it.
    case notInstalled
    /// iOS is installing it; the fraction when `AssetInventory` reports one.
    case installing(fraction: Double?)
    /// On the device: the engine can transcribe with nothing to download.
    case installed
    /// The last install failed; picking again retries.
    case failed
}

/// Whether "Apple (on-device)" can be picked, and in what state its card is.
///
/// The whole rule, as a pure function so every combination is tested: iOS 26 or later
/// (`SpeechAnalyzer`, `SpeechTranscriber` and `AssetInventory` start there), and the
/// dictation language the user CHOSE listed in Apple's `supportedLocales` — the same
/// language rule as in-keyboard dictation (#992), never one detected from speech.
public enum AppleEngineAvailability: Equatable, Sendable {
    /// Greyed, with one explanation line.
    case unavailable(Reason)
    /// Selectable. Picking it installs Apple's model first (`assetState` says where that is).
    case needsAsset(AppleEngineAssetState)
    /// Selectable, and the model is installed: dictation can use it now.
    case ready(languageCode: String)

    public enum Reason: Equatable, Sendable {
        /// Older than iOS 26.
        case systemTooOld
        /// "Transcription language: automatic detection": no single language to give
        /// Apple's recognizer, which takes one locale.
        case autoDetect
        /// Apple does not list the chosen language.
        case languageNotCovered(String)
    }

    public var isSelectable: Bool {
        if case .unavailable = self { return false }
        return true
    }

    public var isReady: Bool {
        if case .ready = self { return true }
        return false
    }

    /// - Parameters:
    ///   - systemMajorVersion: the running iOS major version.
    ///   - mode / keyboardLanguageCode: the transcription language setting and the
    ///     keyboard language of the moment (`.followKeyboard` follows it).
    ///   - supportedLocales: Apple's `supportedLocales` as BCP-47 identifiers ("fr-FR").
    ///     Only the language subtag counts.
    ///   - assetState: the model for the resolved locale.
    public static func evaluate(systemMajorVersion: Int,
                                mode: TranscriptionLanguageMode,
                                keyboardLanguageCode: String,
                                supportedLocales: [String],
                                assetState: AppleEngineAssetState) -> AppleEngineAvailability {
        guard systemMajorVersion >= InKeyboardDictationRoute.minimumSystemMajorVersion else {
            return .unavailable(.systemTooOld)
        }
        switch InKeyboardLanguageEligibility.evaluate(mode: mode,
                                                      keyboardLanguageCode: keyboardLanguageCode,
                                                      supportedLocales: supportedLocales) {
        case .autoDetect:
            return .unavailable(.autoDetect)
        case .notCovered(let code):
            return .unavailable(.languageNotCovered(code))
        case .covered(let code):
            return assetState == .installed ? .ready(languageCode: code) : .needsAsset(assetState)
        }
    }
}

/// The engine a dictation in the app actually runs.
public enum EffectiveSpeechEngine: Equatable, Sendable {
    case apple(languageCode: String)
    case downloadedModel

    /// Apple only when the user picked it AND it is ready right now. Anything else
    /// (not picked, greyed after a language change, model not installed yet) dictates
    /// with the downloaded model, as before the choice existed.
    public static func resolve(choice: SpeechEngineChoice,
                               availability: AppleEngineAvailability) -> EffectiveSpeechEngine {
        guard choice == .apple, case .ready(let code) = availability else { return .downloadedModel }
        return .apple(languageCode: code)
    }
}

public enum AppleSpeechEngineIdentity {
    /// The name the app's coordinator and its logs give the engine while it is loaded,
    /// where a downloaded model has its catalogue identifier. Never written to
    /// `SharedKeys.activeModel`.
    public static let identifier = "apple-speechtranscriber"
}
