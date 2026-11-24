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

/// The chosen dictation language read against Apple's `SpeechTranscriber`.
///
/// Activation by the language the user CHOSE, checked against Apple's
/// `supportedLocales`, never by detecting what they speak (Pierre, 2026-11-21).
public enum AppleSpeechLanguage: Equatable, Sendable {
    /// Apple lists the chosen language.
    case covered(String)
    /// Apple does not list it.
    case notCovered(String)
    /// Automatic detection: no single language to give a recognizer that takes one locale.
    case autoDetect
    /// The iPhone or its iOS has no `SpeechTranscriber` (`isAvailable == false`, or before
    /// iOS 26), whatever the language. No fallback to `DictationTranscriber` (Pierre,
    /// 2026-11-21).
    case speechTranscriberUnavailable

    /// - Parameters:
    ///   - speechTranscriberAvailable: `SpeechTranscriber.isAvailable` on iOS 26 and
    ///     later, false before. Checked first: without it no language is covered.
    ///   - supportedLocales: `SpeechTranscriber.supportedLocales`, BCP 47 identifiers.
    public static func evaluate(mode: TranscriptionLanguageMode, keyboardLanguageCode: String,
                                speechTranscriberAvailable: Bool,
                                supportedLocales: [String]) -> AppleSpeechLanguage {
        guard speechTranscriberAvailable else { return .speechTranscriberUnavailable }
        guard let code = mode.resolvedLanguageCode(keyboardLanguageCode: keyboardLanguageCode) else {
            return .autoDetect
        }
        return isLanguageCovered(code, bySupportedLocales: supportedLocales) ? .covered(code) : .notCovered(code)
    }

    /// The dictation language Apple's recognizer is given, read from the App Group: an
    /// explicit transcription language, or the keyboard language in "follow the keyboard"
    /// mode. Nil under automatic detection.
    public static func activeDictationLanguageCode() -> String? {
        TranscriptionLanguageMode.active.resolvedLanguageCode(keyboardLanguageCode: SupportedLanguage.active.rawValue)
    }

    /// Whether Apple's recognizer lists the language at all, from its `supportedLocales`
    /// identifiers ("zh-CN", "fr-CA", …). Only the language subtag counts; the region is
    /// chosen by `localeIdentifier`.
    public static func isLanguageCovered(_ languageCode: String, bySupportedLocales identifiers: [String]) -> Bool {
        identifiers.contains { identifier in
            identifier.split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map(String.init) == languageCode
        }
    }

    /// The full locale to ask the speech model for, from a bare dictation language.
    ///
    /// WHY not `Locale(identifier: "fr")`: `supportedLocale(equivalentTo:)` resolves a bare
    /// language to an arbitrary region (measured 2026-11-19 on the iOS 26.5 simulator:
    /// "fr" gave `fr_BE`), and the installed model is per region. The device's own region
    /// wins when it speaks that language; otherwise the language's main region.
    public static func localeIdentifier(languageCode: String, deviceLocaleIdentifier: String) -> String {
        let device = Locale(identifier: deviceLocaleIdentifier)
        if device.language.languageCode?.identifier == languageCode,
           let region = device.region?.identifier {
            return "\(languageCode)-\(region)"
        }
        // The region Apple's SpeechTranscriber lists first for each language it supports
        // (`supportedLocales`, macOS 26 / iOS 26). Chinese: mainland by default; a device
        // set to zh-TW or zh-HK gets its own region from the branch above.
        let mainRegion = ["fr": "FR", "en": "US", "es": "ES", "de": "DE", "it": "IT", "pt": "BR",
                          "ja": "JP", "ko": "KR", "zh": "CN", "yue": "CN", "hi": "IN", "bn": "IN",
                          "gu": "IN", "kn": "IN", "ml": "IN", "mr": "IN", "ne": "IN", "pa": "IN",
                          "ta": "IN", "te": "IN", "ur": "IN"]
        guard let region = mainRegion[languageCode] else { return languageCode }
        return "\(languageCode)-\(region)"
    }
}

/// Whether "Apple (on-device)" can be picked, and in what state its card is.
///
/// The whole rule, as a pure function so every combination is tested: iOS 26 or later
/// (`SpeechAnalyzer`, `SpeechTranscriber` and `AssetInventory` start there), Apple's
/// `SpeechTranscriber` available on this iPhone (no fallback to `DictationTranscriber`,
/// Pierre, 2026-11-21), and the dictation language the user CHOSE listed in its
/// `supportedLocales`.
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
        /// iOS 26 or later, but `SpeechTranscriber.isAvailable` is false on this iPhone.
        case speechTranscriberUnavailable
        /// "Transcription language: automatic detection": no single language to give
        /// Apple's recognizer, which takes one locale.
        case autoDetect
        /// Apple does not list the chosen language.
        case languageNotCovered(String)
    }

    /// First iOS major version with `SpeechAnalyzer`, `SpeechTranscriber` and
    /// `AssetInventory`.
    public static let minimumSystemMajorVersion = 26

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
    ///   - language: the chosen dictation language read against Apple's `SpeechTranscriber`.
    ///   - assetState: the model for the resolved locale.
    public static func evaluate(systemMajorVersion: Int,
                                language: AppleSpeechLanguage,
                                assetState: AppleEngineAssetState) -> AppleEngineAvailability {
        guard systemMajorVersion >= minimumSystemMajorVersion else {
            return .unavailable(.systemTooOld)
        }
        switch language {
        case .speechTranscriberUnavailable:
            return .unavailable(.speechTranscriberUnavailable)
        case .autoDetect:
            return .unavailable(.autoDetect)
        case .notCovered(let code):
            return .unavailable(.languageNotCovered(code))
        case .covered(let code):
            return assetState == .installed ? .ready(languageCode: code) : .needsAsset(assetState)
        }
    }

    /// The major component of `UIDevice.current.systemVersion` ("26.5" → 26).
    /// An unreadable string gives 0, which greys the card.
    public static func majorVersion(of systemVersion: String) -> Int {
        Int(systemVersion.split(separator: ".").first ?? "") ?? 0
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
